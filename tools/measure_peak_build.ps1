# Measures peak resident memory for a Nucleor build process tree.
# Used by verify.sh on Windows so the memory gate tracks crash risk
# instead of cumulative allocation churn.

param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$OutName,
    [Parameter(Mandatory = $true)][int]$BudgetMb,
    [int]$TimeoutSec = 120,
    [string]$Bin = "",
    [int]$WarningMb = 800,
    [int]$SampleMs = 100
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\rss_estop_lib.ps1"

$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Bin)) {
    $Bin = Join-Path $root "bin\nucleor.exe"
} elseif (-not [System.IO.Path]::IsPathRooted($Bin)) {
    $Bin = Join-Path $root $Bin
}

if (-not (Test-Path $Bin)) {
    Write-Host "FAIL: compiler binary not found: $Bin"
    exit 1
}
if ($WarningMb -ge $BudgetMb) { $WarningMb = [Math]::Max(1, $BudgetMb - 1) }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("nuc_peak_{0}_{1}" -f $PID, [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$stdoutPath = Join-Path $tmp "stdout.txt"
$stderrPath = Join-Path $tmp "stderr.txt"
$oldTrace = $env:NUC_TRACE_ALLOC

try {
    Remove-Item Env:\NUC_TRACE_ALLOC -ErrorAction SilentlyContinue

    Push-Location $root
    try {
        $args = @("build", $Source, "-o", $OutName, "--no-cache")
        $summary = Invoke-NucRssEstop `
            -FilePath $Bin `
            -ArgumentList $args `
            -WorkingDirectory $root `
            -BudgetMb $BudgetMb `
            -WarningMb $WarningMb `
            -TimeoutSec $TimeoutSec `
            -SampleMs $SampleMs `
            -StdoutPath $stdoutPath `
            -StderrPath $stderrPath
    } finally {
        Pop-Location
    }

    $peakRounded = [int][Math]::Ceiling([double]$summary.peak_mb)
    $wallRounded = [Math]::Round([double]$summary.wall_seconds, 3)

    if ($summary.killed) {
        Write-Host ("FAIL: {0} peak {1} MB / {2} MB e-stop, wall {3}s ({4})" -f $Source, $peakRounded, $BudgetMb, $wallRounded, $summary.reason)
        Write-Host ("       peak detail: {0}" -f $summary.peak_detail)
        exit 1
    }

    $exitCode = $summary.exit_code
    if ($null -eq $exitCode -or "$exitCode" -eq "") {
        $expectedExe = Join-Path $root ("target\{0}.exe" -f $OutName)
        if (Test-Path $expectedExe) { $exitCode = 0 } else { $exitCode = 1 }
    }

    if ([int]$exitCode -ne 0) {
        Write-Host ("FAIL: {0} build exited {1}, peak {2} MB / {3} MB e-stop, wall {4}s" -f $Source, $exitCode, $peakRounded, $BudgetMb, $wallRounded)
        if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Tail 8 }
        if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath -Tail 8 }
        exit 1
    }

    Write-Host ("OK: {0} peak {1} MB / {2} MB e-stop, wall {3}s" -f $Source, $peakRounded, $BudgetMb, $wallRounded)
    if ($summary.crossed_warning) {
        Write-Host ("WARN: crossed {0} MB at {1}s ({2})" -f $summary.warning_mb, $summary.warning_at_seconds, $summary.warning_detail)
    }
    exit 0
} finally {
    if ($null -eq $oldTrace) { Remove-Item Env:\NUC_TRACE_ALLOC -ErrorAction SilentlyContinue }
    else { $env:NUC_TRACE_ALLOC = $oldTrace }
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
