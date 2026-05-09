# Data Model Diagram

## Overview

This project uses three modelling layers after ingestion:

1. Staging views over ADLS Gen2 staged files.
2. A lightweight Data Vault layer materialised to ADLS Gen2 as Parquet.
3. A curated dimensional model materialised to ADLS Gen2 as Parquet and exposed through SQL reporting views.

## Lakehouse Modelling Flow

```mermaid
%%{init: {"themeVariables": {"fontSize": "18px"}}}%%
flowchart TD
    Raw["ADLS raw zone<br/>CSV / JSON source files"]
    StagingFiles["ADLS staging zone<br/>ADF raw-to-staging copy"]
    StagingViews["Synapse staging views<br/>stg_*"]
    DQ["Data quality view<br/>dq_validation_results"]
    QualityParquet["ADLS quality zone<br/>validation_results Parquet"]
    Vault["ADLS vault zone<br/>hubs, links, satellites Parquet"]
    Curated["ADLS curated zone<br/>dimensions and facts Parquet"]
    Reporting["SQL reporting views<br/>vw_*"]

    Raw --> StagingFiles
    StagingFiles --> StagingViews
    StagingViews --> DQ
    DQ --> QualityParquet
    StagingViews --> Vault
    Vault --> Curated
    Curated --> Reporting
```

## Lightweight Data Vault Model

```mermaid
%%{init: {"themeVariables": {"fontSize": "18px"}}}%%
erDiagram
    HUB_SCHOOL {
        varchar school_id PK
        datetime2 load_timestamp
        varchar record_source
    }

    HUB_STUDENT {
        varchar student_id PK
        datetime2 load_timestamp
        varchar record_source
    }

    HUB_ASSESSMENT {
        varchar assessment_id PK
        datetime2 load_timestamp
        varchar record_source
    }

    HUB_EVENT {
        varchar event_id PK
        datetime2 load_timestamp
        varchar record_source
    }

    LINK_STUDENT_SCHOOL {
        varchar student_id FK
        varchar school_id FK
        datetime2 load_timestamp
        varchar record_source
    }

    LINK_STUDENT_ASSESSMENT {
        varchar student_id FK
        varchar assessment_id FK
        datetime2 load_timestamp
        varchar record_source
    }

    LINK_SCHOOL_EVENT {
        varchar school_id FK
        varchar event_id FK
        datetime2 load_timestamp
        varchar record_source
    }

    SAT_SCHOOL_DETAILS {
        varchar school_id FK
        varchar school_name
        varchar region
        varchar school_type
        date open_date
        varchar status
        datetime2 load_timestamp
        varchar record_source
    }

    SAT_STUDENT_DETAILS {
        varchar student_id FK
        varchar school_id
        int year_level
        varchar gender
        date enrolment_date
        varchar status
        datetime2 load_timestamp
        varchar record_source
    }

    SAT_ATTENDANCE_RECORD {
        varchar attendance_id
        varchar student_id
        varchar school_id
        date attendance_month
        int possible_days
        int attended_days
        varchar absence_reason
        datetime2 load_timestamp
        varchar record_source
    }

    SAT_ASSESSMENT_RESULT {
        varchar assessment_id FK
        varchar student_id
        varchar school_id
        int assessment_year
        varchar domain
        int score
        varchar proficiency_band
        datetime2 load_timestamp
        varchar record_source
    }

    SAT_EVENT_DETAILS {
        varchar event_id FK
        varchar school_id
        varchar event_type
        date event_date
        varchar description
        datetime2 load_timestamp
        varchar record_source
    }

    HUB_STUDENT ||--o{ LINK_STUDENT_SCHOOL : student_id
    HUB_SCHOOL ||--o{ LINK_STUDENT_SCHOOL : school_id

    HUB_STUDENT ||--o{ LINK_STUDENT_ASSESSMENT : student_id
    HUB_ASSESSMENT ||--o{ LINK_STUDENT_ASSESSMENT : assessment_id

    HUB_SCHOOL ||--o{ LINK_SCHOOL_EVENT : school_id
    HUB_EVENT ||--o{ LINK_SCHOOL_EVENT : event_id

    HUB_SCHOOL ||--o{ SAT_SCHOOL_DETAILS : school_id
    HUB_STUDENT ||--o{ SAT_STUDENT_DETAILS : student_id
    HUB_ASSESSMENT ||--o{ SAT_ASSESSMENT_RESULT : assessment_id
    HUB_EVENT ||--o{ SAT_EVENT_DETAILS : event_id
```

