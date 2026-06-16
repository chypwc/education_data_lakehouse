from __future__ import annotations

import csv
import json
import random
import shutil
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path


RANDOM_SEED = 20240612
OUTPUT_DIR = Path("data/pipeline_c_monthly_insights")

NUM_SCHOOLS = 50
NUM_STUDENTS = 10_000

START_YEAR = 2024
END_YEAR = 2025

SNAPSHOT_MONTH = "2024-01"
CHANGE_MONTHS = [
    f"{year}-{month:02d}"
    for year in range(START_YEAR, END_YEAR + 1)
    for month in range(1, 13)
    if f"{year}-{month:02d}" != SNAPSHOT_MONTH
]

REGIONS = [
    "North Canberra",
    "South Canberra",
    "Belconnen",
    "Tuggeranong",
    "Gungahlin",
    "Woden",
    "Weston Creek",
]

SCHOOL_TYPES = ["Primary", "High School", "College", "Specialist"]
DOMAINS = ["Reading", "Numeracy", "Writing"]
ABSENCE_REASONS = ["Illness", "Family", "Unauthorised", "Medical", "Other"]

SCHOOL_FIELDS = ["school_id", "school_name", "region", "school_type", "open_date", "status"]
STUDENT_FIELDS = ["student_id", "school_id", "year_level", "gender", "enrolment_date", "status"]
ATTENDANCE_FIELDS = [
    "attendance_id",
    "student_id",
    "school_id",
    "attendance_month",
    "possible_days",
    "attended_days",
    "absence_reason",
]
ASSESSMENT_FIELDS = [
    "assessment_id",
    "student_id",
    "school_id",
    "assessment_year",
    "domain",
    "score",
    "proficiency_band",
]


@dataclass
class StudentProfile:
    attendance_bias: float
    academic_bias: float


def month_start(month_id: str) -> date:
    year, month = month_id.split("-")
    return date(int(year), int(month), 1)


def random_date(start: date, end: date) -> date:
    days = (end - start).days
    return start + timedelta(days=random.randint(0, days))


def month_dir(month_id: str) -> Path:
    return OUTPUT_DIR / f"month={month_id}"


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)


def school_supports_year_level(school: dict, year_level: int) -> bool:
    school_type = school["school_type"]
    if school_type == "Primary":
        return 0 <= year_level <= 6
    if school_type == "High School":
        return 7 <= year_level <= 10
    if school_type == "College":
        return 11 <= year_level <= 12
    return True


def choose_school_for_year_level(
    schools: dict[str, dict],
    year_level: int,
    exclude_school_id: str | None = None,
) -> dict:
    compatible = [
        school
        for school in schools.values()
        if school["status"] == "Active"
        and school_supports_year_level(school, year_level)
        and school["school_id"] != exclude_school_id
    ]
    if not compatible:
        compatible = [school for school in schools.values() if school["status"] == "Active"]
    return random.choice(compatible)


def generate_schools() -> dict[str, dict]:
    schools: dict[str, dict] = {}
    for i in range(1, NUM_SCHOOLS + 1):
        school_type = random.choices(SCHOOL_TYPES, weights=[0.55, 0.25, 0.15, 0.05])[0]
        school_id = f"SCH{i:03d}"
        schools[school_id] = {
            "school_id": school_id,
            "school_name": f"ACT Education School {i:03d}",
            "region": random.choice(REGIONS),
            "school_type": school_type,
            "open_date": date(random.randint(1970, 2018), random.randint(1, 12), 1).isoformat(),
            "status": "Active",
        }
    return schools


def generate_students(schools: dict[str, dict]) -> tuple[dict[str, dict], dict[str, StudentProfile]]:
    students: dict[str, dict] = {}
    profiles: dict[str, StudentProfile] = {}

    for i in range(1, NUM_STUDENTS + 1):
        school = random.choice(list(schools.values()))
        if school["school_type"] == "Primary":
            year_level = random.randint(0, 6)
        elif school["school_type"] == "High School":
            year_level = random.randint(7, 10)
        elif school["school_type"] == "College":
            year_level = random.randint(11, 12)
        else:
            year_level = random.randint(0, 12)

        student_id = f"STU{i:06d}"
        students[student_id] = {
            "student_id": student_id,
            "school_id": school["school_id"],
            "year_level": year_level,
            "gender": random.choices(["Female", "Male", "Non-specified"], weights=[0.49, 0.49, 0.02])[0],
            "enrolment_date": random_date(date(2018, 1, 1), month_start(SNAPSHOT_MONTH)).isoformat(),
            "status": "Active",
        }
        profiles[student_id] = StudentProfile(
            attendance_bias=random.gauss(0, 0.025),
            academic_bias=random.gauss(0, 18),
        )

    return students, profiles


