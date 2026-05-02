# tools/run_with_peakmem.ps1 — wrap a verify.sh invocation, sample
# subtree memory cheaply (Get-Process by name, filtered to current
# session), track peak, kill the tree at 1 GB hard e-stop, and append
# a run-summary row to the CSV.
#
# Cheap sampler design (vs the old CIM/Win32_Process tree walk):
#   - poll once per second (default)
#   - filter Get-Process by SessionId == current session
#   - filter by image name set: nucleor, clang, bash, sh, python, conhost
#   - sum WorkingSet64 across matched processes
#   - no Get-CimInstance calls (those are 100s of ms each)
#
# 1 GB e-stop: hard ceiling. If subtree sum >= 1 GB at any sample,
# the entire process tree (verify.sh + descendants) is killed via
# `taskkill /T /F /PID <id>`. The run-summary row records the kill.
#
# v0.5.30 robustness fixes:
#   - $ErrorActionPreference is "Continue" now, NOT "Stop".
#     Under "Stop", a transient error in the poll loop (e.g. accessing
#     .StartTime on a process the current user can't introspect, or a
#     short-lived clang.exe that exited between Get-Process and the
#     property read) terminated the entire script mid-run with no
#     summary row written. parallel-1 hit this on the env-off full
#     run reaching [669/697] without a summary.
#   - .StartTime access is now wrapped per-process. If the access
#     throws, the process is silently skipped from this poll's sum.
#   - The main body is wrapped in try/finally so the summary-row
#     append fires on EVERY exit path — normal exit, e-stop kill,
#     unhandled exception. The CSV always gets the summary row,
#     even if the run blew up in unexpected ways.
#
# The CSV gets one extra row per run, distinguished by name = "__run_summary__":
#   run_iso, 0, wall_seconds, status, "__run_summary__", peak_mb, killed, last_index
#
# Where:
#   wall_seconds = total wall time of the verify invocation
#   status = PASS if exit==0 and !killed, FAIL if exit!=0, KILLED if e-stop fired,
#            CRASH if the wrapper itself caught an exception (rare, surfaced)
#   peak_mb = max sum-of-subtree memory observed across all samples (MB)
#   killed = "1" if e-stop fired, "0" otherwise
#   last_index = highest STEP_INDEX seen in this run's per-step rows at exit time
#
# Per-step rows (the existing schema) remain unchanged: 5 columns.
# Tools that read the CSV must tolerate trailing extra columns on
# the summary row (or filter on name).
#
# Usage:
#   pwsh tools/run_with_peakmem.ps1 -VerifyArgs "<verify.sh args as one string>"
#
# Exit code: forwarded from verify.sh (or 137 if killed by e-stop, or
# 2 if the wrapper itself crashed).

param(
    [Parameter(Mandatory = $true)][string]$VerifyArgs,
    [int]$EstopMb = 1024,
    [int]$PollMs = 1000
)

# v0.5.30: NOT "Stop". Transient errors in the poll loop (Get-Process
# access denials, short-lived process .StartTime reads) must NOT
# terminate the wrapper. We handle errors explicitly where they matter.
$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot

$bashCandidates = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files\Git\usr\bin\bash.exe",
    "C:\msys64\usr\bin\bash.exe"
)
$bash = $null
foreach ($c in $bashCandidates) {
    if (Test-Path $c -ErrorAction SilentlyContinue) { $bash = $c; break }
}
if (-not $bash) { $bash = "bash.exe" }

# Names to sum. Anything verify.sh might spawn during a Nucleor build/test.
# Keep this tight to avoid false positives from unrelated user processes.
$names = @("nucleor","nucleor_tools","clang","clang++","ld","ld.lld","lld-link","python","bash","sh","conhost","cmd")

# Resolve CSV path (mirror verify.sh logic) so we can append the summary
# row at the same path verify.sh writes per-step rows to.
$csvOverride = $env:NUC_VERIFY_CSV
$agent = if ($env:NUC_VERIFY_AGENT) { $env:NUC_VERIFY_AGENT } else { "main" }
if ($csvOverride) {
    $csvPath = $csvOverride
} else {
    $csvPath = Join-Path $root "tools\verify_timings.$agent.csv"
}

$mySessionId = $null
try { $mySessionId = (Get-Process -Id $PID).SessionId } catch { $mySessionId = 0 }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $bash
$psi.Arguments = "tools/verify.sh $VerifyArgs"
$psi.WorkingDirectory = $root
$psi.UseShellExecute = $false

# Explicit env propagation. PSI auto-populates from parent at construction
# but Git-Bash on Windows mangles inheritance for some keys. Re-add the
# critical ones so verify.sh sees them and writes per-step rows to the
# SAME CSV that this wrapper appends the summary row to.
foreach ($k in @("NUC_VERIFY_AGENT","NUC_VERIFY_CSV","NUC_VERIFY_JOBS")) {
    $v = [Environment]::GetEnvironmentVariable($k, "Process")
    if ($v) {
        $psi.EnvironmentVariables.Remove($k) | Out-Null
        $psi.EnvironmentVariables.Add($k, $v)
    }
}

Write-Host "[peakmem] launching: bash tools/verify.sh $VerifyArgs"
Write-Host "[peakmem] e-stop: $EstopMb MB; poll: ${PollMs}ms; csv: $csvPath"

$start = Get-Date
$peakBytes = 0L
$samples = 0
$killed = $false
$estopBytes = [int64]$EstopMb * 1MB
$proc = $null
$exitCode = 2          # default = wrapper crash (overwritten on normal/killed exit)
$crashMsg = $null

