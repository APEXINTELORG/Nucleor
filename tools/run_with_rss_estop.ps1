# Runs an arbitrary command under a real-time process-tree RSS e-stop.

param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$ArgumentList = @(),
    [string]$ArgumentString = "",
    [switch]$UseArgumentString,
    [string]$WorkingDirectory = "",
    [int]$BudgetMb = 1000,
    [int]$WarningMb = 800,
    [int]$TimeoutSec = 0,
    [int]$SampleMs = 100,
    [string]$StdoutPath = "",
    [string]$StderrPath = "",
    [string]$SummaryPath = "",
    [switch]$Json,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments = @()
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\rss_estop_lib.ps1"

if ($ArgumentList.Count -eq 0 -and $RemainingArguments.Count -gt 0) {
    $ArgumentList = $RemainingArguments
}

$summary = Invoke-NucRssEstop `
    -FilePath $FilePath `
    -ArgumentList $ArgumentList `
    -ArgumentString $ArgumentString `
    -UseArgumentString:$UseArgumentString `
    -WorkingDirectory $WorkingDirectory `
    -BudgetMb $BudgetMb `
    -WarningMb $WarningMb `
    -TimeoutSec $TimeoutSec `
    -SampleMs $SampleMs `
    -StdoutPath $StdoutPath `
    -StderrPath $StderrPath

if (-not [string]::IsNullOrWhiteSpace($SummaryPath)) {
    $summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $SummaryPath
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 4
} else {
    $state = if ($summary.killed) { "KILLED" } elseif ($summary.exit_code -eq 0) { "OK" } else { "FAIL" }
    Write-Host ("{0}: exit={1} peak={2} MB / {3} MB e-stop, wall={4}s" -f
        $state, $summary.exit_code, $summary.peak_mb, $summary.budget_mb, $summary.wall_seconds)
    if ($summary.crossed_warning) {
        Write-Host ("WARN: crossed {0} MB at {1}s ({2})" -f
            $summary.warning_mb, $summary.warning_at_seconds, $summary.warning_detail)
    }
    if ($summary.reason) {
        Write-Host ("reason: {0}" -f $summary.reason)
    }
    Write-Host ("peak_detail: {0}" -f $summary.peak_detail)
    Write-Host ("stdout: {0}" -f $summary.stdout)
    Write-Host ("stderr: {0}" -f $summary.stderr)
}

exit ([int]$summary.exit_code)
