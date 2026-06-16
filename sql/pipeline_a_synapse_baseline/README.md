# Pipeline A: Synapse Baseline SQL

These scripts support the original ADF + Synapse baseline pipeline.

Run order:

1. `00_create_external_objects.sql`
2. `01_create_staging_views.sql`
3. `06_data_quality_checks.sql`
4. `03_materialize_quality_results.sql`
5. `04_create_vault_tables.sql`
6. `05_create_curated_tables.sql`
7. `07_reporting_views.sql`

Utility script:

- `99_cleanup_rebuild_phase_3_4.sql`

Pipeline C SQL should not be added to this folder.
