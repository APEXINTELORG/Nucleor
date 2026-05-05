# Shared Windows process-tree RSS e-stop helpers.
#
# The 1000 MB limit used by this repo is an emergency stop, not a
# performance target. Callers should sample the whole launched process
# tree and kill it immediately when resident memory crosses the limit.
#
# Default Windows path: a small native helper in tools/nuc_rss_estop.c.
# This keeps the 100ms polling loop out of PowerShell/pwsh. The older
# PowerShell/.NET sampler remains as a fallback, or for NUC_RSS_USE_JOB=1
# focused probes. The helper binary is cached under tools/.nuc_rss_estop
# because perf gates intentionally delete target/ between cold samples.

$script:NucRssNativeDefault = ($env:OS -eq "Windows_NT" -and $env:NUC_RSS_DISABLE_NATIVE -ne "1")

if ((-not $script:NucRssNativeDefault -or $env:NUC_RSS_USE_JOB -eq "1") -and -not ("NucRssJobApi" -as [type])) {
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

    private const uint TH32CS_SNAPPROCESS = 0x00000002;
    private static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct PROCESSENTRY32 {
        public uint dwSize;
        public uint cntUsage;
        public uint th32ProcessID;
        public IntPtr th32DefaultHeapID;
        public uint th32ModuleID;
        public uint cntThreads;
        public uint th32ParentProcessID;
        public int pcPriClassBase;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szExeFile;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateToolhelp32Snapshot(uint dwFlags, uint th32ProcessID);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool Process32FirstW(IntPtr hSnapshot, ref PROCESSENTRY32 lppe);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool Process32NextW(IntPtr hSnapshot, ref PROCESSENTRY32 lppe);

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

    public static int[] QueryDescendantPids(int rootPid) {
        IntPtr snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snapshot == IntPtr.Zero || snapshot == INVALID_HANDLE_VALUE) return new int[0];
        try {
            Dictionary<int, List<int>> childrenByParent = new Dictionary<int, List<int>>();
            PROCESSENTRY32 entry = new PROCESSENTRY32();
            entry.dwSize = (uint)Marshal.SizeOf(typeof(PROCESSENTRY32));
            if (!Process32FirstW(snapshot, ref entry)) return new int[0];
            do {
                int pid = unchecked((int)entry.th32ProcessID);
                int parent = unchecked((int)entry.th32ParentProcessID);
                if (pid > 0 && parent > 0) {
                    List<int> children;
                    if (!childrenByParent.TryGetValue(parent, out children)) {
                        children = new List<int>();
                        childrenByParent[parent] = children;
                    }
                    children.Add(pid);
                }
                entry.dwSize = (uint)Marshal.SizeOf(typeof(PROCESSENTRY32));
            } while (Process32NextW(snapshot, ref entry));

            List<int> ids = new List<int>();
            Queue<int> queue = new Queue<int>();
            queue.Enqueue(rootPid);
            while (queue.Count > 0) {
                int id = queue.Dequeue();
                if (ids.Contains(id)) continue;
                ids.Add(id);
                List<int> children;
                if (childrenByParent.TryGetValue(id, out children)) {
                    for (int i = 0; i < children.Count; i++) queue.Enqueue(children[i]);
                }
            }
            return ids.ToArray();
        } finally {
            CloseHandle(snapshot);
        }
    }

}
"@
}

