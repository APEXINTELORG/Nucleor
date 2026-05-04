# tools/check_perf_regression.ps1
#
# Cold + hot self-build perf check. Catches the v0.3.205 footgun pattern
# (a single line that adds O(N-source) per-call overhead). Reads
# tools/perf_baseline.json for thresholds.
#
# Usage:
#   ./tools/check_perf_regression.ps1           # check; nonzero exit on regression
#   ./tools/check_perf_regression.ps1 -Update   # re-record baseline (after intentional changes)
#   ./tools/check_perf_regression.ps1 -Quiet    # only output on regression
#
# Exit 0 = within thresholds. Exit 1 = regression detected.

param(
    [switch]$Update,
    [switch]$Quiet,
    [int]$BudgetMb = 1000,
    [int]$TimeoutSec = 180,
    [int]$WarningMb = 800,
    [int]$SampleMs = 100
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\rss_estop_lib.ps1"
$root = Split-Path -Parent $PSScriptRoot
$baseline_path = Join-Path $root "tools/perf_baseline.json"
$bin = Join-Path $root "bin/nucleor.exe"
$src = Join-Path $root "compiler/nucleor_s1_compiler.nr"

if (-not (Test-Path $baseline_path)) { Write-Host "ERROR: baseline missing: $baseline_path" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $bin)) { Write-Host "ERROR: bin/nucleor.exe missing" -ForegroundColor Red; exit 1 }
if ($WarningMb -ge $BudgetMb) { $WarningMb = [Math]::Max(1, $BudgetMb - 1) }

$baseline = Get-Content $baseline_path -Raw | ConvertFrom-Json

function Get-NucPerfHostSnapshot {
    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $cpu = "n/a"
    $logical = "n/a"
    try {
        $processors = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
        if ($processors.Count -gt 0) {
            $cpuVals = @($processors | ForEach-Object { [double]$_.LoadPercentage })
            $cpu = [Math]::Round((($cpuVals | Measure-Object -Average).Average), 1)
            $logical = (($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum)
        }
    } catch { }

    $top = "n/a"
    try {
        $top = ((Get-Process -ErrorAction Stop |
            Where-Object { $null -ne $_.CPU } |
            Sort-Object CPU -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                "{0}:{1}:cpu={2:n1}:rss={3:n0}MB" -f $_.ProcessName, $_.Id, $_.CPU, ($_.WorkingSet64 / 1MB)
            }) -join ", ")
        if ([string]::IsNullOrWhiteSpace($top)) { $top = "n/a" }
    } catch { }

    return [pscustomobject]@{
        Stamp = $stamp
        CpuPercent = $cpu
        LogicalProcessors = $logical
        TopCpu = $top
    }
}

function Format-NucPerfHostSnapshot($Snapshot) {
    return ("{0} | cpu={1}% logical={2} | top_cpu={3}" -f
        $Snapshot.Stamp, $Snapshot.CpuPercent, $Snapshot.LogicalProcessors, $Snapshot.TopCpu)
}

