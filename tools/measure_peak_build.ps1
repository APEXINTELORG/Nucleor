# Measures peak resident memory for a Nucleor build process tree.
# Used by verify.sh on Windows so the memory gate tracks crash risk
# instead of cumulative allocation churn.

param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$OutName,
    [Parameter(Mandatory = $true)][int]$BudgetMb,
    [int]$TimeoutSec = 120,
    [string]$Bin = ""
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Bin)) {
    $Bin = Join-Path $root "bin\nucleor.exe"
} elseif (-not [System.IO.Path]::IsPathRooted($Bin)) {
    $Bin = Join-Path $root $Bin
}

if (-not (Test-Path $Bin)) {
    Write-Host "FAIL: compiler binary not found: $Bin"
    exit 1
}

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

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("nuc_peak_{0}_{1}" -f $PID, [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$stdoutPath = Join-Path $tmp "stdout.txt"
$stderrPath = Join-Path $tmp "stderr.txt"
$oldTrace = $env:NUC_TRACE_ALLOC

try {
    Remove-Item Env:\NUC_TRACE_ALLOC -ErrorAction SilentlyContinue

    Push-Location $root
    try {
        $args = @("build", $Source, "-o", $OutName, "--no-cache")
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $proc = Start-Process -FilePath $Bin `
            -ArgumentList $args `
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

            Start-Sleep -Milliseconds 100
            try { $proc.Refresh() } catch { }
        }

        if (-not $killed) {
            $proc.WaitForExit()
            $proc.Refresh()
        }
        $sw.Stop()
    } finally {
        Pop-Location
    }

    $peakRounded = [int][Math]::Ceiling($peakMb)
    $wallRounded = [Math]::Round($sw.Elapsed.TotalSeconds, 3)

    if ($killed) {
        Write-Host ("FAIL: {0} peak {1} MB / {2} MB budget, wall {3}s ({4})" -f $Source, $peakRounded, $BudgetMb, $wallRounded, $reason)
        exit 1
    }

    $exitCode = $proc.ExitCode
    if ($null -eq $exitCode -or "$exitCode" -eq "") {
        $expectedExe = Join-Path $root ("target\{0}.exe" -f $OutName)
        if (Test-Path $expectedExe) { $exitCode = 0 } else { $exitCode = 1 }
    }

    if ([int]$exitCode -ne 0) {
        Write-Host ("FAIL: {0} build exited {1}, peak {2} MB / {3} MB budget, wall {4}s" -f $Source, $exitCode, $peakRounded, $BudgetMb, $wallRounded)
        if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Tail 8 }
        if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath -Tail 8 }
        exit 1
    }

    Write-Host ("OK: {0} peak {1} MB / {2} MB budget, wall {3}s" -f $Source, $peakRounded, $BudgetMb, $wallRounded)
    exit 0
} finally {
    if ($null -eq $oldTrace) { Remove-Item Env:\NUC_TRACE_ALLOC -ErrorAction SilentlyContinue }
    else { $env:NUC_TRACE_ALLOC = $oldTrace }
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
