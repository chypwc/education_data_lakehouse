from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path
from statistics import mean


try:
    import matplotlib.pyplot as plt
    from matplotlib.ticker import PercentFormatter
except ModuleNotFoundError as exc:
    raise SystemExit(
        "matplotlib is required to run this script. Install it in your Python "
        "environment, then rerun: python scripts\\pipeline_c_monthly_insights\\plot_pipeline_c_story.py"
    ) from exc


DATA_DIR = Path("data/pipeline_c_monthly_insights")
OUTPUT_DIR = Path("images/pipeline_c_monthly_insights/story_validation")

LOW_ATTENDANCE_THRESHOLD = 0.82
MEDIUM_ATTENDANCE_THRESHOLD = 0.90


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []

    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def month_folders() -> list[tuple[str, Path]]:
    folders = []
    for path in DATA_DIR.iterdir():
        if path.is_dir() and path.name.startswith("month="):
            folders.append((path.name.replace("month=", ""), path))
    return sorted(folders)


def attendance_band(rate: float) -> str:
    if rate < LOW_ATTENDANCE_THRESHOLD:
        return "Low"
    if rate < MEDIUM_ATTENDANCE_THRESHOLD:
        return "Medium"
    return "High"


def year_group(year_level: int) -> str:
    if year_level == 7:
        return "Year 7"
    if 8 <= year_level <= 10:
        return "Years 8-10"
    if 11 <= year_level <= 12:
        return "Years 11-12"
    return "Primary"


def collect_story_metrics() -> dict:
    months = month_folders()
    if not months:
        raise FileNotFoundError(f"No month=YYYY-MM folders found under {DATA_DIR}")

    students: dict[str, dict[str, str]] = {}
    monthly_attendance: dict[str, list[float]] = defaultdict(list)
    group_attendance: dict[str, dict[str, list[float]]] = defaultdict(lambda: defaultdict(list))
    attendance_history: dict[tuple[str, int], list[float]] = defaultdict(list)
    quality_caveats: dict[str, int] = defaultdict(int)
    assessment_scores: dict[str, list[int]] = defaultdict(list)

    for month_id, folder in months:
        year = int(month_id[:4])

        if month_id == "2024-01":
            for row in read_csv(folder / "students.csv"):
                students[row["student_id"]] = row
        else:
            for row in read_csv(folder / "students_delta.csv"):
                if not row.get("school_id"):
                    quality_caveats[month_id] += 1
                students[row["student_id"]] = row

        seen_attendance_keys: set[tuple[str, str, str]] = set()
        for row in read_csv(folder / "attendance.csv"):
            key = (row["student_id"], row["school_id"], row["attendance_month"])
            if key in seen_attendance_keys:
                quality_caveats[month_id] += 1
            seen_attendance_keys.add(key)

            if row["student_id"] not in students:
                quality_caveats[month_id] += 1

            possible_days = int(row["possible_days"])
            attended_days = int(row["attended_days"])
            if possible_days <= 0 or attended_days < 0 or attended_days > possible_days:
                quality_caveats[month_id] += 1
                continue

            rate = attended_days / possible_days
            monthly_attendance[month_id].append(rate)
            attendance_history[(row["student_id"], year)].append(rate)

            student = students.get(row["student_id"])
            if student:
                group_attendance[year_group(int(student["year_level"]))][month_id].append(rate)

        for row in read_csv(folder / "assessment_results_delta.csv"):
            score = int(row["score"])
            if score < 250 or score > 700:
                quality_caveats[month_id] += 1
                continue

            student_rates = attendance_history.get((row["student_id"], int(row["assessment_year"])), [])
            avg_attendance = mean(student_rates) if student_rates else MEDIUM_ATTENDANCE_THRESHOLD
            assessment_scores[attendance_band(avg_attendance)].append(score)

    month_ids = [month_id for month_id, _ in months]
    return {
        "months": month_ids,
        "monthly_attendance": {
            month_id: mean(rates) if rates else None
            for month_id, rates in monthly_attendance.items()
        },
        "group_attendance": {
            group: {
                month_id: mean(rates) if rates else None
                for month_id, rates in by_month.items()
            }
            for group, by_month in group_attendance.items()
        },
        "assessment_scores": {
            band: mean(scores) if scores else 0
            for band, scores in assessment_scores.items()
        },
        "quality_caveats": dict(quality_caveats),
    }


def configure_style() -> None:
    plt.rcParams.update(
        {
            "figure.facecolor": "white",
            "axes.facecolor": "#f8fafc",
            "axes.edgecolor": "#d8dee9",
            "axes.labelcolor": "#34495e",
            "axes.titlecolor": "#22313f",
            "xtick.color": "#607080",
            "ytick.color": "#607080",
            "grid.color": "#e3e8ef",
            "font.family": "DejaVu Sans",
        }
    )


