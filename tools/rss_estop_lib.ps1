# Shared Windows process-tree RSS e-stop helpers.
#
# The 1000 MB limit used by this repo is an emergency stop, not a
# performance target. Callers should sample the whole launched process
# tree and kill it immediately when resident memory crosses the limit.

if (-not ("NucRssJobApi" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class NucRssJobApi {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool TerminateJobObject(IntPtr hJob, uint uExitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool QueryInformationJobObject(
        IntPtr hJob,
        int jobObjectInfoClass,
        IntPtr lpJobObjectInfo,
        uint cbJobObjectInfoLength,
        out uint lpReturnLength);

    public static int[] QueryJobPids(IntPtr hJob) {
        const int JobObjectBasicProcessIdList = 3;
        int maxPids = 4096;
        int offset = 8;
        int bytes = offset + (IntPtr.Size * maxPids);
        IntPtr buffer = Marshal.AllocHGlobal(bytes);
        try {
            uint returned;
            bool ok = QueryInformationJobObject(hJob, JobObjectBasicProcessIdList, buffer, (uint)bytes, out returned);
            if (!ok) return new int[0];
            int count = Marshal.ReadInt32(buffer, 4);
            if (count < 0) return new int[0];
            if (count > maxPids) count = maxPids;
            List<int> ids = new List<int>(count);
            for (int i = 0; i < count; i++) {
                IntPtr raw = Marshal.ReadIntPtr(buffer, offset + (i * IntPtr.Size));
                long pid = raw.ToInt64();
                if (pid > 0 && pid <= Int32.MaxValue) ids.Add((int)pid);
            }
            return ids.ToArray();
        } finally {
            Marshal.FreeHGlobal(buffer);
        }
    }
}
"@
}

function Get-NucProcessTreeIds([int]$RootPid) {
    $ids = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    $queue.Enqueue($RootPid)
    while ($queue.Count -gt 0) {
        $id = $queue.Dequeue()
        if (-not $ids.Contains($id)) { $ids.Add($id) }
        Get-CimInstance Win32_Process -Filter "ParentProcessId = $id" -ErrorAction SilentlyContinue |
            ForEach-Object { $queue.Enqueue([int]$_.ProcessId) }
    }
    return @($ids)
}

function Stop-NucProcessTree([int[]]$Ids) {
    # Kill descendants first. If the root exits first, grandchildren can
    # become orphaned and escape a parent-id based follow-up sweep.
    $ordered = @($Ids | Select-Object -Unique)
    [array]::Reverse($ordered)
    foreach ($id in $ordered) {
        try { Stop-Process -Id $id -Force -ErrorAction Stop } catch { }
    }
}

function Get-NucWatchedProcessIds([int]$RootPid, [IntPtr]$JobHandle, [bool]$JobAssigned) {
    $ids = @(Get-NucProcessTreeIds $RootPid)
    if ($JobAssigned -and $JobHandle -ne [IntPtr]::Zero) {
        try { $ids += @([NucRssJobApi]::QueryJobPids($JobHandle)) } catch { }
    }
    return @($ids | Select-Object -Unique)
}

function Stop-NucWatchedProcesses([int[]]$Ids, [IntPtr]$JobHandle, [bool]$JobAssigned) {
    if ($JobAssigned -and $JobHandle -ne [IntPtr]::Zero) {
        try {
            [void][NucRssJobApi]::TerminateJobObject($JobHandle, 99)
            return
        } catch { }
    }
    Stop-NucProcessTree $Ids
}

function Format-NucRssDetail($Processes) {
    return (($Processes |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 8 |
        ForEach-Object { "{0}:{1}MB" -f $_.ProcessName, ([Math]::Round($_.WorkingSet64 / 1MB, 1)) }) -join ", ")
}

function Invoke-NucRssEstop {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$ArgumentString = "",
        [switch]$UseArgumentString,
        [string]$WorkingDirectory = "",
        [int]$BudgetMb = 1000,
        [int]$WarningMb = 800,
        [int]$TimeoutSec = 0,
        [int]$SampleMs = 100,
        [string]$StdoutPath = "",
        [string]$StderrPath = ""
    )

    if ($BudgetMb -lt 1) { throw "BudgetMb must be >= 1" }
    if ($SampleMs -lt 25) { throw "SampleMs must be >= 25" }
    if ($WarningMb -ge $BudgetMb) { throw "WarningMb must be lower than BudgetMb" }

    if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $WorkingDirectory = (Get-Location).Path
    }

    if (-not [System.IO.Path]::IsPathRooted($FilePath)) {
        $candidate = Join-Path $WorkingDirectory $FilePath
        if (Test-Path $candidate) { $FilePath = $candidate }
    }

    $tmpDir = ""
    if ([string]::IsNullOrWhiteSpace($StdoutPath) -or [string]::IsNullOrWhiteSpace($StderrPath)) {
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("nuc_rss_estop_{0}_{1}" -f $PID, [Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        if ([string]::IsNullOrWhiteSpace($StdoutPath)) { $StdoutPath = Join-Path $tmpDir "stdout.txt" }
        if ([string]::IsNullOrWhiteSpace($StderrPath)) { $StderrPath = Join-Path $tmpDir "stderr.txt" }
    }

    $startArgs = if ($UseArgumentString) { $ArgumentString } else { $ArgumentList }

    $proc = Start-Process -FilePath $FilePath `
        -ArgumentList $startArgs `
        -WorkingDirectory $WorkingDirectory `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $StdoutPath `
        -RedirectStandardError $StderrPath

    $peakBytes = 0L
    $peakDetail = ""
    try {
        $proc.Refresh()
        if ($proc.WorkingSet64 -gt $peakBytes) {
            $peakBytes = [int64]$proc.WorkingSet64
            $peakDetail = "{0}:{1}MB (root initial)" -f $proc.ProcessName, ([Math]::Round($proc.WorkingSet64 / 1MB, 1))
        }
    } catch { }

    $jobHandle = [IntPtr]::Zero
    $jobAssigned = $false
    try {
        $jobHandle = [NucRssJobApi]::CreateJobObject([IntPtr]::Zero, $null)
        if ($jobHandle -ne [IntPtr]::Zero) {
            $jobAssigned = [NucRssJobApi]::AssignProcessToJobObject($jobHandle, $proc.Handle)
        }
    } catch {
        $jobAssigned = $false
    }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $limitBytes = [int64]$BudgetMb * 1MB
    $warningBytes = [int64]$WarningMb * 1MB
    $crossedWarning = $false
    $warningAtSeconds = $null
    $warningDetail = ""
    $killed = $false
    $reason = ""

    while ($true) {
        $ids = Get-NucWatchedProcessIds $proc.Id $jobHandle $jobAssigned
        $procs = @(Get-Process -Id $ids -ErrorAction SilentlyContinue)
        if ($procs.Count -eq 0) { break }

        $rss = ($procs | Measure-Object -Property WorkingSet64 -Sum).Sum
        if ($rss -gt $peakBytes) {
            $peakBytes = [int64]$rss
            $peakDetail = Format-NucRssDetail $procs
        }

        if ((-not $crossedWarning) -and $rss -gt $warningBytes) {
            $crossedWarning = $true
            $warningAtSeconds = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
            $warningDetail = Format-NucRssDetail $procs
        }

        if ($rss -gt $limitBytes) {
            $killed = $true
            $reason = "process-tree RSS exceeded ${BudgetMb} MB e-stop"
            Stop-NucWatchedProcesses $ids $jobHandle $jobAssigned
            Start-Sleep -Milliseconds 100
            $remaining = @(Get-NucWatchedProcessIds $proc.Id $jobHandle $jobAssigned)
            Stop-NucWatchedProcesses $remaining $jobHandle $jobAssigned
            break
        }

        if ($TimeoutSec -gt 0 -and $sw.Elapsed.TotalSeconds -gt $TimeoutSec) {
            $killed = $true
            $reason = "timeout exceeded ${TimeoutSec}s"
            Stop-NucWatchedProcesses $ids $jobHandle $jobAssigned
            Start-Sleep -Milliseconds 100
            $remaining = @(Get-NucWatchedProcessIds $proc.Id $jobHandle $jobAssigned)
            Stop-NucWatchedProcesses $remaining $jobHandle $jobAssigned
            break
        }

        Start-Sleep -Milliseconds $SampleMs
        try { $proc.Refresh() } catch { }
    }

    if (-not $killed) {
        try {
            $proc.WaitForExit()
            $proc.Refresh()
        } catch { }
    }
    $sw.Stop()
    try {
        $rootPeak = [int64]$proc.PeakWorkingSet64
        if ($rootPeak -gt $peakBytes) {
            $peakBytes = $rootPeak
            $peakDetail = "{0}:{1}MB (root peak)" -f $proc.ProcessName, ([Math]::Round($rootPeak / 1MB, 1))
        }
    } catch { }
    if ($jobHandle -ne [IntPtr]::Zero) {
        try { [void][NucRssJobApi]::CloseHandle($jobHandle) } catch { }
    }

    $exitCode = if ($killed) { 99 } else { [int]$proc.ExitCode }
    return [pscustomobject]@{
        exit_code = $exitCode
        killed = $killed
        reason = $reason
        budget_mb = $BudgetMb
        warning_mb = $WarningMb
        crossed_warning = $crossedWarning
        warning_at_seconds = $warningAtSeconds
        warning_detail = $warningDetail
        peak_mb = [Math]::Round($peakBytes / 1MB, 1)
        peak_detail = $peakDetail
        wall_seconds = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
        sample_ms = $SampleMs
        stdout = $StdoutPath
        stderr = $StderrPath
        tmp_dir = $tmpDir
        job_assigned = $jobAssigned
    }
}
