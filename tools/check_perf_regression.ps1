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
    [int]$BudgetMb = 1024,
    [int]$TimeoutSec = 180
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$baseline_path = Join-Path $root "tools/perf_baseline.json"
$bin = Join-Path $root "bin/nucleor.exe"
$src = Join-Path $root "compiler/nucleor_s1_compiler.nr"

if (-not (Test-Path $baseline_path)) { Write-Host "ERROR: baseline missing: $baseline_path" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $bin)) { Write-Host "ERROR: bin/nucleor.exe missing" -ForegroundColor Red; exit 1 }

$baseline = Get-Content $baseline_path -Raw | ConvertFrom-Json

function Get-ProcessTreeIds([int]$RootPid) {
    $ids = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootPid)
    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        if (-not $ids.Contains($id)) { $ids.Add($id) }
        Get-CimInstance Win32_Process -Filter "ParentProcessId = $id" -ErrorAction SilentlyContinue |
            ForEach-Object { $queue.Enqueue([int]$_.ProcessId) }
    }
    return $ids
}

function Stop-ProcessTree([int[]]$Ids) {
    foreach ($id in $Ids) {
        try { Stop-Process -Id $id -Force -ErrorAction Stop } catch { }
    }
}

function Invoke-CappedBuild([string[]]$ArgsList, [string]$Label) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("nuc_perf_{0}_{1}" -f $PID, [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $stdoutPath = Join-Path $tmp "stdout.txt"
    $stderrPath = Join-Path $tmp "stderr.txt"
    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $proc = Start-Process -FilePath $bin `
            -ArgumentList $ArgsList `
            -WorkingDirectory $root `
            -WindowStyle Hidden `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        $peakMb = 0.0
        $killed = $false
        $reason = ""
        while (-not $proc.HasExited) {
            $ids = Get-ProcessTreeIds $proc.Id
            $sum = 0L
            foreach ($id in $ids) {
                try { $sum += (Get-Process -Id $id -ErrorAction Stop).WorkingSet64 } catch { }
            }
            $curMb = $sum / 1MB
            if ($curMb -gt $peakMb) { $peakMb = $curMb }
            if ($curMb -gt $BudgetMb) {
                $killed = $true
                $reason = "peak exceeded ${BudgetMb} MB budget"
                Stop-ProcessTree $ids
                break
            }
            if ($sw.Elapsed.TotalSeconds -gt $TimeoutSec) {
                $killed = $true
                $reason = "timeout exceeded ${TimeoutSec}s"
                Stop-ProcessTree $ids
                break
            }
            Start-Sleep -Milliseconds 50
            try { $proc.Refresh() } catch { }
        }
        if (-not $killed) {
            $proc.WaitForExit()
            $proc.Refresh()
        }
        $sw.Stop()
        $peakRounded = [int][Math]::Ceiling($peakMb)
        if ($killed) {
            throw "$Label failed: peak ${peakRounded} MB / ${BudgetMb} MB budget ($reason)"
        }
        if ([int]$proc.ExitCode -ne 0) {
            $tail = ""
            if (Test-Path $stdoutPath) { $tail += (Get-Content -LiteralPath $stdoutPath -Tail 8 | Out-String) }
            if (Test-Path $stderrPath) { $tail += (Get-Content -LiteralPath $stderrPath -Tail 8 | Out-String) }
            throw "$Label exited $($proc.ExitCode), peak ${peakRounded} MB / ${BudgetMb} MB budget`n$tail"
        }
        return [pscustomobject]@{
            WallSec = $sw.Elapsed.TotalSeconds
            PeakMb = $peakRounded
        }
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

Push-Location $root
try {
    # Cold cache: clear .nuc_cache + target, then time + measure peak memory.
    Remove-Item -Recurse -Force .nuc_cache,target -ErrorAction SilentlyContinue
    $coldResult = Invoke-CappedBuild @("build", $src, "-o", "nuc_perf_check") "cold self-build"
    $cold = $coldResult.WallSec
    $cold_mem_mb = $coldResult.PeakMb

    # Hot cache: immediate re-run, no cleanup
    $hotResult = Invoke-CappedBuild @("build", $src, "-o", "nuc_perf_check") "hot self-build"
    $hot = $hotResult.WallSec
    $hot_mem_mb = $hotResult.PeakMb
    if ($hot_mem_mb -gt $cold_mem_mb) { $cold_mem_mb = $hot_mem_mb }
} finally {
    Pop-Location
}

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
    }
    exit 0
}

Write-Host ""
Write-Host "PERF REGRESSION DETECTED" -ForegroundColor Red -BackgroundColor Black
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