def shade_winter_months(ax, months: list[str]) -> None:
    for index, month_id in enumerate(months):
        if month_id[5:7] in {"06", "07", "08"}:
            ax.axvspan(index - 0.5, index + 0.5, color="#dbeafe", alpha=0.55, zorder=0)


def save_figure(fig, file_name: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUTPUT_DIR / file_name
    fig.savefig(path, dpi=160, bbox_inches="tight")
    plt.close(fig)


def plot_monthly_attendance(metrics: dict) -> None:
    months = metrics["months"]
    values = [metrics["monthly_attendance"].get(month_id) for month_id in months]

    fig, ax = plt.subplots(figsize=(12, 6))
    shade_winter_months(ax, months)
    ax.plot(months, values, color="#2563eb", linewidth=2.5, marker="o", label="Overall attendance")
    ax.set_title("Monthly Attendance Seasonality", fontsize=16, fontweight="bold", loc="left")
    ax.set_xlabel("Reporting month")
    ax.set_ylabel("Attendance rate")
    ax.set_ylim(0.78, 1.00)
    ax.yaxis.set_major_formatter(PercentFormatter(1.0))
    ax.grid(axis="y", linestyle="-", linewidth=0.8)
    ax.legend(loc="lower left")
    ax.tick_params(axis="x", rotation=45)
    save_figure(fig, "monthly_attendance_seasonality.png")


def plot_year_level_patterns(metrics: dict) -> None:
    months = metrics["months"]
    groups = {
        "Year 7": "#7c3aed",
        "Years 8-10": "#0f766e",
        "Years 11-12": "#dc2626",
    }

    fig, ax = plt.subplots(figsize=(12, 6))
    shade_winter_months(ax, months)

    for group, color in groups.items():
        values = [metrics["group_attendance"].get(group, {}).get(month_id) for month_id in months]
        ax.plot(months, values, linewidth=2.3, marker="o", label=group, color=color)

    ax.set_title("Year-Level Attendance Patterns", fontsize=16, fontweight="bold", loc="left")
    ax.set_xlabel("Reporting month")
    ax.set_ylabel("Attendance rate")
    ax.set_ylim(0.74, 1.00)
    ax.yaxis.set_major_formatter(PercentFormatter(1.0))
    ax.grid(axis="y", linestyle="-", linewidth=0.8)
    ax.legend(loc="lower left", ncol=3)
    ax.tick_params(axis="x", rotation=45)
    save_figure(fig, "year_level_attendance_patterns.png")


def plot_assessment_scores(metrics: dict) -> None:
    labels = ["Low", "Medium", "High"]
    values = [metrics["assessment_scores"].get(label, 0) for label in labels]
    colors = ["#b91c1c", "#ca8a04", "#15803d"]

    fig, ax = plt.subplots(figsize=(8, 5.5))
    bars = ax.bar(labels, values, color=colors, width=0.62)
    ax.set_title("Assessment Score By Attendance Band", fontsize=16, fontweight="bold", loc="left")
    ax.set_xlabel("Attendance band")
    ax.set_ylabel("Average assessment score")
    ax.set_ylim(0, max(values) * 1.18)
    ax.grid(axis="y", linestyle="-", linewidth=0.8)

    for bar, value in zip(bars, values):
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            bar.get_height(),
            f"{value:.1f}",
            ha="center",
            va="bottom",
            fontsize=10,
            fontweight="bold",
            color="#22313f",
        )

    save_figure(fig, "assessment_score_by_attendance_band.png")


def plot_quality_caveats(metrics: dict) -> None:
    months = metrics["months"]
    values = [metrics["quality_caveats"].get(month_id, 0) for month_id in months]
    colors = ["#c2410c" if value else "#a8b3c2" for value in values]

    fig, ax = plt.subplots(figsize=(12, 5.5))
    bars = ax.bar(months, values, color=colors, width=0.72)
    ax.set_title("Data Quality Caveats By Reporting Month", fontsize=16, fontweight="bold", loc="left")
    ax.set_xlabel("Reporting month")
    ax.set_ylabel("Caveat count")
    ax.set_ylim(0, max(values) + 1 if values else 1)
    ax.grid(axis="y", linestyle="-", linewidth=0.8)
    ax.tick_params(axis="x", rotation=45)

    for bar, value in zip(bars, values):
        if value:
            ax.text(
                bar.get_x() + bar.get_width() / 2,
                bar.get_height(),
                str(value),
                ha="center",
                va="bottom",
                fontsize=9,
                fontweight="bold",
                color="#22313f",
            )

    save_figure(fig, "data_quality_caveats_by_month.png")


def main() -> None:
    configure_style()
    metrics = collect_story_metrics()

    plot_monthly_attendance(metrics)
    plot_year_level_patterns(metrics)
    plot_assessment_scores(metrics)
    plot_quality_caveats(metrics)

    print("Pipeline C matplotlib story validation figures created:")
    for path in sorted(OUTPUT_DIR.glob("*.png")):
        print(f"- {path}")


if __name__ == "__main__":
    main()