def possible_school_days(month_number: int) -> int:
    if month_number == 1:
        return random.randint(1, 3)
    if month_number == 12:
        return random.randint(10, 15)
    if month_number in {4, 7, 9}:
        return random.randint(14, 18)
    return random.randint(18, 22)


def attendance_rate_for(student: dict, profile: StudentProfile, school: dict, month_id: str) -> float:
    month = int(month_id[-2:])
    year_level = int(student["year_level"])

    if year_level <= 6:
        base = 0.925
    elif year_level == 7:
        base = 0.885
    elif year_level <= 10:
        base = 0.905
    else:
        base = 0.86

    seasonal = -0.065 if month in {6, 7, 8} else 0
    if month in {2, 3} and year_level == 7:
        seasonal -= 0.045
    if year_level in {11, 12}:
        senior_month_adjustment = {
            2: 0.025,
            3: -0.045,
            4: 0.030,
            5: -0.035,
            9: -0.040,
            10: 0.025,
            11: -0.030,
            12: 0.020,
        }
        seasonal += senior_month_adjustment.get(month, 0) + random.gauss(0, 0.040)

    challenge_school = school["school_id"] in {"SCH007", "SCH014", "SCH021", "SCH028", "SCH035"}
    if challenge_school and month in {6, 7, 8}:
        seasonal -= 0.035

    rate = base + seasonal + profile.attendance_bias + random.gauss(0, 0.025)
    return max(0.55, min(0.985, rate))


def attendance_band(rate: float) -> str:
    if rate < 0.82:
        return "Low"
    if rate < 0.90:
        return "Medium"
    return "High"


def score_band(score: int) -> str:
    if score < 400:
        return "Low"
    if score < 550:
        return "Medium"
    return "High"


def generate_attendance(
    students: dict[str, dict],
    profiles: dict[str, StudentProfile],
    schools: dict[str, dict],
    month_id: str,
    attendance_history: dict[tuple[str, int], list[float]],
) -> list[dict]:
    month = int(month_id[-2:])
    year = int(month_id[:4])
    rows: list[dict] = []

    for student in students.values():
        if student["status"] != "Active":
            continue

        school = schools.get(student["school_id"])
        if not school or school["status"] != "Active":
            continue

        possible_days = possible_school_days(month)
        rate = attendance_rate_for(student, profiles[student["student_id"]], school, month_id)
        attended_days = round(possible_days * rate)
        absent_days = possible_days - attended_days

        attendance_history[(student["student_id"], year)].append(attended_days / possible_days)

        rows.append(
            {
                "attendance_id": f"ATT{month_id.replace('-', '')}{student['student_id'][3:]}",
                "student_id": student["student_id"],
                "school_id": student["school_id"],
                "attendance_month": f"{month_id}-01",
                "possible_days": possible_days,
                "attended_days": attended_days,
                "absence_reason": "" if absent_days == 0 else random.choice(ABSENCE_REASONS),
            }
        )

    return rows


def generate_assessments(
    students: dict[str, dict],
    profiles: dict[str, StudentProfile],
    attendance_history: dict[tuple[str, int], list[float]],
    assessment_year: int,
) -> list[dict]:
    rows: list[dict] = []

    for student in students.values():
        if student["status"] != "Active":
            continue

        student_id = student["student_id"]
        year_level = int(student["year_level"])
        rates = attendance_history.get((student_id, assessment_year), [])
        avg_attendance = sum(rates) / len(rates) if rates else 0.9
        band = attendance_band(avg_attendance)

        attendance_adjustment = {"Low": -110, "Medium": 0, "High": 65}[band]
        for domain in DOMAINS:
            domain_adjustment = {"Reading": 10, "Numeracy": 0, "Writing": -5}[domain]
            raw_score = (
                360
                + year_level * 5
                + domain_adjustment
                + attendance_adjustment
                + profiles[student_id].academic_bias
                + random.gauss(0, 35)
            )
            score = int(max(250, min(700, round(raw_score))))
            rows.append(
                {
                    "assessment_id": f"ASM{assessment_year}{domain[:3].upper()}{student_id[3:]}",
                    "student_id": student_id,
                    "school_id": student["school_id"],
                    "assessment_year": assessment_year,
                    "domain": domain,
                    "score": score,
                    "proficiency_band": score_band(score),
                }
            )

    return rows