# v0.5.30: try/finally guarantees the summary row write below runs on
# every exit path. The previous version exited mid-poll on transient
# Get-Process / .StartTime exceptions and never appended a summary.
try {
    $proc = [System.Diagnostics.Process]::Start($psi)
    # Scope sampling to processes that started AT OR AFTER our launch.
    # Cheap heuristic that excludes pre-existing bash/clang/python processes
    # (e.g. another agent's session, this Claude Code's own shell) from the
    # subtree sum. Add a small clock skew tolerance.
    $startCutoff = $start.AddSeconds(-2)

    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds $PollMs
        $sum = 0L
        $matchedCount = 0
        foreach ($n in $names) {
            $procs = $null
            try { $procs = Get-Process -Name $n -ErrorAction SilentlyContinue } catch { $procs = $null }
            if ($null -ne $procs) {
                foreach ($p in $procs) {
                    # v0.5.30: per-process try/catch. .StartTime throws
                    # InvalidOperationException on protected/dying processes.
                    # Skip them silently rather than tearing down the script.
                    $sid = -1
                    $st  = $null
                    try { $sid = $p.SessionId } catch { continue }
                    if ($sid -ne $mySessionId) { continue }
                    try { $st = $p.StartTime } catch { continue }
                    if ($null -eq $st) { continue }
                    if ($st -lt $startCutoff) { continue }
                    try { $sum += $p.WorkingSet64; $matchedCount++ } catch { }
                }
            }
        }
        if ($sum -gt $peakBytes) { $peakBytes = $sum }
        $samples++
        if ($sum -ge $estopBytes) {
            Write-Host ""
            Write-Host "[peakmem] *** E-STOP TRIPPED *** subtree=$([math]::Round($sum/1MB)) MB >= ${EstopMb} MB across $matchedCount procs; killing tree"
            try { & taskkill /T /F /PID $proc.Id 2>&1 | Out-Null } catch { }
            $killed = $true
            break
        }
    }
    if (-not $proc.HasExited) {
        $proc.WaitForExit()
    }
    $exitCode = if ($killed) { 137 } else { $proc.ExitCode }
}
catch {
    $crashMsg = $_.Exception.Message
    Write-Host ""
    Write-Host "[peakmem] !! WRAPPER CAUGHT EXCEPTION: $crashMsg"
    if ($null -ne $proc -and -not $proc.HasExited) {
        try { & taskkill /T /F /PID $proc.Id 2>&1 | Out-Null } catch { }
    }
    $exitCode = 2
}
finally {
    $end = Get-Date
    $wall = ($end - $start).TotalSeconds
    $peakMb = [int]([math]::Round($peakBytes / 1MB))

    # Resolve run_iso AND last_index from the per-step rows that verify.sh
    # just appended. Reading after-the-fact avoids the unreliable env-var
    # handshake between PowerShell and Git-Bash.
    $runIso = ""
    $lastIndex = 0
    if (Test-Path $csvPath) {
        $rows = $null
        try { $rows = Get-Content -Path $csvPath -Tail 2000 -ErrorAction SilentlyContinue } catch { $rows = $null }
        if ($null -ne $rows) {
            for ($k = $rows.Count - 1; $k -ge 0; $k--) {
                $r = $rows[$k]
                if ($r -notlike "*__run_summary__*" -and $r -match '^[0-9]') {
                    $runIso = ($r -split ",")[0]
                    break
                }
            }
            if ($runIso -ne "") {
                foreach ($r in $rows) {
                    if ($r -like "$runIso,*" -and $r -notlike "*__run_summary__*") {
                        $idx = ($r -split ",")[1]
                        if ($idx -match '^\d+$' -and [int]$idx -gt $lastIndex) { $lastIndex = [int]$idx }
                    }
                }
            }
        }
    }
    if ($runIso -eq "") {
        $runIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $status = if ($crashMsg) { "CRASH" } elseif ($killed) { "KILLED" } elseif ($exitCode -eq 0) { "PASS" } else { "FAIL" }

    # Append run-summary row. Schema:
    #   run_iso, 0, wall_seconds, status, "__run_summary__", peak_mb, killed, last_index
    $summaryRow = '{0},0,{1:F3},{2},"__run_summary__",{3},{4},{5}' -f `
        $runIso, $wall, $status, $peakMb, ($(if ($killed) { 1 } else { 0 })), $lastIndex

    if (-not (Test-Path $csvPath)) {
        try { "run_iso,index,seconds,status,name,peak_mb,killed,last_index" | Out-File -Encoding ascii $csvPath } catch { }
    }
    try { Add-Content -Path $csvPath -Value $summaryRow -Encoding ascii } catch {
        Write-Host "[peakmem] !! could not write summary row to $csvPath : $($_.Exception.Message)"
    }

    Write-Host ""
    Write-Host "[peakmem] samples=$samples  peak=${peakMb} MB  wall=$([math]::Round($wall,2))s  status=$status  killed=$killed"
    if ($crashMsg) { Write-Host "[peakmem] crash: $crashMsg" }
    Write-Host "[peakmem] summary row appended to: $csvPath"
    Write-Host "PEAKMEM_MB=$peakMb  EXIT=$exitCode  WALL_S=$([math]::Round($wall,3))  KILLED=$killed  LAST_INDEX=$lastIndex"
}

exit $exitCode