function Invoke-CappedBuild([string[]]$ArgsList, [string]$Label) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("nuc_perf_{0}_{1}" -f $PID, [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $stdoutPath = Join-Path $tmp "stdout.txt"
    $stderrPath = Join-Path $tmp "stderr.txt"
    try {
        $summary = Invoke-NucRssEstop `
            -FilePath $bin `
            -ArgumentList $ArgsList `
            -WorkingDirectory $root `
            -BudgetMb $BudgetMb `
            -WarningMb $WarningMb `
            -TimeoutSec $TimeoutSec `
            -SampleMs $SampleMs `
            -StdoutPath $stdoutPath `
            -StderrPath $stderrPath

        $peakRounded = [int][Math]::Ceiling([double]$summary.peak_mb)
        if ($summary.killed) {
            throw "$Label failed: peak ${peakRounded} MB / ${BudgetMb} MB e-stop ($($summary.reason)); $($summary.peak_detail)"
        }
        if ([int]$summary.exit_code -ne 0) {
            $tail = ""
            if (Test-Path $stdoutPath) { $tail += (Get-Content -LiteralPath $stdoutPath -Tail 8 | Out-String) }
            if (Test-Path $stderrPath) { $tail += (Get-Content -LiteralPath $stderrPath -Tail 8 | Out-String) }
            throw "$Label exited $($summary.exit_code), peak ${peakRounded} MB / ${BudgetMb} MB e-stop`n$tail"
        }
        $cacheLine = ""
        $stdoutTail = ""
        $stderrTail = ""
        if (Test-Path $stdoutPath) {
            $cacheLine = (Get-Content -LiteralPath $stdoutPath |
                Select-String -Pattern '^cache:' |
                Select-Object -Last 1 |
                ForEach-Object { $_.Line })
            if ($null -eq $cacheLine) { $cacheLine = "" }
            $stdoutTail = (Get-Content -LiteralPath $stdoutPath -Tail 16 | Out-String)
        }
        if (Test-Path $stderrPath) {
            $stderrTail = (Get-Content -LiteralPath $stderrPath -Tail 16 | Out-String)
        }
        return [pscustomobject]@{
            WallSec = [double]$summary.wall_seconds
            PeakMb = $peakRounded
            CrossedWarning = [bool]$summary.crossed_warning
            WarningDetail = [string]$summary.warning_detail
            CacheLine = [string]$cacheLine
            StdoutTail = [string]$stdoutTail
            StderrTail = [string]$stderrTail
        }
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

function Get-MedianSeconds($Results) {
    $vals = @($Results | ForEach-Object { [double]$_.WallSec } | Sort-Object)
    if ($vals.Count -eq 0) { return 0.0 }
    $mid = [int][Math]::Floor($vals.Count / 2)
    if (($vals.Count % 2) -eq 1) { return [double]$vals[$mid] }
    return ([double]$vals[$mid - 1] + [double]$vals[$mid]) / 2.0
}

$hostStart = Get-NucPerfHostSnapshot

Push-Location $root
try {
    # Cold cache: clear .nuc_cache + target before each sample.
    # Report median wall time so one Windows scheduler / linker outlier
    # does not fail an otherwise stable compiler. Peak memory remains
    # the max across all samples.
    $coldResults = @()
    $cold_mem_mb = 0
    for ($coldSample = 1; $coldSample -le 3; $coldSample++) {
        Remove-Item -Recurse -Force .nuc_cache,target -ErrorAction SilentlyContinue
        $coldResult = Invoke-CappedBuild @("build", $src, "-o", "nuc_perf_check") "cold self-build sample $coldSample"
        if ($coldResult.CacheLine -notmatch '^cache: miss') {
            throw "cold self-build sample $coldSample did not start from cold cache: $($coldResult.CacheLine)`nstdout tail:`n$($coldResult.StdoutTail)`nstderr tail:`n$($coldResult.StderrTail)"
        }
        $coldResults += $coldResult
        if ($coldResult.PeakMb -gt $cold_mem_mb) { $cold_mem_mb = $coldResult.PeakMb }
    }
    $cold = Get-MedianSeconds $coldResults

    # Hot cache: immediate re-runs, no cleanup. Use a 3-sample median
    # so OS process-spawn / scheduler jitter cannot fail the gate, but
    # still fail if any hot run exits nonzero or misses the cache.
    $hotResults = @()
    for ($hotSample = 1; $hotSample -le 3; $hotSample++) {
        $hotResult = Invoke-CappedBuild @("build", $src, "-o", "nuc_perf_check") "hot self-build sample $hotSample"
        if ($hotResult.CacheLine -notmatch '^cache: hit') {
            throw "hot self-build sample $hotSample did not hit cache: $($hotResult.CacheLine)`nstdout tail:`n$($hotResult.StdoutTail)`nstderr tail:`n$($hotResult.StderrTail)"
        }
        $hotResults += $hotResult
        if ($hotResult.PeakMb -gt $cold_mem_mb) { $cold_mem_mb = $hotResult.PeakMb }
    }
    $hot = Get-MedianSeconds $hotResults
    $hot_mem_mb = ($hotResults | ForEach-Object { [int]$_.PeakMb } | Measure-Object -Maximum).Maximum
    $crossed_warning = $false
    foreach ($coldResult in $coldResults) {
        if ($coldResult.CrossedWarning) { $crossed_warning = $true }
    }
    foreach ($hotResult in $hotResults) {
        if ($hotResult.CrossedWarning) { $crossed_warning = $true }
    }
} finally {
    Pop-Location
}

$hostEnd = Get-NucPerfHostSnapshot

$cold_max = [double]$baseline.cold_max_allowed_seconds
$hot_max = [double]$baseline.hot_max_allowed_seconds
$cold_baseline = [double]$baseline.cold_self_build_seconds
$hot_baseline = [double]$baseline.hot_self_build_seconds
$mem_max = [int]$baseline.cold_max_allowed_memory_mb
$mem_baseline = [int]$baseline.cold_peak_memory_mb

$cold_round = [math]::Round($cold, 2)
$hot_round = [math]::Round($hot, 2)

if ($Update) {
    $baseline.cold_self_build_seconds = $cold_round
    $baseline.hot_self_build_seconds = $hot_round
    $baseline.cold_peak_memory_mb = $cold_mem_mb
    $baseline.version_locked_at = "manual"
    $baseline.locked_at_date = (Get-Date).ToString("yyyy-MM-dd")
    $baseline | ConvertTo-Json -Depth 4 | Set-Content $baseline_path
    Write-Host ("UPDATED baseline: cold={0}s hot={1}s mem={2}MB" -f $cold_round, $hot_round, $cold_mem_mb) -ForegroundColor Green
    exit 0
}

$cold_ok = $cold -le $cold_max
$hot_ok = $hot -le $hot_max
$mem_ok = $cold_mem_mb -le $mem_max

if ($cold_ok -and $hot_ok -and $mem_ok) {
    if (-not $Quiet) {
        Write-Host ("OK perf: cold={0}s (max {1}s) | hot={2}s (max {3}s) | peak_mem={4}MB (max {5}MB)" -f
            $cold_round, $cold_max, $hot_round, $hot_max, $cold_mem_mb, $mem_max) -ForegroundColor Green
        Write-Host ("  host start: {0}" -f (Format-NucPerfHostSnapshot $hostStart))
        Write-Host ("  host end:   {0}" -f (Format-NucPerfHostSnapshot $hostEnd))
        if ($crossed_warning) {
            Write-Host ("WARN: perf check crossed {0} MB warning before staying under e-stop" -f $WarningMb) -ForegroundColor Yellow
        }
    }
    exit 0
}

Write-Host ""
Write-Host "PERF REGRESSION DETECTED" -ForegroundColor Red -BackgroundColor Black
Write-Host ("  host start: {0}" -f (Format-NucPerfHostSnapshot $hostStart))
Write-Host ("  host end:   {0}" -f (Format-NucPerfHostSnapshot $hostEnd))
Write-Host ""
if (-not $cold_ok) {
    $cold_x = [math]::Round($cold / $cold_baseline, 1)
    Write-Host ("  COLD self-build: {0}s vs baseline {1}s ({2}x slower, max {3}s)" -f
        $cold_round, $cold_baseline, $cold_x, $cold_max) -ForegroundColor Red
}
if (-not $hot_ok) {
    $hot_x = [math]::Round($hot / $hot_baseline, 1)
    Write-Host ("  HOT self-build:  {0}s vs baseline {1}s ({2}x slower, max {3}s)" -f
        $hot_round, $hot_baseline, $hot_x, $hot_max) -ForegroundColor Red
}
if (-not $mem_ok) {
    $mem_x = [math]::Round($cold_mem_mb / [double]$mem_baseline, 1)
    Write-Host ("  PEAK MEMORY:     {0}MB vs baseline {1}MB ({2}x larger, max {3}MB)" -f
        $cold_mem_mb, $mem_baseline, $mem_x, $mem_max) -ForegroundColor Red
}
Write-Host ""
Write-Host "Common causes:" -ForegroundColor Yellow
Write-Host "  - Runtime helper added strlen() / vec_len() per call (scales with caller's input size)"
Write-Host "  - Bounds check that scans the whole source per substring/index"
Write-Host "  - Hot-path helper added a function call instead of inline op"
Write-Host "  - Cache or memoization invalidated by minor edit"
Write-Host ""
Write-Host "Fix path:"
Write-Host "  1. ./bin/nucleor.exe build compiler/nucleor_s1_compiler.nr -o tmp --time-passes"
Write-Host "     -> see which phase regressed; investigate code added there"
Write-Host "  2. Compare against last good v0.3.x via git log"
Write-Host "  3. Once fixed: ./tools/check_perf_regression.ps1 -Update"
exit 1
