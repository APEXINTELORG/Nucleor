# tools/run_with_peakmem.ps1 — wrap a verify.sh invocation, sample
# launched process-tree memory, track peak, kill the tree at 1 GB hard
# e-stop, and append a run-summary row to the CSV.
#
# Sampler design:
#   - poll once per second (default)
#   - query the Windows process table for parent/child relationships
#   - walk descendants from the launched bash process
#   - add repo-rooted Git-Bash/MSYS worker processes started during this run
#     because MSYS sometimes reports xargs/workers outside the Win32 parent tree
#   - sum WorkingSet64 across the tracked verify workload
#
# 1 GB e-stop: hard ceiling. If tracked sum >= 1 GB at any sample,
# the tracked verify workload is killed via
# `taskkill /T /F /PID <id>`. The run-summary row records the kill.
#
# v0.5.30 robustness fixes:
#   - $ErrorActionPreference is "Continue" now, NOT "Stop".
#     Under "Stop", a transient error in the poll loop (e.g. a
#     short-lived child process exiting between process-table sampling
#     and WorkingSet64 reads) terminated the entire script mid-run with no
#     summary row written. parallel-1 hit this on the env-off full
#     run reaching [669/697] without a summary.
#   - Per-process memory reads are wrapped. If a child exits between
#     tree discovery and memory sampling, it is skipped for this poll.
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
#   peak_mb = max tracked verify workload memory observed across all samples (MB)
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
    # Default empty string: "run the full set with default args".
    # Pass "--range FROM-TO" or other verify.sh flags for narrower runs.
    [string]$VerifyArgs = "",
    [int]$EstopMb = 1024,
    [int]$PollMs = 1000
)

# v0.5.30: NOT "Stop". Transient errors in the poll loop (Get-CimInstance
# failures, Get-Process access denials, short-lived child exits) must NOT
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

# Resolve CSV path (mirror verify.sh logic) so we can append the summary
# row at the same path verify.sh writes per-step rows to.
$csvOverride = $env:NUC_VERIFY_CSV
$agent = if ($env:NUC_VERIFY_AGENT) { $env:NUC_VERIFY_AGENT } else { "main" }
if ($csvOverride) {
    $csvPath = $csvOverride
} else {
    $csvPath = Join-Path $root "tools\verify_timings.$agent.csv"
}

function Convert-ToMsysPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        return "/" + $matches[1].ToLowerInvariant() + "/" + ($matches[2] -replace '\\', '/')
    }
    return ($full -replace '\\', '/')
}

function Convert-ProcCreationTime($CreationDate) {
    if ($CreationDate -is [DateTime]) { return [DateTime]$CreationDate }
    try { return [Management.ManagementDateTimeConverter]::ToDateTime([string]$CreationDate) } catch { }
    try { return [DateTime]$CreationDate } catch { return [DateTime]::MinValue }
}

