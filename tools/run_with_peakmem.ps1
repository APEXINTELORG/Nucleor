# tools/run_with_peakmem.ps1 — wrap a verify.sh invocation, sample
# subtree memory cheaply (Get-Process by name, filtered to current
# session), track peak, kill the tree at 1 GB hard e-stop, and append
# a run-summary row to the CSV.
#
# Cheap sampler design (vs the old CIM/Win32_Process tree walk):
#   - poll once per second (not 500ms)
#   - filter Get-Process by SessionId == current session
#   - filter by image name set: nucleor, clang, bash, sh, python, conhost
#   - sum WorkingSet64 across matched processes
#   - no Get-CimInstance calls (those are 100s of ms each)
#
# 1 GB e-stop: hard ceiling. If subtree sum >= 1 GB at any sample,
# the entire process tree (verify.sh + descendants) is killed via
# `taskkill /T /F /PID <id>`. The run-summary row records the kill.
#
# The CSV gets one extra row per run, distinguished by name = "__run_summary__":
#   run_iso, 0, wall_seconds, status, "__run_summary__", peak_mb, killed, last_index
#
# Where:
#   wall_seconds = total wall time of the verify invocation
#   status = PASS if exit==0 and !killed, FAIL if exit!=0, KILLED if e-stop fired
#   peak_mb = max sum-of-subtree memory observed across all samples (MB)
#   killed = "1" if e-stop fired, "0" otherwise
#   last_index = highest STEP_INDEX seen in this run's per-step rows at kill time
#
# Per-step rows (the existing schema) remain unchanged: 5 columns.
# Tools that read the CSV must tolerate trailing extra columns on
# the summary row (or filter on name).
#
# Usage:
#   pwsh tools/run_with_peakmem.ps1 -VerifyArgs "<verify.sh args as one string>"
#
# Exit code: forwarded from verify.sh (or 137 if killed by e-stop).

param(
    [Parameter(Mandatory = $true)][string]$VerifyArgs,
    [int]$EstopMb = 1024,
    [int]$PollMs = 1000
)

$ErrorActionPreference = "Stop"

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

$mySessionId = (Get-Process -Id $PID).SessionId

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
$proc = [System.Diagnostics.Process]::Start($psi)
# Scope sampling to processes that started AT OR AFTER our launch.
# Cheap heuristic that excludes pre-existing bash/clang/python processes
# (e.g. another agent's session, this Claude Code's own shell) from the
# subtree sum. Add a small clock skew tolerance.
$startCutoff = $start.AddSeconds(-2)

$peakBytes = 0L
$samples = 0
$killed = $false
$estopBytes = [int64]$EstopMb * 1MB

while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds $PollMs
    $sum = 0L
    $matchedCount = 0
    foreach ($n in $names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue |
            Where-Object {
                $_.SessionId -eq $mySessionId -and
                $_.StartTime -ge $startCutoff
            } |
            ForEach-Object { $sum += $_.WorkingSet64; $matchedCount++ }
    }
    if ($sum -gt $peakBytes) { $peakBytes = $sum }
    $samples++
    if ($sum -ge $estopBytes) {
        Write-Host ""
        Write-Host "[peakmem] *** E-STOP TRIPPED *** subtree=$([math]::Round($sum/1MB)) MB >= ${EstopMb} MB across $matchedCount procs; killing tree"
        & taskkill /T /F /PID $proc.Id 2>&1 | Out-Null
        $killed = $true
        break
    }
}
if (-not $proc.HasExited) {
    $proc.WaitForExit()
}
$end = Get-Date
$wall = ($end - $start).TotalSeconds
$peakMb = [int]([math]::Round($peakBytes / 1MB))
$exitCode = if ($killed) { 137 } else { $proc.ExitCode }

# Resolve run_iso AND last_index from the per-step rows that verify.sh
# just appended. We use the most recent run_iso anywhere in the CSV — the
# rows we just wrote — and find the highest index for that run_iso.
# This avoids the brittle env-var override path: PSI.EnvironmentVariables
# / [Environment]::SetEnvironmentVariable doesn't reliably propagate into
# the Git-Bash child on Windows; reading after-the-fact is bullet-proof.
$runIso = ""
$lastIndex = 0
if (Test-Path $csvPath) {
    $rows = Get-Content -Path $csvPath -Tail 1000 -ErrorAction SilentlyContinue
    # Walk from end; first non-summary row gives us the run_iso of this run.
    for ($k = $rows.Count - 1; $k -ge 0; $k--) {
        $r = $rows[$k]
        if ($r -notlike "*__run_summary__*" -and $r -match '^[0-9]') {
            $runIso = ($r -split ",")[0]
            break
        }
    }
    # Now sweep for the highest index in that run.
    if ($runIso -ne "") {
        foreach ($r in $rows) {
            if ($r -like "$runIso,*" -and $r -notlike "*__run_summary__*") {
                $idx = ($r -split ",")[1]
                if ($idx -match '^\d+$' -and [int]$idx -gt $lastIndex) { $lastIndex = [int]$idx }
            }
        }
    }
}
# If verify.sh wrote no per-step rows at all (e.g. all skipped or fatal
# error before any step), fall back to a wrapper-generated timestamp so
# the summary row still has SOMETHING for run_iso.
if ($runIso -eq "") {
    $runIso = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$status = if ($killed) { "KILLED" } elseif ($exitCode -eq 0) { "PASS" } else { "FAIL" }

# Append run-summary row. Schema:
#   run_iso, 0, wall_seconds, status, "__run_summary__", peak_mb, killed, last_index
$summaryRow = '{0},0,{1:F3},{2},"__run_summary__",{3},{4},{5}' -f `
    $runIso, $wall, $status, $peakMb, ($(if ($killed) { 1 } else { 0 })), $lastIndex

# Make sure the CSV has a header. If the file doesn't exist, write our
# header. If it exists with the legacy 5-col header, the summary row's
# trailing extra columns just get ignored by 5-col-aware tools.
if (-not (Test-Path $csvPath)) {
    "run_iso,index,seconds,status,name,peak_mb,killed,last_index" | Out-File -Encoding ascii $csvPath
}
Add-Content -Path $csvPath -Value $summaryRow -Encoding ascii

Write-Host ""
Write-Host "[peakmem] samples=$samples  peak=${peakMb} MB  wall=$([math]::Round($wall,2))s  status=$status  killed=$killed"
Write-Host "[peakmem] summary row appended to: $csvPath"
Write-Host "PEAKMEM_MB=$peakMb  EXIT=$exitCode  WALL_S=$([math]::Round($wall,3))  KILLED=$killed  LAST_INDEX=$lastIndex"

exit $exitCode
