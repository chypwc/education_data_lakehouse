from pathlib import Path
import csv
import json
import random
from datetime import date, timedelta

RANDOM_SEED = 42
OUTPUT_DIR = Path("data/raw_sample")

NUM_SCHOOLS = 50
NUM_STUDENTS = 10_000
START_YEAR = 2024
END_YEAR = 2025

random.seed(RANDOM_SEED)

# Helper functions
def ensure_output_dir():
    """Create the output folder for generated CSV and JSON files."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def random_date(start: date, end: date) -> date:
    """Return a random date between the inclusive start and end dates."""
    days = (end - start).days
    return start + timedelta(days=random.randint(0, days))


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]):
    """Write a list of dictionaries to a CSV file with a fixed column order."""
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, rows: list[dict]):
    """Write a list of dictionaries to a formatted JSON file."""
    with path.open("w", encoding="utf-8") as f:
        json.dump(rows, f, indent=2)
        

def generate_schools():
    """Generate synthetic ACT school reference data."""
    regions = ["North Canberra", "South Canberra", "Belconnen", "Tuggeranong", "Gungahlin", "Woden", "Weston Creek"]
    school_types = ["Primary", "High School", "College", "Specialist"]

    schools = []

    for i in range(1, NUM_SCHOOLS + 1):
        school_id = f"SCH{i:03d}"
        # Use weighted choices so the school mix is closer to a real education system.
        school_type = random.choices(
            school_types,
            weights=[0.55, 0.25, 0.15, 0.05]
        )[0]

        schools.append({
            "school_id": school_id,
            "school_name": f"ACT Education School {i:03d}",
            "region": random.choice(regions),
            "school_type": school_type,
            "open_date": random_date(date(1970, 1, 1), date(2020, 1, 1)).isoformat(),
            "status": random.choices(["Active", "Closed"], weights=[0.92, 0.08])[0],
        })

    return schools


def generate_students(schools):
    """Generate synthetic student enrolment records linked to generated schools."""

    students = []

    for i in range(1, NUM_STUDENTS + 1):
        school = random.choice(schools)
        school_type = school["school_type"]

        # Match year levels to school type so the data is more education-realistic.
        if school_type == "Primary":
            year_level = random.randint(0, 6)
        elif school_type == "High School":
            year_level = random.randint(7, 10)
        elif school_type == "College":
            year_level = random.randint(11, 12)
        else:
            year_level = random.randint(0, 12)

        students.append({
            "student_id": f"STU{i:06d}",
            "school_id": school["school_id"],
            "year_level": year_level,
            "gender": random.choices(
                ["Female", "Male", "Non-specified"],
                weights=[0.49, 0.49, 0.02]
            )[0],
            "enrolment_date": random_date(
                date(2018, 1, 1),
                date(2025, 1, 31)
            ).isoformat(),
            "status": random.choices(
                ["Active", "Transferred", "Left"],
                weights=[0.86, 0.09, 0.05]
            )[0],
        })
        
    return students


def generate_attendance(students):
    """Generate monthly attendance records for each synthetic student."""
    rows = []
    attendance_id = 1
    absence_reasons = ["Illness", "Family", "Unauthorised", "Medical", "Other"]

    for student in students:
        for year in range(START_YEAR, END_YEAR + 1):
            for month in range(1, 13):

                # Approximate the ACT school calendar: January has no school days,
                # December has fewer school days, and other months are mostly full.
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

                    if absent_days == 0:
                        absence_reason = ""
                    else:
                        absence_reason = random.choice(absence_reasons)

                rows.append({
                    "attendance_id": f"ATT{attendance_id:08d}",
                    "student_id": student["student_id"],
                    "school_id": student["school_id"],
                    "attendance_month": f"{year}-{month:02d}-01",
                    "possible_days": possible_days,
                    "attended_days": attended_days,
                    "absence_reason": absence_reason,
                })

                attendance_id += 1

    return rows


def generate_assessment_results(students):
    """Generate assessment results by year, student, and assessment domain."""
    rows = []
    assessment_id = 1
    domains = ["Reading", "Numeracy", "Writing"]

    for student in students:
        year_level = student["year_level"]

        for year in range(START_YEAR, END_YEAR + 1):
            for domain in domains:
                # Higher year levels receive higher base scores, with domain-specific
                # adjustments and random variation to avoid flat synthetic data.
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

                rows.append({
                    "assessment_id": f"ASM{assessment_id:08d}",
                    "student_id": student["student_id"],
                    "school_id": student["school_id"],
                    "assessment_year": year,
                    "domain": domain,
                    "score": score,
                    "proficiency_band": band,
                })

                assessment_id += 1

    return rows


def generate_school_events(schools):
    """Generate API-style JSON school events linked to schools."""
    event_types = ["Attendance campaign", "Wellbeing program", "Assessment intervention"]
    event_weights = [0.40, 0.40, 0.20]

    descriptions = {
        "Attendance campaign": "Campaign to improve student attendance and reduce unexplained absences",
        "Wellbeing program": "School-based wellbeing program supporting student engagement",
        "Assessment intervention": "Targeted intervention for students requiring academic support",
    }

    rows = []
    event_id = 1

    for school in schools:
        number_of_events = random.randint(1, 5)

        for _ in range(number_of_events):
            event_type = random.choices(event_types, weights=event_weights)[0]

            rows.append({
                "event_id": f"EVT{event_id:05d}",
                "school_id": school["school_id"],
                "event_type": event_type,
                "event_date": random_date(
                    date(START_YEAR, 2, 1),
                    date(END_YEAR, 12, 15)
                ).isoformat(),
                "description": descriptions[event_type],
            })

            event_id += 1

    return rows


def inject_data_quality_issues(students, attendance, assessments):
    """Add intentional bad records so SQL data quality checks can be demonstrated."""
    # Missing foreign key: student has no school_id
    students.append({
        "student_id": "STU_BAD_MISSING_SCHOOL",
        "school_id": "",
        "year_level": 7,
        "gender": "Non-specified",
        "enrolment_date": "2024-02-01",
        "status": "Active",
    })

    # Missing primary key: student record has no student_id
    students.append({
        "student_id": "",
        "school_id": "SCH001",
        "year_level": 8,
        "gender": "Non-specified",
        "enrolment_date": "2024-03-01",
        "status": "Active",
    })

    # Business rule violation: attended_days cannot exceed possible_days
    # This also create duplicates if duplicate rule is based on student_id + school_id + attendance_month
    bad_attendance = attendance[0].copy()
    bad_attendance["attendance_id"] = "ATT_BAD_INVALID_DAYS"
    bad_attendance["attended_days"] = bad_attendance["possible_days"] + 5
    attendance.append(bad_attendance)

    # Business duplicate: same student/month, different attendance_id
    duplicate_attendance = attendance[1].copy()
    duplicate_attendance["attendance_id"] = "ATT_BAD_DUPLICATE"
    attendance.append(duplicate_attendance)

    # Orphan record: attendance references a non-existent student
    orphan_attendance = attendance[2].copy()
    orphan_attendance["attendance_id"] = "ATT_BAD_ORPHAN_STUDENT"
    orphan_attendance["student_id"] = "STU999999"
    attendance.append(orphan_attendance)

    # Invalid score: outside expected assessment score range
    bad_assessment = assessments[0].copy()
    bad_assessment["assessment_id"] = "ASM_BAD_SCORE"
    bad_assessment["score"] = 999
    assessments.append(bad_assessment)


def main():
    """Generate all synthetic datasets and write them to the raw sample folder."""
    ensure_output_dir()

    schools = generate_schools()
    students = generate_students(schools)
    attendance = generate_attendance(students)
    assessments = generate_assessment_results(students)
    events = generate_school_events(schools)

    inject_data_quality_issues(students, attendance, assessments)

    write_csv(
        OUTPUT_DIR / "schools.csv",
        ["school_id", "school_name", "region", "school_type", "open_date", "status"],
        schools,
    )

    write_csv(
        OUTPUT_DIR / "students.csv",
        ["student_id", "school_id", "year_level", "gender", "enrolment_date", "status"],
        students,
    )

    write_csv(
        OUTPUT_DIR / "attendance.csv",
        ["attendance_id", "student_id", "school_id", "attendance_month", "possible_days", "attended_days", "absence_reason"],
        attendance,
    )

    write_csv(
        OUTPUT_DIR / "assessment_results.csv",
        ["assessment_id", "student_id", "school_id", "assessment_year", "domain", "score", "proficiency_band"],
        assessments,
    )

    write_json(OUTPUT_DIR / "school_events.json", events)

    print("Synthetic data generated successfully.")
    print(f"Schools: {len(schools):,}")
    print(f"Students: {len(students):,}")
    print(f"Attendance records: {len(attendance):,}")
    print(f"Assessment records: {len(assessments):,}")
    print(f"School events: {len(events):,}")



if __name__ == "__main__":
    main()