function Get-NucProcessTreeIds([int]$RootPid) {
    try {
        $fastIds = @([NucRssJobApi]::QueryDescendantPids($RootPid))
        if ($fastIds.Count -gt 0) { return @($fastIds) }
    } catch { }

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

function Get-NucFreshWatchedProcesses([int[]]$Ids, [int]$RootPid, [datetime]$RootStartTime) {
    # Windows parent-PID links are generation-blind. If the launched
    # compiler reuses a PID once held by another process, ToolHelp can
    # report old children of that prior process as descendants. Filter
    # candidates by creation time so stale unrelated processes are not
    # charged to, or killed with, this e-stop.
    $lowerBound = $RootStartTime.AddSeconds(-2)
    $rootUpperBound = $RootStartTime.AddSeconds(2)
    $fresh = @()
    foreach ($p in @(Get-Process -Id (@($Ids) | Select-Object -Unique) -ErrorAction SilentlyContinue)) {
        try {
            $started = $p.StartTime
        } catch {
            continue
        }
        if ($p.Id -eq $RootPid) {
            if ($started -ge $lowerBound -and $started -le $rootUpperBound) { $fresh += $p }
        } elseif ($started -ge $lowerBound) {
            $fresh += $p
        }
    }
    return @($fresh)
}

function Format-NucRssDetail($Processes) {
    $rows = @()
    foreach ($p in $Processes) {
        try {
            $rows += [pscustomobject]@{
                Name = $p.ProcessName
                WorkingSet64 = [int64]$p.WorkingSet64
            }
        } catch { }
    }
    return (($rows |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 8 |
        ForEach-Object { "{0}:{1}MB" -f $_.Name, ([Math]::Round($_.WorkingSet64 / 1MB, 1)) }) -join ", ")
}

function Get-NucNativeRssCompiler {
    if (-not [string]::IsNullOrWhiteSpace($env:NUC_RSS_NATIVE_CC)) {
        if (Test-Path $env:NUC_RSS_NATIVE_CC) { return $env:NUC_RSS_NATIVE_CC }
    }

    $cmd = Get-Command clang -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }

    $candidates = @(
        "C:\Progra~1\LLVM\bin\clang.exe",
        "C:\Program Files\LLVM\bin\clang.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return ""
}

function Get-NucNativeRssEstopPath {
    if (-not $script:NucRssNativeDefault) { return "" }

    $root = Split-Path -Parent $PSScriptRoot
    $src = Join-Path $PSScriptRoot "nuc_rss_estop.c"
    if (-not (Test-Path $src)) { return "" }

    $outDir = Join-Path $PSScriptRoot ".nuc_rss_estop"
    $exe = Join-Path $outDir "nuc_rss_estop.exe"
    if ((Test-Path $exe) -and ((Get-Item $exe).LastWriteTimeUtc -ge (Get-Item $src).LastWriteTimeUtc)) {
        return $exe
    }

    $clang = Get-NucNativeRssCompiler
    if ([string]::IsNullOrWhiteSpace($clang)) { return "" }

    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $buildLog = Join-Path $outDir "nuc_rss_estop.build.log"
    $oldErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & $clang "-O2" "-std=c11" $src "-o" $exe 2>&1
        $exitCode = $LASTEXITCODE
        $output | Out-File -FilePath $buildLog -Encoding utf8
        if ($exitCode -ne 0 -or -not (Test-Path $exe)) { return "" }
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }
    return $exe
}