## Curated Dimensional Model

```mermaid
%%{init: {"themeVariables": {"fontSize": "18px"}}}%%
erDiagram
    DIM_SCHOOL {
        varchar school_key PK
        varchar school_name
        varchar region
        varchar school_type
        date open_date
        varchar status
        datetime2 load_timestamp
    }

    DIM_STUDENT_GROUP {
        bigint student_group_key PK
        varchar school_key FK
        int year_level
        varchar gender
        varchar student_status
        bigint student_count
        datetime2 load_timestamp
    }

    DIM_DATE {
        int date_key PK
        date calendar_date
        int calendar_year
        int calendar_month
        varchar month_name
        int calendar_quarter
        datetime2 load_timestamp
    }

    DIM_ASSESSMENT_DOMAIN {
        bigint assessment_domain_key PK
        varchar assessment_domain
        datetime2 load_timestamp
    }

    DIM_EVENT_TYPE {
        bigint event_type_key PK
        varchar event_type
        datetime2 load_timestamp
    }

    FACT_ATTENDANCE {
        varchar attendance_id
        varchar student_id
        varchar school_key FK
        int date_key FK
        bigint student_group_key FK
        int possible_days
        int attended_days
        int absence_days
        decimal attendance_rate
        decimal absence_rate
        int chronic_absence_flag
        int is_valid_attendance
        datetime2 load_timestamp
    }

    FACT_ASSESSMENT {
        varchar assessment_id
        varchar student_id
        varchar school_key FK
        int date_key FK
        bigint assessment_domain_key FK
        bigint student_group_key FK
        int score
        varchar proficiency_band
        int is_valid_score
        int low_proficiency_flag
        datetime2 load_timestamp
    }

    FACT_SCHOOL_EVENTS {
        varchar event_id
        varchar school_key FK
        int date_key FK
        bigint event_type_key FK
        int event_count
        datetime2 load_timestamp
    }

    DIM_SCHOOL ||--o{ DIM_STUDENT_GROUP : school_key
    DIM_SCHOOL ||--o{ FACT_ATTENDANCE : school_key
    DIM_DATE ||--o{ FACT_ATTENDANCE : date_key
    DIM_STUDENT_GROUP ||--o{ FACT_ATTENDANCE : student_group_key

    DIM_SCHOOL ||--o{ FACT_ASSESSMENT : school_key
    DIM_DATE ||--o{ FACT_ASSESSMENT : date_key
    DIM_ASSESSMENT_DOMAIN ||--o{ FACT_ASSESSMENT : assessment_domain_key
    DIM_STUDENT_GROUP ||--o{ FACT_ASSESSMENT : student_group_key

    DIM_SCHOOL ||--o{ FACT_SCHOOL_EVENTS : school_key
    DIM_DATE ||--o{ FACT_SCHOOL_EVENTS : date_key
    DIM_EVENT_TYPE ||--o{ FACT_SCHOOL_EVENTS : event_type_key
```

## Reporting Views

| View | Purpose |
|---|---|
| `vw_attendance_by_school` | Attendance rate and absence metrics by school and month |
| `vw_attendance_by_year_level` | Attendance metrics by school, year level, gender, and student status |
| `vw_assessment_by_school` | Assessment outcomes by school, year, and domain |
| `vw_assessment_by_domain` | Assessment outcomes by year and domain |
| `vw_data_quality_summary` | Data quality results for monitoring and reporting |

## Modelling Notes

- Staging views standardise source files and preserve source lineage.
- The Data Vault layer keeps business keys, relationships, and descriptive details separated.
- The curated layer is stricter than the vault layer and is designed for reporting.
- Invalid measure values are retained in some facts with validity flags, while orphan key records are excluded from reporting facts.
- `dim_student_group` is used instead of an individual `dim_student` to keep reporting aggregated and privacy-aware.
