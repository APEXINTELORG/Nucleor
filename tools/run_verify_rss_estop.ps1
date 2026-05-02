# Runs tools/verify.sh under a real-time process-tree RSS e-stop.
#
# This is the Windows guardrail for long verify runs. It is intentionally
# separate from Git Bash ulimit: ulimit caps virtual memory, while this
# watches actual resident memory for the launched bash process tree and
# kills that tree immediately if it crosses BudgetMb.

param(
    [ValidateSet("default", "0", "1")]
    [string]$StrictIntrin = "default",
    [int]$Jobs = 1,
    [int]$BudgetMb = 1000,
    [int]$WarningMb = 800,
    [int]$TimeoutSec = 3600,
    [int]$SampleMs = 100,
    [string]$CsvPath = "",
    [string]$StdoutPath = "",
    [string]$StderrPath = "",
    [string]$RunName = "",
    [string]$ExtraVerifyArgs = "--no-color"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\rss_estop_lib.ps1"

$root = Split-Path -Parent $PSScriptRoot
$bash = "C:\Program Files\Git\usr\bin\bash.exe"
if (-not (Test-Path $bash)) {
    $bash = "C:\Program Files\Git\bin\bash.exe"
}
if (-not (Test-Path $bash)) {
    throw "Git Bash not found at $bash"
}

if ($Jobs -lt 0) { throw "Jobs must be >= 0" }
if ($BudgetMb -lt 1) { throw "BudgetMb must be >= 1" }
if ($SampleMs -lt 25) { throw "SampleMs must be >= 25" }
if ($WarningMb -ge $BudgetMb) { throw "WarningMb must be lower than BudgetMb" }

if ([string]::IsNullOrWhiteSpace($RunName)) {
    $RunName = "verify_rss_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}

$targetDir = Join-Path $root "target"
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($StdoutPath)) {
    $StdoutPath = Join-Path $targetDir "${RunName}.stdout.log"
}
if ([string]::IsNullOrWhiteSpace($StderrPath)) {
    $StderrPath = Join-Path $targetDir "${RunName}.stderr.log"
}

Remove-Item -LiteralPath $StdoutPath, $StderrPath -ErrorAction SilentlyContinue

$tmpName = $RunName -replace "[^A-Za-z0-9_]", "_"
$csvSummary = $CsvPath
$bashCmd = "NUCLEOR_MEM_CAP_KB=0 NUC_VERIFY_JOBS=$Jobs NUC_VERIFY_TMPDIR=/tmp/$tmpName"
if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    $bashCmd = "$bashCmd NUC_VERIFY_CSV='$CsvPath'"
} else {
    $agent = $env:NUC_VERIFY_AGENT
    if ([string]::IsNullOrWhiteSpace($agent)) {
        $csvSummary = "(verify default)"
    } else {
        $csvSummary = "tools/verify_timings.$agent.csv"
    }
}
if ($StrictIntrin -ne "default") {
    $bashCmd = "$bashCmd NUCLEOR_INT_STRICT_INTRIN=$StrictIntrin"
}
$bashCmd = "$bashCmd ./tools/verify.sh $ExtraVerifyArgs"

# Start-Process on Windows passes the -lc command reliably when it is
# presented as one quoted ArgumentList string.
$arg = '-lc "' + ($bashCmd -replace '"', '\"') + '"'

$summary = Invoke-NucRssEstop `
    -FilePath $bash `
    -ArgumentString $arg `
    -UseArgumentString `
    -WorkingDirectory $root `
    -BudgetMb $BudgetMb `
    -WarningMb $WarningMb `
    -TimeoutSec $TimeoutSec `
    -SampleMs $SampleMs `
    -StdoutPath $StdoutPath `
    -StderrPath $StderrPath

$summary | Add-Member -NotePropertyName run_name -NotePropertyValue $RunName -Force
$summary | Add-Member -NotePropertyName jobs -NotePropertyValue $Jobs -Force
$summary | Add-Member -NotePropertyName strict_intrin -NotePropertyValue $StrictIntrin -Force
$summary | Add-Member -NotePropertyName csv -NotePropertyValue $csvSummary -Force

$summary | ConvertTo-Json -Depth 3
exit ([int]$summary.exit_code)
