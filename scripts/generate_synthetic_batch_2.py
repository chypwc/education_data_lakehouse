
"""
If Year 12:
    status = Left
    keep previous school_id for final snapshot, or optionally last school attended

Else:
    year_level += 1

    If current school still supports new year_level:
        keep same school_id

    Else:
        choose compatible school

    Small chance of transfer:
        choose compatible school
"""


from pathlib import Path
import csv
import json
import random
from datetime import date, timedelta

RANDOM_SEED = 84

BATCH_1_ID = "2025-01-15"
BATCH_2_ID = "2026-01-15"

INPUT_DIR = Path(f"data/batches/batch_id={BATCH_1_ID}")
OUTPUT_DIR = Path(f"data/batches/batch_id={BATCH_2_ID}")

BATCH_2_YEAR = 2025

NEW_STUDENT_COUNT = 500

random.seed(RANDOM_SEED)


def ensure_output_dir() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def read_csv(path: Path) -> list[dict]:
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def read_json(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)


def random_date(start: date, end: date) -> date:
    days = (end - start).days
    return start + timedelta(days=random.randint(0, days))


def roll_forward_schools(schools: list[dict]) -> list[dict]:
    """Create the Batch 2 school snapshot with realistic reference-data changes."""
    schools_batch_2 = [row.copy() for row in schools]

    # Simulate one existing school closing.
    for school in schools_batch_2:
        if school["school_id"] == "SCH050":
            school["status"] = "Closed"

    # Simulate one new school opening.
    schools_batch_2.append(
        {
            "school_id": "SCH051",
            "school_name": "ACT Education School 051",
            "region": "Gungahlin",
            "school_type": "Primary",
            "open_date": "2025-01-30",
            "status": "Active",
        }
    )

    return schools_batch_2


def choose_school_for_year_level(schools: list[dict], year_level: int) -> dict:
    """Choose a school compatible with the student's year level."""
    active_schools = [s for s in schools if s["status"] == "Active"]

    if year_level <= 6:
        compatible = [s for s in active_schools if s["school_type"] in ["Primary", "Specialist"]]
    elif year_level <= 10:
        compatible = [s for s in active_schools if s["school_type"] in ["High School", "Specialist"]]
    else:
        compatible = [s for s in active_schools if s["school_type"] in ["College", "Specialist"]]

    if not compatible:
        compatible = active_schools

    return random.choice(compatible)


def school_supports_year_level(school: dict, year_level: int) -> bool:
    """Return whether a school type supports the student's year level."""
    school_type = school["school_type"]

    if school_type == "Primary":
        return 0 <= year_level <= 6

    if school_type == "High School":
        return 7 <= year_level <= 10

    if school_type == "College":
        return 11 <= year_level <= 12

    if school_type == "Specialist":
        return 0 <= year_level <= 12

    return False


def choose_school_for_year_level(schools: list[dict], year_level: int, exclude_school_id: str | None = None) -> dict:
    """Choose an active compatible school for a year level."""
    compatible = [
        school
        for school in schools
        if school["status"] == "Active"
        and school_supports_year_level(school, year_level)
        and school["school_id"] != exclude_school_id
    ]

    if not compatible:
        compatible = [
            school
            for school in schools
            if school["status"] == "Active"
            and school_supports_year_level(school, year_level)
        ]

    return random.choice(compatible)


def roll_forward_students(students: list[dict], schools_batch_2: list[dict]) -> list[dict]:
    """Create the Batch 2 student snapshot after annual rollover."""
    schools_by_id = {school["school_id"]: school for school in schools_batch_2}
    students_batch_2 = []

    for student in students:
        # Skip intentionally bad Batch 1 test records from the normal rollover.
        if not student["student_id"].startswith("STU"):
            continue

        updated_student = student.copy()
        current_status = student["status"]
        current_year_level = int(student["year_level"])

        if current_status != "Active":
            students_batch_2.append(updated_student)
            continue

        # Year 12 students leave after completing college.
        if current_year_level >= 12:
            updated_student["status"] = "Left"
            students_batch_2.append(updated_student)
            continue

        new_year_level = current_year_level + 1
        updated_student["year_level"] = new_year_level

        current_school = schools_by_id.get(student["school_id"])

        must_change_school = (
            current_school is None
            or current_school["status"] != "Active"
            or not school_supports_year_level(current_school, new_year_level)
        )

        voluntary_transfer = random.random() < 0.03

        if must_change_school or voluntary_transfer:
            new_school = choose_school_for_year_level(
                schools_batch_2,
                new_year_level,
                exclude_school_id=student["school_id"],
            )
            updated_student["school_id"] = new_school["school_id"]

            if voluntary_transfer and not must_change_school:
                updated_student["status"] = "Transferred"

        # A small number of students leave for non-graduation reasons.
        if updated_student["status"] == "Active" and random.random() < 0.02:
            updated_student["status"] = "Left"

        students_batch_2.append(updated_student)

    return students_batch_2


