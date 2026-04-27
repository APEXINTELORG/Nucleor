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
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$baseline_path = Join-Path $root "tools/perf_baseline.json"
$bin = Join-Path $root "bin/nucleor.exe"
$src = Join-Path $root "compiler/nucleor_s1_compiler.nr"

if (-not (Test-Path $baseline_path)) { Write-Host "ERROR: baseline missing: $baseline_path" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $bin)) { Write-Host "ERROR: bin/nucleor.exe missing" -ForegroundColor Red; exit 1 }

$baseline = Get-Content $baseline_path -Raw | ConvertFrom-Json

# Kill any stale processes that would skew measurements
Get-Process nucleor*,clang* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Push-Location $root
try {
    # Cold cache: clear .nuc_cache + target, then time + measure peak memory.
    Remove-Item -Recurse -Force .nuc_cache,target -ErrorAction SilentlyContinue
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath $bin -ArgumentList @("build", $src, "-o", "nuc_perf_check") -PassThru -WindowStyle Hidden -RedirectStandardOutput "perf_stdout.tmp" -RedirectStandardError "perf_stderr.tmp"
    $peak_mb = 0
    while (-not $proc.HasExited) {
        try {
            $proc.Refresh()
            $cur_mb = [int]($proc.PeakWorkingSet64 / 1MB)
            if ($cur_mb -gt $peak_mb) { $peak_mb = $cur_mb }
        } catch {}
        Start-Sleep -Milliseconds 50
    }
    $sw.Stop()
    # Final read after exit
    try { $proc.Refresh(); $final_peak = [int]($proc.PeakWorkingSet64 / 1MB); if ($final_peak -gt $peak_mb) { $peak_mb = $final_peak } } catch {}
    $cold = $sw.Elapsed.TotalSeconds
    $cold_mem_mb = $peak_mb

    Remove-Item -Force perf_stdout.tmp,perf_stderr.tmp -ErrorAction SilentlyContinue

    # Hot cache: immediate re-run, no cleanup
    $hot = (Measure-Command { & $bin build $src -o nuc_perf_check 2>&1 | Out-Null }).TotalSeconds
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
