# Pipeline C Scripts

This folder contains scripts for Pipeline C: Monthly Education Insights Reporting.

## Current Scripts

- `generate_pipeline_c_data.py` generates the Pipeline C synthetic source data.
- `plot_pipeline_c_story.py` creates matplotlib PNG figures to validate the synthetic analytics story.
- `upload_pipeline_c_monthly_data.ps1` uploads generated month folders to ADLS with Azure CLI and writes `_READY.json` last to trigger ADF.

## Generated Output

The generator writes to `data/pipeline_c_monthly_insights/`.

It creates:

- `month=2024-01/` as the initial production-style snapshot;
- `month=2024-02/` to `month=2025-12/` as monthly change batches;
- `generation_summary.json` as a run summary.

## Story Coverage

The generated data is shaped to support the Block 1 analytics story:

- richer attendance seasonality, including winter decline;
- Year 7 transition pattern;
- senior secondary attendance volatility;
- attendance-to-assessment relationship;
- reporting caveats from intentional data quality defects.

## How To Run

From the repository root:

```powershell
python scripts\pipeline_c_monthly_insights\generate_pipeline_c_data.py
python scripts\pipeline_c_monthly_insights\plot_pipeline_c_story.py
```

Re-running the script replaces `data/pipeline_c_monthly_insights/`.

The plotting script writes story-validation PNG figures to `images/pipeline_c_monthly_insights/story_validation/`.
It requires `matplotlib` in the active Python environment.

To test the Azure upload script without writing to ADLS:

```powershell
.\scripts\pipeline_c_monthly_insights\upload_pipeline_c_monthly_data.ps1 -StartMonth "2024-01" -EndMonth "2024-03" -DryRun
```

To upload all Pipeline C months and trigger ADF one month at a time:

```powershell
az login
.\scripts\pipeline_c_monthly_insights\upload_pipeline_c_monthly_data.ps1 -StartMonth "2024-01" -EndMonth "2025-12"
```

The script waits 390 seconds after each non-final `_READY.json` upload by default, so the next month is not triggered while the previous monthly pipeline is still running.

## Planned Next Scripts

- exported SQL or reporting validation helpers if needed.