def generate_events(schools: dict[str, dict], month_id: str, sequence_start: int) -> tuple[list[dict], int]:
    event_types = ["Attendance campaign", "Wellbeing program", "Assessment intervention"]
    descriptions = {
        "Attendance campaign": "Campaign to improve student attendance and reduce unexplained absences",
        "Wellbeing program": "School-based wellbeing program supporting student engagement",
        "Assessment intervention": "Targeted intervention for students requiring academic support",
    }
    rows: list[dict] = []
    event_number = sequence_start
    active_schools = [s for s in schools.values() if s["status"] == "Active"]
    sampled_schools = random.sample(active_schools, k=min(len(active_schools), random.randint(5, 12)))

    for school in sampled_schools:
        event_type = random.choices(event_types, weights=[0.45, 0.35, 0.20])[0]
        rows.append(
            {
                "event_id": f"EVT{event_number:06d}",
                "school_id": school["school_id"],
                "event_type": event_type,
                "event_date": f"{month_id}-{random.randint(1, 24):02d}",
                "description": descriptions[event_type],
            }
        )
        event_number += 1

    return rows, event_number


def next_student_id(students: dict[str, dict]) -> str:
    max_id = max(int(student_id[3:]) for student_id in students if student_id.startswith("STU"))
    return f"STU{max_id + 1:06d}"


def add_new_students(
    students: dict[str, dict],
    profiles: dict[str, StudentProfile],
    schools: dict[str, dict],
    month_id: str,
    count: int,
) -> list[dict]:
    changed: list[dict] = []
    for _ in range(count):
        student_id = next_student_id(students)
        year_level = random.choices(
            list(range(0, 13)),
            weights=[0.38, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.10, 0.07, 0.06, 0.05, 0.05, 0.05],
        )[0]
        school = choose_school_for_year_level(schools, year_level)
        students[student_id] = {
            "student_id": student_id,
            "school_id": school["school_id"],
            "year_level": year_level,
            "gender": random.choices(["Female", "Male", "Non-specified"], weights=[0.49, 0.49, 0.02])[0],
            "enrolment_date": f"{month_id}-01",
            "status": "Active",
        }
        profiles[student_id] = StudentProfile(
            attendance_bias=random.gauss(0, 0.025),
            academic_bias=random.gauss(0, 18),
        )
        changed.append(students[student_id].copy())
    return changed


def apply_student_monthly_changes(
    students: dict[str, dict],
    profiles: dict[str, StudentProfile],
    schools: dict[str, dict],
    month_id: str,
) -> list[dict]:
    changed: list[dict] = []
    active_students = [s for s in students.values() if s["status"] == "Active"]

    if month_id == "2025-01":
        for student in active_students:
            year_level = int(student["year_level"])
            if year_level >= 12:
                student["status"] = "Left"
                changed.append(student.copy())
                continue

            new_year_level = year_level + 1
            student["year_level"] = new_year_level
            school = schools.get(student["school_id"])
            if not school or not school_supports_year_level(school, new_year_level) or school["status"] != "Active":
                student["school_id"] = choose_school_for_year_level(schools, new_year_level, student["school_id"])["school_id"]
            changed.append(student.copy())

        changed.extend(add_new_students(students, profiles, schools, month_id, 450))
        return changed

    for student in active_students:
        school = schools.get(student["school_id"])
        year_level = int(student["year_level"])
        if not school or school["status"] != "Active" or not school_supports_year_level(school, year_level):
            student["school_id"] = choose_school_for_year_level(schools, year_level, student["school_id"])["school_id"]
            changed.append(student.copy())

    for student in random.sample(active_students, k=min(18, len(active_students))):
        student["school_id"] = choose_school_for_year_level(
            schools,
            int(student["year_level"]),
            student["school_id"],
        )["school_id"]
        changed.append(student.copy())

    for student in random.sample(active_students, k=min(10, len(active_students))):
        student["status"] = "Left"
        changed.append(student.copy())

    changed.extend(add_new_students(students, profiles, schools, month_id, 25))
    return changed


def apply_school_changes(schools: dict[str, dict], month_id: str) -> list[dict]:
    if month_id != "2025-07":
        return []

    school = schools["SCH050"]
    school["status"] = "Closed"
    return [school.copy()]


def inject_data_quality_caveats(
    month_id: str,
    students_delta: list[dict],
    attendance: list[dict],
    assessments: list[dict],
) -> None:
    if month_id == "2024-03":
        students_delta.append(
            {
                "student_id": "STU_CAVEAT_MISSING_SCHOOL",
                "school_id": "",
                "year_level": 7,
                "gender": "Non-specified",
                "enrolment_date": "2024-03-01",
                "status": "Active",
            }
        )

    if month_id in {"2024-06", "2025-06"} and attendance:
        bad_attendance = attendance[0].copy()
        bad_attendance["attendance_id"] = f"ATT_CAVEAT_INVALID_DAYS_{month_id.replace('-', '')}"
        bad_attendance["attended_days"] = int(bad_attendance["possible_days"]) + 4
        attendance.append(bad_attendance)

    if month_id in {"2024-08", "2025-08"} and len(attendance) > 1:
        duplicate = attendance[1].copy()
        duplicate["attendance_id"] = f"ATT_CAVEAT_DUPLICATE_{month_id.replace('-', '')}"
        attendance.append(duplicate)

    if month_id == "2025-09" and len(attendance) > 2:
        orphan = attendance[2].copy()
        orphan["attendance_id"] = "ATT_CAVEAT_ORPHAN_STUDENT_202509"
        orphan["student_id"] = "STU999999"
        attendance.append(orphan)

    if month_id in {"2024-11", "2025-11"} and assessments:
        invalid = assessments[0].copy()
        invalid["assessment_id"] = f"ASM_CAVEAT_INVALID_SCORE_{month_id[:4]}"
        invalid["score"] = 999
        assessments.append(invalid)


