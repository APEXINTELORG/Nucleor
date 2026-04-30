# E-stop wrapper for the probe agent.
#
# Source once per session:
#   . .\tools\run_capped.ps1
#
# Run a process under a 1 GB RSS hard cap. If RSS crosses the cap the
# process is killed immediately — this is the system-protect safety net,
# not a perf gate. Returns peak RSS + wall time.
#
# Drift detection (the +10% warning above baseline) is a SEPARATE tool:
#   .\tools\check_perf_regression.ps1   # cold/hot self-build vs perf_baseline.json
# Run that after every rebuild to catch creep. Run-Capped only catches
# catastrophic memory blowups in real time.
#
# Defaults: 1024 MB e-stop, no wall timeout. Caller can override either,
# but never raise the e-stop above 1024 MB without explicit user approval —
# >1 GB risks system crash, which is exactly what this wrapper exists
# to prevent.
#
# Usage:
#   $r = Run-Capped './bin/nucleor.exe' @('build','probes/foo.nr','-o','/tmp/p')
#   "wall=$($r.WallSec) peak=$($r.PeakMB)MB"
#
# Throws on:
#   - E-STOP        (RSS > cap; process killed)
#   - TIMEOUT       (only if caller passed -TimeoutSec; process killed)
#   - non-zero exit (process exited with error)

function Run-Capped {
    param(
        [Parameter(Mandatory)][string]$Cmd,
        [Parameter(Mandatory)][string[]]$ArgList,
        [int]$EstopMB = 1024,
        [int]$TimeoutSec = 0,    # 0 = unbounded
        [string]$Label = $null
    )
    if (-not $Label) { $Label = "$Cmd $($ArgList -join ' ')" }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p  = Start-Process -FilePath $Cmd -ArgumentList $ArgList -PassThru -NoNewWindow
    $deadline = if ($TimeoutSec -gt 0) { (Get-Date).AddSeconds($TimeoutSec) } else { $null }
    $peak_mb = 0
    while (-not $p.HasExited) {
        try {
            $p.Refresh()
            $cur_mb = [int]($p.WorkingSet64 / 1MB)
            if ($cur_mb -gt $peak_mb) { $peak_mb = $cur_mb }
            if ($cur_mb -gt $EstopMB) {
                $p.Kill()
                throw "E-STOP: $Label hit ${cur_mb}MB (cap ${EstopMB}MB) — system-protect kill"
            }
        } catch [System.Management.Automation.RuntimeException] { throw }
          catch {} # transient process-state read; ignore
        if ($deadline -and (Get-Date) -gt $deadline) {
            $p.Kill()
            throw "TIMEOUT: $Label exceeded ${TimeoutSec}s (caller-set)"
        }
        Start-Sleep -Milliseconds 250
    }
    $sw.Stop()
    $wall = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    if ($p.ExitCode -ne 0) {
        throw "EXIT $($p.ExitCode): $Label (wall=${wall}s peak=${peak_mb}MB)"
    }
    [pscustomobject]@{ WallSec = $wall; PeakMB = $peak_mb; ExitCode = 0 }
}