function Test-RepoRootedVerifyProcess($Proc, [DateTime]$StartedAt, [string]$RepoRoot, [string]$RepoRootMsys) {
    $created = Convert-ProcCreationTime $Proc.CreationDate
    if ($created -lt $StartedAt.AddSeconds(-2)) { return $false }

    $name = [string]$Proc.Name
    $cmd = [string]$Proc.CommandLine
    $exe = [string]$Proc.ExecutablePath

    if (-not [string]::IsNullOrWhiteSpace($exe) -and
        $exe.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($cmd)) { return $false }
    $mentionsRepo = ($cmd.IndexOf($RepoRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
        ($cmd.IndexOf($RepoRootMsys, [StringComparison]::OrdinalIgnoreCase) -ge 0)
    if (-not $mentionsRepo) { return $false }

    $lower = $name.ToLowerInvariant()
    if ($lower -in @(
        "bash.exe", "sh.exe", "dash.exe", "xargs.exe",
        "nucleor.exe", "clang.exe", "clang++.exe", "lld-link.exe",
        "ld.exe", "gcc.exe", "g++.exe", "cc1.exe", "cc1plus.exe", "cmd.exe"
    )) {
        return $true
    }

    if ($lower -in @("powershell.exe", "pwsh.exe")) {
        return ($cmd.IndexOf("measure_peak_build.ps1", [StringComparison]::OrdinalIgnoreCase) -ge 0)
    }

    # Fixture executables are emitted under target/_pv_* and then run by
    # relative path from the repo root, so their executable path is the most
    # reliable signal. Keep this fallback for command-line-only process rows.
    return ($cmd.IndexOf("/target/_pv_", [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
        ($cmd.IndexOf("\target\_pv_", [StringComparison]::OrdinalIgnoreCase) -ge 0)
}

function Get-VerifyProcessIds([int]$RootPid, [DateTime]$StartedAt, [string]$RepoRoot, [string]$RepoRootMsys) {
    $childrenByParent = @{}
    $processes = $null
    try {
        $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
        $processes | ForEach-Object {
                $ppid = [int]$_.ParentProcessId
                if (-not $childrenByParent.ContainsKey($ppid)) {
                    $childrenByParent[$ppid] = New-Object System.Collections.Generic.List[int]
                }
                $childrenByParent[$ppid].Add([int]$_.ProcessId)
            }
    } catch {
        return ,$RootPid
    }

    $ids = New-Object System.Collections.Generic.HashSet[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootPid)

    foreach ($p in $processes) {
        if (Test-RepoRootedVerifyProcess $p $StartedAt $RepoRoot $RepoRootMsys) {
            $queue.Enqueue([int]$p.ProcessId)
        }
    }

    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        if (-not $ids.Add($id)) { continue }
        if ($childrenByParent.ContainsKey($id)) {
            foreach ($childId in $childrenByParent[$id]) {
                $queue.Enqueue([int]$childId)
            }
        }
    }
    $result = New-Object System.Collections.Generic.List[int]
    foreach ($id in $ids) {
        $result.Add([int]$id)
    }
    return $result.ToArray()
}

function Stop-TrackedVerifyProcesses([int[]]$Ids, [int]$RootPid) {
    try { & taskkill /T /F /PID $RootPid 2>&1 | Out-Null } catch { }
    foreach ($id in ($Ids | Sort-Object -Unique)) {
        if ($id -eq $PID) { continue }
        try { & taskkill /F /PID $id 2>&1 | Out-Null } catch { }
    }
}

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
$rootFull = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
$rootMsys = Convert-ToMsysPath $rootFull
$peakBytes = 0L
$samples = 0
$killed = $false
$estopBytes = [int64]$EstopMb * 1MB
$proc = $null
$exitCode = 2          # default = wrapper crash (overwritten on normal/killed exit)
$crashMsg = $null
$lastTrackedIds = @()

# v0.5.30: try/finally guarantees the summary row write below runs on
# every exit path. The previous version exited mid-poll on transient
# Get-Process/CIM exceptions and never appended a summary.
try {
    $proc = [System.Diagnostics.Process]::Start($psi)
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds $PollMs
        $sum = 0L
        $matchedCount = 0
        $trackedIds = Get-VerifyProcessIds $proc.Id $start $rootFull $rootMsys
        $lastTrackedIds = $trackedIds
        foreach ($id in $trackedIds) {
            try {
                $p = Get-Process -Id $id -ErrorAction Stop
                $sum += $p.WorkingSet64
                $matchedCount++
            } catch { }
        }
        if ($sum -gt $peakBytes) { $peakBytes = $sum }
        $samples++
        if ($sum -ge $estopBytes) {
            Write-Host ""
            Write-Host "[peakmem] *** E-STOP TRIPPED *** tracked=$([math]::Round($sum/1MB)) MB >= ${EstopMb} MB across $matchedCount procs; killing verify workload"
            Stop-TrackedVerifyProcesses $trackedIds $proc.Id
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
        Stop-TrackedVerifyProcesses $lastTrackedIds $proc.Id
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