def write_snapshot(
    schools: dict[str, dict],
    students: dict[str, dict],
    profiles: dict[str, StudentProfile],
    attendance_history: dict[tuple[str, int], list[float]],
    event_number: int,
) -> int:
    month_id = SNAPSHOT_MONTH
    output_dir = month_dir(month_id)
    attendance = generate_attendance(students, profiles, schools, month_id, attendance_history)
    events, event_number = generate_events(schools, month_id, event_number)

    write_csv(output_dir / "schools.csv", SCHOOL_FIELDS, list(schools.values()))
    write_csv(output_dir / "students.csv", STUDENT_FIELDS, list(students.values()))
    write_csv(output_dir / "attendance.csv", ATTENDANCE_FIELDS, attendance)
    write_csv(output_dir / "assessment_results.csv", ASSESSMENT_FIELDS, [])
    write_json(output_dir / "school_events.json", events)
    return event_number


def write_change_batch(
    month_id: str,
    schools: dict[str, dict],
    students: dict[str, dict],
    profiles: dict[str, StudentProfile],
    attendance_history: dict[tuple[str, int], list[float]],
    event_number: int,
) -> tuple[int, dict[str, int]]:
    output_dir = month_dir(month_id)

    schools_delta = apply_school_changes(schools, month_id)
    students_delta = apply_student_monthly_changes(students, profiles, schools, month_id)
    attendance = generate_attendance(students, profiles, schools, month_id, attendance_history)

    assessments: list[dict] = []
    if month_id in {"2024-11", "2025-11"}:
        assessments = generate_assessments(students, profiles, attendance_history, int(month_id[:4]))

    events, event_number = generate_events(schools, month_id, event_number)
    inject_data_quality_caveats(month_id, students_delta, attendance, assessments)

    write_csv(output_dir / "schools_delta.csv", SCHOOL_FIELDS, schools_delta)
    write_csv(output_dir / "students_delta.csv", STUDENT_FIELDS, students_delta)
    write_csv(output_dir / "attendance.csv", ATTENDANCE_FIELDS, attendance)
    write_csv(output_dir / "assessment_results_delta.csv", ASSESSMENT_FIELDS, assessments)
    write_json(output_dir / "school_events.json", events)

    return event_number, {
        "schools_delta": len(schools_delta),
        "students_delta": len(students_delta),
        "attendance": len(attendance),
        "assessment_results_delta": len(assessments),
        "school_events": len(events),
    }


def main() -> None:
    random.seed(RANDOM_SEED)
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    schools = generate_schools()
    students, profiles = generate_students(schools)
    attendance_history: dict[tuple[str, int], list[float]] = defaultdict(list)

    event_number = 1
    event_number = write_snapshot(schools, students, profiles, attendance_history, event_number)

    summary = {
        "random_seed": RANDOM_SEED,
        "snapshot_month": SNAPSHOT_MONTH,
        "snapshot_folder": f"month={SNAPSHOT_MONTH}",
        "change_months": CHANGE_MONTHS,
        "change_folders": [f"month={month_id}" for month_id in CHANGE_MONTHS],
        "initial_schools": NUM_SCHOOLS,
        "initial_students": NUM_STUDENTS,
        "batches": {},
    }

    for month_id in CHANGE_MONTHS:
        event_number, counts = write_change_batch(
            month_id,
            schools,
            students,
            profiles,
            attendance_history,
            event_number,
        )
        summary["batches"][month_id] = counts

    summary["final_students"] = len(students)
    summary["final_active_students"] = sum(1 for s in students.values() if s["status"] == "Active")
    summary["final_schools"] = len(schools)
    summary["final_active_schools"] = sum(1 for s in schools.values() if s["status"] == "Active")

    write_json(OUTPUT_DIR / "generation_summary.json", summary)

    print("Pipeline C synthetic data generated successfully.")
    print(f"Output folder: {OUTPUT_DIR}")
    print(f"Snapshot month: {SNAPSHOT_MONTH}")
    print(f"Change batches: {len(CHANGE_MONTHS)}")
    print(f"Initial students: {NUM_STUDENTS:,}")
    print(f"Final active students: {summary['final_active_students']:,}")


if __name__ == "__main__":
    main()