def next_student_number(students: list[dict]) -> int:
    """Find the next numeric student ID after existing STU records."""
    max_number = 0

    for student in students:
        student_id = student["student_id"]

        if student_id.startswith("STU") and student_id[3:].isdigit():
            max_number = max(max_number, int(student_id[3:]))

    return max_number + 1


def add_new_students(students_batch_2: list[dict], schools_batch_2: list[dict]) -> list[dict]:
    """Add new enrolments for Batch 2."""
    students_with_new = [row.copy() for row in students_batch_2]
    next_number = next_student_number(students_with_new)

    for i in range(NEW_STUDENT_COUNT):
        student_id = f"STU{next_number + i:06d}"

        # Most new students enter Kindergarten/Foundation, with some transfers into later years.
        year_level = random.choices(
            population=[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
            weights=[0.40, 0.04, 0.04, 0.04, 0.04, 0.04, 0.04, 0.08, 0.07, 0.06, 0.05, 0.05, 0.05],
        )[0]

        school = choose_school_for_year_level(schools_batch_2, year_level)

        students_with_new.append(
            {
                "student_id": student_id,
                "school_id": school["school_id"],
                "year_level": year_level,
                "gender": random.choices(
                    ["Female", "Male", "Non-specified"],
                    weights=[0.49, 0.49, 0.02],
                )[0],
                "enrolment_date": random_date(date(2025, 1, 20), date(2025, 2, 28)).isoformat(),
                "status": "Active",
            }
        )

    return students_with_new



def generate_attendance_for_year(students: list[dict], year: int, id_prefix: str) -> list[dict]:
    """Generate monthly attendance records for active students in one year."""
    rows = []
    attendance_number = 1
    absence_reasons = ["Illness", "Family", "Unauthorised", "Medical", "Other"]

    active_students = [student for student in students if student["status"] == "Active"]

    for student in active_students:
        for month in range(1, 13):
            if month == 1:
                possible_days = 0
            elif month == 12:
                possible_days = random.randint(10, 15)
            else:
                possible_days = random.randint(18, 22)

            if possible_days == 0:
                attended_days = 0
                absence_reason = ""
            else:
                absent_days = random.randint(0, 6)
                attended_days = max(0, possible_days - absent_days)
                absence_reason = "" if absent_days == 0 else random.choice(absence_reasons)

            rows.append(
                {
                    "attendance_id": f"{id_prefix}{attendance_number:08d}",
                    "student_id": student["student_id"],
                    "school_id": student["school_id"],
                    "attendance_month": f"{year}-{month:02d}-01",
                    "possible_days": possible_days,
                    "attended_days": attended_days,
                    "absence_reason": absence_reason,
                }
            )

            attendance_number += 1

    return rows


def generate_assessment_results_for_year(students: list[dict], year: int, id_prefix: str) -> list[dict]:
    """Generate assessment results for active students in one year."""
    rows = []
    assessment_number = 1
    domains = ["Reading", "Numeracy", "Writing"]

    active_students = [student for student in students if student["status"] == "Active"]

    for student in active_students:
        year_level = int(student["year_level"])

        for domain in domains:
            base_score = 300 + year_level * 25

            domain_adjustment = {
                "Reading": 10,
                "Numeracy": 0,
                "Writing": -5,
            }[domain]

            noise = random.randint(-60, 60)
            score = base_score + domain_adjustment + noise
            score = max(250, min(700, score))

            if score < 400:
                band = "Low"
            elif score < 550:
                band = "Medium"
            else:
                band = "High"

            rows.append(
                {
                    "assessment_id": f"{id_prefix}{assessment_number:08d}",
                    "student_id": student["student_id"],
                    "school_id": student["school_id"],
                    "assessment_year": year,
                    "domain": domain,
                    "score": score,
                    "proficiency_band": band,
                }
            )

            assessment_number += 1

    return rows


def generate_school_events_for_year(schools: list[dict], year: int, id_prefix: str) -> list[dict]:
    """Generate API-style school events for active schools in one year."""
    event_types = ["Attendance campaign", "Wellbeing program", "Assessment intervention"]
    event_weights = [0.40, 0.40, 0.20]

    descriptions = {
        "Attendance campaign": "Campaign to improve student attendance and reduce unexplained absences",
        "Wellbeing program": "School-based wellbeing program supporting student engagement",
        "Assessment intervention": "Targeted intervention for students requiring academic support",
    }

    active_schools = [school for school in schools if school["status"] == "Active"]

    rows = []
    event_number = 1

    for school in active_schools:
        number_of_events = random.randint(1, 5)

        for _ in range(number_of_events):
            event_type = random.choices(event_types, weights=event_weights)[0]

            rows.append(
                {
                    "event_id": f"{id_prefix}{event_number:05d}",
                    "school_id": school["school_id"],
                    "event_type": event_type,
                    "event_date": random_date(date(year, 2, 1), date(year, 12, 15)).isoformat(),
                    "description": descriptions[event_type],
                }
            )

            event_number += 1

    return rows


def inject_batch_2_data_quality_issues(
    students: list[dict],
    attendance: list[dict],
    assessments: list[dict],
) -> None:
    """Add intentional Batch 2 data quality issues."""
    students.append(
        {
            "student_id": "STU_BAD_BATCH2_MISSING_SCHOOL",
            "school_id": "",
            "year_level": 3,
            "gender": "Non-specified",
            "enrolment_date": "2025-02-03",
            "status": "Active",
        }
    )

    if attendance:
        bad_attendance = attendance[0].copy()
        bad_attendance["attendance_id"] = "ATT2025_BAD_INVALID_DAYS"
        bad_attendance["attended_days"] = int(bad_attendance["possible_days"]) + 4
        attendance.append(bad_attendance)

    if len(attendance) > 1:
        duplicate_attendance = attendance[1].copy()
        duplicate_attendance["attendance_id"] = "ATT2025_BAD_DUPLICATE"
        attendance.append(duplicate_attendance)

    if len(attendance) > 2:
        orphan_attendance = attendance[2].copy()
        orphan_attendance["attendance_id"] = "ATT2025_BAD_ORPHAN_STUDENT"
        orphan_attendance["student_id"] = "STU999998"
        attendance.append(orphan_attendance)

    if assessments:
        bad_assessment = assessments[0].copy()
        bad_assessment["assessment_id"] = "ASM2025_BAD_SCORE"
        bad_assessment["score"] = 999
        assessments.append(bad_assessment)


def main() -> None:
    ensure_output_dir()

    schools_batch_1 = read_csv(INPUT_DIR / "schools.csv")
    students_batch_1 = read_csv(INPUT_DIR / "students.csv")

    schools_batch_2 = roll_forward_schools(schools_batch_1)

    students_batch_2 = roll_forward_students(students_batch_1, schools_batch_2)
    students_batch_2 = add_new_students(students_batch_2, schools_batch_2)

    attendance_batch_2 = generate_attendance_for_year(
        students_batch_2,
        BATCH_2_YEAR,
        "ATT2025",
    )

    assessments_batch_2 = generate_assessment_results_for_year(
        students_batch_2,
        BATCH_2_YEAR,
        "ASM2025",
    )

    events_batch_2 = generate_school_events_for_year(
        schools_batch_2,
        BATCH_2_YEAR,
        "EVT2025",
    )

    inject_batch_2_data_quality_issues(
        students_batch_2,
        attendance_batch_2,
        assessments_batch_2,
    )

    write_csv(
        OUTPUT_DIR / "schools.csv",
        ["school_id", "school_name", "region", "school_type", "open_date", "status"],
        schools_batch_2,
    )

    write_csv(
        OUTPUT_DIR / "students.csv",
        ["student_id", "school_id", "year_level", "gender", "enrolment_date", "status"],
        students_batch_2,
    )

    write_csv(
        OUTPUT_DIR / "attendance.csv",
        [
            "attendance_id",
            "student_id",
            "school_id",
            "attendance_month",
            "possible_days",
            "attended_days",
            "absence_reason",
        ],
        attendance_batch_2,
    )

    write_csv(
        OUTPUT_DIR / "assessment_results.csv",
        [
            "assessment_id",
            "student_id",
            "school_id",
            "assessment_year",
            "domain",
            "score",
            "proficiency_band",
        ],
        assessments_batch_2,
    )

    write_json(OUTPUT_DIR / "school_events.json", events_batch_2)

    print("Batch 2 synthetic data generated successfully.")
    print(f"Input Batch 1 students: {len(students_batch_1):,}")
    print(f"Batch 2 schools: {len(schools_batch_2):,}")
    print(f"Batch 2 students: {len(students_batch_2):,}")
    print(f"Batch 2 attendance records: {len(attendance_batch_2):,}")
    print(f"Batch 2 assessment records: {len(assessments_batch_2):,}")
    print(f"Batch 2 school events: {len(events_batch_2):,}")
    print(f"Output folder: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()