function Invoke-NucNativeRssEstop {
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

    if ($env:NUC_RSS_USE_JOB -eq "1") { return $null }

    $helper = Get-NucNativeRssEstopPath
    if ([string]::IsNullOrWhiteSpace($helper)) { return $null }

    $nativeArgs = @(
        "--file", $FilePath,
        "--cwd", $WorkingDirectory,
        "--budget-mb", [string]$BudgetMb,
        "--warning-mb", [string]$WarningMb,
        "--timeout-sec", [string]$TimeoutSec,
        "--sample-ms", [string]$SampleMs,
        "--stdout", $StdoutPath,
        "--stderr", $StderrPath
    )
    if ($UseArgumentString) {
        $nativeArgs += @("--arg-string", $ArgumentString)
    } else {
        $nativeArgs += @("--arg-count", [string]$ArgumentList.Count)
        $nativeArgs += $ArgumentList
    }

    $jsonText = (& $helper @nativeArgs | Out-String)
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        throw "native RSS e-stop helper produced no summary"
    }
    return ($jsonText | ConvertFrom-Json)
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

    $nativeSummary = Invoke-NucNativeRssEstop `
        -FilePath $FilePath `
        -ArgumentList $ArgumentList `
        -ArgumentString $ArgumentString `
        -UseArgumentString:$UseArgumentString `
        -WorkingDirectory $WorkingDirectory `
        -BudgetMb $BudgetMb `
        -WarningMb $WarningMb `
        -TimeoutSec $TimeoutSec `
        -SampleMs $SampleMs `
        -StdoutPath $StdoutPath `
        -StderrPath $StderrPath
    if ($null -ne $nativeSummary) {
        if (-not [string]::IsNullOrWhiteSpace($tmpDir)) {
            $nativeSummary | Add-Member -NotePropertyName tmp_dir -NotePropertyValue $tmpDir -Force
        }
        return $nativeSummary
    }

    $startParams = @{
        FilePath = $FilePath
        WorkingDirectory = $WorkingDirectory
        WindowStyle = "Hidden"
        PassThru = $true
        RedirectStandardOutput = $StdoutPath
        RedirectStandardError = $StderrPath
    }
    if ($UseArgumentString) {
        if (-not [string]::IsNullOrEmpty($ArgumentString)) {
            $startParams.ArgumentList = $ArgumentString
        }
    } elseif ($ArgumentList.Count -gt 0) {
        $startParams.ArgumentList = $ArgumentList
    }

    $proc = Start-Process @startParams
    $rootStartTime = Get-Date
    try {
        $proc.Refresh()
        $rootStartTime = $proc.StartTime
    } catch { }

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
    # Job objects give stronger descendant containment, but on this
    # toolchain they can leave the self-host compiler waiting after the
    # output artifact is emitted. Keep parent-tree RSS sampling as the
    # default crash guard; opt into Job tracking only for focused probes.
    if ($env:NUC_RSS_USE_JOB -eq "1") {
        try {
            $jobHandle = [NucRssJobApi]::CreateJobObject([IntPtr]::Zero, $null)
            if ($jobHandle -ne [IntPtr]::Zero) {
                $jobAssigned = [NucRssJobApi]::AssignProcessToJobObject($jobHandle, $proc.Handle)
            }
        } catch {
            $jobAssigned = $false
        }
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
        $procs = @(Get-NucFreshWatchedProcesses $ids $proc.Id $rootStartTime)
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
            $killIds = @($procs | ForEach-Object { [int]$_.Id })
            Stop-NucWatchedProcesses $killIds $jobHandle $jobAssigned
            Start-Sleep -Milliseconds 100
            $remaining = @(Get-NucWatchedProcessIds $proc.Id $jobHandle $jobAssigned)
            $remainingProcs = @(Get-NucFreshWatchedProcesses $remaining $proc.Id $rootStartTime)
            $remainingIds = @($remainingProcs | ForEach-Object { [int]$_.Id })
            Stop-NucWatchedProcesses $remainingIds $jobHandle $jobAssigned
            break
        }

        if ($TimeoutSec -gt 0 -and $sw.Elapsed.TotalSeconds -gt $TimeoutSec) {
            $killed = $true
            $reason = "timeout exceeded ${TimeoutSec}s"
            $killIds = @($procs | ForEach-Object { [int]$_.Id })
            Stop-NucWatchedProcesses $killIds $jobHandle $jobAssigned
            Start-Sleep -Milliseconds 100
            $remaining = @(Get-NucWatchedProcessIds $proc.Id $jobHandle $jobAssigned)
            $remainingProcs = @(Get-NucFreshWatchedProcesses $remaining $proc.Id $rootStartTime)
            $remainingIds = @($remainingProcs | ForEach-Object { [int]$_.Id })
            Stop-NucWatchedProcesses $remainingIds $jobHandle $jobAssigned
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
