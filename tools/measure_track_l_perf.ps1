# Track L perf matrix: 10 cold + 10 hot samples per config under a
# process-tree memory cap. This script never kills unrelated nucleor/clang
# processes; it only stops descendants of the process it launched.

param(
    [int]$Samples = 10,
    [int]$BudgetMb = 1024,
    [int]$TimeoutSec = 180,
    [string]$OutputJson = "target/track_l_perf_measurements.json"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $root "bin\nucleor.exe"

if (-not (Test-Path $bin)) { throw "compiler binary missing: $bin" }
if ($Samples -lt 1) { throw "Samples must be >= 1" }

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
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("nuc_track_l_{0}_{1}" -f $PID, [Guid]::NewGuid().ToString("N"))
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
        $stdout = if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
        $stderr = if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
        $peakRounded = [int][Math]::Ceiling($peakMb)
        if ($killed) {
            throw "$Label failed: peak ${peakRounded} MB / ${BudgetMb} MB budget ($reason)"
        }
        if ([int]$proc.ExitCode -ne 0) {
            throw "$Label exited $($proc.ExitCode), peak ${peakRounded} MB / ${BudgetMb} MB budget`n$stdout`n$stderr"
        }
        return [pscustomobject]@{
            wall_seconds = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
            peak_mb = $peakRounded
            stdout = $stdout
            stderr = $stderr
        }
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

function Percentile([double[]]$Values, [double]$P) {
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) { return 0.0 }
    $rank = [Math]::Ceiling($sorted.Count * $P)
    if ($rank -lt 1) { $rank = 1 }
    if ($rank -gt $sorted.Count) { $rank = $sorted.Count }
    return [Math]::Round([double]$sorted[$rank - 1], 3)
}

function Summarize($Rows) {
    $cold = @($Rows | ForEach-Object { [double]$_.cold.wall_seconds })
    $hot = @($Rows | ForEach-Object { [double]$_.hot.wall_seconds })
    $peaks = @()
    foreach ($r in $Rows) {
        $peaks += [int]$r.cold.peak_mb
        $peaks += [int]$r.hot.peak_mb
    }
    return [pscustomobject]@{
        cold_p50_seconds = Percentile $cold 0.50
        cold_p95_seconds = Percentile $cold 0.95
        hot_p50_seconds = Percentile $hot 0.50
        hot_p95_seconds = Percentile $hot 0.95
        peak_mb = (($peaks | Measure-Object -Maximum).Maximum)
    }
}

$configs = @(
    [pscustomobject]@{
        name = "env-default-strict-intrin-on"
        source = "compiler/nucleor_s1_compiler.nr"
        out = "track_l_perf_default"
        strict_intrin = "1"
    },
    [pscustomobject]@{
        name = "env-off-strict-intrin-0"
        source = "compiler/nucleor_s1_compiler.nr"
        out = "track_l_perf_env_off"
        strict_intrin = "0"
    },
    [pscustomobject]@{
        name = "wrapping-everywhere-fixture"
        source = "tests/features/wrapping_everywhere_perf.nr"
        out = "track_l_perf_wrapping"
        strict_intrin = "1"
    }
)

$oldStrictIntrin = $env:NUCLEOR_INT_STRICT_INTRIN
$results = @()
Push-Location $root
try {
    foreach ($cfg in $configs) {
        $env:NUCLEOR_INT_STRICT_INTRIN = $cfg.strict_intrin
        $rows = @()
        for ($i = 1; $i -le $Samples; $i++) {
            Remove-Item -Recurse -Force ".nuc_cache", "target" -ErrorAction SilentlyContinue
            $cold = Invoke-CappedBuild @("build", $cfg.source, "-o", $cfg.out, "--cache-stats") "$($cfg.name) cold sample $i"
            $hot = Invoke-CappedBuild @("build", $cfg.source, "-o", $cfg.out, "--cache-stats") "$($cfg.name) hot sample $i"
            $rows += [pscustomobject]@{
                sample = $i
                cold = $cold
                hot = $hot
            }
            Write-Host ("{0} sample {1}/{2}: cold={3}s hot={4}s peak={5}/{6}MB" -f $cfg.name, $i, $Samples, $cold.wall_seconds, $hot.wall_seconds, $cold.peak_mb, $hot.peak_mb)
        }
        $results += [pscustomobject]@{
            name = $cfg.name
            source = $cfg.source
            strict_intrin = $cfg.strict_intrin
            samples = $rows
            summary = (Summarize $rows)
        }
    }
} finally {
    if ($null -eq $oldStrictIntrin) { Remove-Item Env:\NUCLEOR_INT_STRICT_INTRIN -ErrorAction SilentlyContinue }
    else { $env:NUCLEOR_INT_STRICT_INTRIN = $oldStrictIntrin }
    Pop-Location
}

$outPath = if ([System.IO.Path]::IsPathRooted($OutputJson)) { $OutputJson } else { Join-Path $root $OutputJson }
$outDir = Split-Path -Parent $outPath
if ($outDir) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
$payload = [pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    samples_per_config = $Samples
    budget_mb = $BudgetMb
    results = $results
}
$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding UTF8

Write-Host ""
Write-Host "Track L perf summary:"
foreach ($r in $results) {
    Write-Host ("  {0}: cold p50={1}s p95={2}s | hot p50={3}s p95={4}s | peak={5}MB" -f `
        $r.name, $r.summary.cold_p50_seconds, $r.summary.cold_p95_seconds, $r.summary.hot_p50_seconds, $r.summary.hot_p95_seconds, $r.summary.peak_mb)
}
Write-Host ("Wrote {0}" -f $outPath)
