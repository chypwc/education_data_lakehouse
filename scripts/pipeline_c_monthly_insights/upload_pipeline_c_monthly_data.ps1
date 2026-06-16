param(
    [string]$AccountName = "steduinsightsdev",
    [string]$FileSystem = "education-lakehouse",
    [string]$LocalRoot = "data\pipeline_c_monthly_insights",
    [string]$StartMonth = "2024-01",
    [string]$EndMonth = "2025-12",
    [int]$DelaySeconds = 330,
    [ValidateSet("login", "key")]
    [string]$AuthMode = "login",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-MonthDate {
    param([string]$Month)

    return [datetime]::ParseExact($Month, "yyyy-MM", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-MonthRange {
    param(
        [string]$Start,
        [string]$End
    )

    $current = ConvertTo-MonthDate -Month $Start
    $last = ConvertTo-MonthDate -Month $End

    if ($current -gt $last) {
        throw "StartMonth must be earlier than or equal to EndMonth."
    }

    while ($current -le $last) {
        $current.ToString("yyyy-MM")
        $current = $current.AddMonths(1)
    }
}

function Get-MonthFiles {
    param([string]$LoadMode)

    if ($LoadMode -eq "INITIAL_SNAPSHOT") {
        return @(
            "schools.csv",
            "students.csv",
            "attendance.csv",
            "assessment_results.csv",
            "school_events.json"
        )
    }

    return @(
        "schools_delta.csv",
        "students_delta.csv",
        "attendance.csv",
        "assessment_results_delta.csv",
        "school_events.json"
    )
}

function Invoke-AzUpload {
    param(
        [string]$Source,
        [string]$DestinationPath
    )

    $arguments = @(
        "storage", "fs", "file", "upload",
        "--account-name", $AccountName,
        "--file-system", $FileSystem,
        "--path", $DestinationPath,
        "--source", $Source,
        "--auth-mode", $AuthMode,
        "--overwrite", "true"
    )

    if ($DryRun) {
        Write-Host "[DRY RUN] az $($arguments -join ' ')"
        return
    }

    az @arguments | Out-Host
}

function Upload-PipelineCMonth {
    param([string]$Month)

    $loadMode = if ($Month -eq "2024-01") { "INITIAL_SNAPSHOT" } else { "MONTHLY_CHANGE" }
    $sourceBatchId = $Month.Replace("-", "_")
    $localMonthPath = Join-Path $LocalRoot "month=$Month"
    $remoteMonthPath = "raw/month=$Month"

    if (-not (Test-Path -Path $localMonthPath -PathType Container)) {
        throw "Local month folder not found: $localMonthPath"
    }

    Write-Host ""
    Write-Host "Uploading month=$Month ($loadMode)"

    foreach ($fileName in (Get-MonthFiles -LoadMode $loadMode)) {
        $sourcePath = Join-Path $localMonthPath $fileName

        if (-not (Test-Path -Path $sourcePath -PathType Leaf)) {
            throw "Expected source file not found: $sourcePath"
        }

        Invoke-AzUpload `
            -Source $sourcePath `
            -DestinationPath "$remoteMonthPath/$fileName"
    }

    $readyPath = Join-Path $env:TEMP "_READY_$sourceBatchId.json"
    $readyPayload = [ordered]@{
        reporting_month = $Month
        source_batch_id = $sourceBatchId
        load_mode = $loadMode
        uploaded_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] Would write $readyPath with:"
        $readyPayload | ConvertTo-Json | Write-Host
    }
    else {
        $readyPayload | ConvertTo-Json | Set-Content -Path $readyPath -Encoding UTF8
    }

    Invoke-AzUpload `
        -Source $readyPath `
        -DestinationPath "$remoteMonthPath/_READY.json"

    Write-Host "Uploaded _READY.json for month=$Month"
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI was not found. Install Azure CLI or run this script from a shell where az is available."
}

$months = @(Get-MonthRange -Start $StartMonth -End $EndMonth)

Write-Host "Pipeline C ADLS upload"
Write-Host "Account: $AccountName"
Write-Host "File system: $FileSystem"
Write-Host "Local root: $LocalRoot"
Write-Host "Range: $StartMonth to $EndMonth"
Write-Host "Delay after each non-final _READY.json upload: $DelaySeconds seconds"
Write-Host "Dry run: $DryRun"

for ($i = 0; $i -lt $months.Count; $i++) {
    Upload-PipelineCMonth -Month $months[$i]

    if ($i -lt ($months.Count - 1)) {
        Write-Host "Waiting $DelaySeconds seconds before uploading the next month..."
        Start-Sleep -Seconds $DelaySeconds
    }
}

Write-Host ""
Write-Host "Upload sequence complete."
