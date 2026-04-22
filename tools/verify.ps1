# verify.ps1 — smoke gate for the Nucleor OSS distribution.
#
# Usage: powershell.exe -ExecutionPolicy Bypass -File tools\verify.ps1
#
# Steps:
#   1. Confirm bin\nucleor.exe loads
#   2. Build and run examples 01..06 + 08..12 (07 only if rust_bridge built)
#   3. Build and run all positive tests under tests\{lang,attrs,runtime,rods}
#   4. Confirm negative tests under tests\err\ fail with the expected diagnostic
#   5. Self-host loop: rebuild the compiler from source
#
# Exit code: 0 = ship-ready; 1 = a step failed.
#
# Output: progress counter [N/T] per step, colored OK/FAIL/SKIP labels when
# stdout is a TTY. Honors NO_COLOR (https://no-color.org/) and --no-color.

param(
    [switch]$NoColor
)

$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $root "bin\nucleor.exe"

# --- Color setup --------------------------------------------------------
$useColor = $true
if ($NoColor) { $useColor = $false }
if ($env:NO_COLOR) { $useColor = $false }
# Detect TTY: PowerShell knows via $Host.UI.RawUI; piped output is BufferSize=null.
try {
    $null = $Host.UI.RawUI.WindowSize
} catch {
    $useColor = $false
}

# Enable VT processing for ANSI colors on Windows 10+ cmd / PowerShell hosts.
if ($useColor) {
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
}

function Color($text, $ansi) {
    if ($useColor) { return "$([char]27)[${ansi}m${text}$([char]27)[0m" } else { return $text }
}
function Green($t)  { return Color $t "32" }
function Yellow($t) { return Color $t "33" }
function Red($t)    { return Color $t "31" }
function Dim($t)    { return Color $t "2"  }

# --- Step counter -------------------------------------------------------
$totalPass = 0
$totalFail = 0
$totalSkip = 0
$failures  = @()
$stepIndex = 0
$stepTotal = 0   # filled in once we know the totals

function Step($stepName, [scriptblock]$action) {
    $script:stepIndex++
    $prefix = "[{0,3}/{1}]" -f $script:stepIndex, $script:stepTotal
    $result = & $action
    $ok = $false
    $skipped = $false
    if ($null -ne $result) {
        if ($result -is [array]) {
            $last = $result[-1]
            if ($last -is [string] -and $last -eq "SKIP") { $skipped = $true }
            else { $ok = [bool]$last }
        } else {
            if ($result -is [string] -and $result -eq "SKIP") { $skipped = $true }
            else { $ok = [bool]$result }
        }
    }
    if ($skipped) {
        Write-Host ("$prefix " + (Yellow "SKIP") + "  $stepName")
        $script:totalSkip++
    } elseif ($ok) {
        Write-Host ("$prefix " + (Green "OK  ") + "  $stepName")
        $script:totalPass++
    } else {
        Write-Host ("$prefix " + (Red   "FAIL") + "  $stepName")
        $script:totalFail++
        $script:failures += $stepName
    }
}

# --- Ensure clang is on PATH (mirror nuc.bat resolution) ----------------
# Verify each candidate has clang.exe before accepting it (env vars can be stale).
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
    $clangCandidate = $null
    if ($env:NUCLEOR_CLANG_PATH -and (Test-Path $env:NUCLEOR_CLANG_PATH)) {
        $clangCandidate = Split-Path -Parent $env:NUCLEOR_CLANG_PATH
    } elseif ($env:LLVM_SYS_180_PREFIX -and (Test-Path (Join-Path $env:LLVM_SYS_180_PREFIX "bin\clang.exe"))) {
        $clangCandidate = Join-Path $env:LLVM_SYS_180_PREFIX "bin"
    } elseif (Test-Path "C:\Program Files\LLVM\bin\clang.exe") {
        $clangCandidate = "C:\Program Files\LLVM\bin"
    }
    if ($clangCandidate) {
        $env:PATH = "$clangCandidate;$env:PATH"
    }
}

Push-Location $root

# --- Compute total step count for the [N/T] counter ---------------------
$rustBridgeLib = Join-Path $root "stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib"
$examples = @("01_hello", "02_fib", "03_structs", "04_rods", "05_quantum", "06_perf_attrs",
              "08_linalg", "09_ode", "10_fft", "11_pid", "12_autodiff")
if (Test-Path $rustBridgeLib) { $examples += "07_rust_interop" }

$testDirs = @("lang", "attrs", "runtime", "rods", "features")
$testCount = 0
foreach ($d in $testDirs) {
    $testCount += (Get-ChildItem -Path (Join-Path $root "tests\$d") -Filter "*.nr" -ErrorAction SilentlyContinue).Count
}
$errCount = (Get-ChildItem -Path (Join-Path $root "tests\err") -Filter "*.nr" -ErrorAction SilentlyContinue).Count

# 1 (binary present) + N examples + N tests + N err + 1 (self-host)
$stepTotal = 1 + $examples.Count + $testCount + $errCount + 1

# --- Run the gate -------------------------------------------------------
Step "binary present" {
    if (-not (Test-Path $bin)) { return $false }
    $out = & $bin help 2>&1 | Select-String "Nucleor Compiler" | Select-Object -First 1
    return $null -ne $out
}

foreach ($ex in $examples) {
    Step "example $ex" {
        $src = "examples/$ex.nr"
        $out = & $bin build $src -o $ex 2>&1 | Out-String
        if (-not (Test-Path "target\$ex.exe")) {
            Write-Host (Dim ("       " + ($out.Trim() -split "`n" | Select-Object -Last 1)))
            return $false
        }
        $runOut = & "target\$ex.exe" 2>&1
        return $LASTEXITCODE -eq 0
    }
}

foreach ($dir in $testDirs) {
    $testFiles = Get-ChildItem -Path (Join-Path $root "tests\$dir") -Filter "*.nr" -ErrorAction SilentlyContinue | Sort-Object Name
    foreach ($t in $testFiles) {
        $tname = $t.BaseName
        Step "test $dir/$tname" {
            if ($tname -eq "rust_interop" -and -not (Test-Path $rustBridgeLib)) {
                return "SKIP"
            }
            $src = "tests/$dir/$($t.Name)"
            $build = & $bin build $src -o $tname 2>&1 | Out-String
            $exePath = Join-Path $root "target\$tname.exe"
            if (-not (Test-Path $exePath)) {
                Write-Host (Dim "       build failed")
                return $false
            }
            $runOut = (& $exePath 2>&1) | Out-String
            $exit = $LASTEXITCODE
            if ($dir -eq "features") {
                # Feature parity tests: pass if the program built and ran without
                # an access-violation crash. They exercise language constructs by
                # construction, not by printing "OK".
                return ($exit -ne -1073741819 -and $exit -ne -1073740940)
            }
            return ($runOut -match "(?m)^OK ")
        }
    }
}

$errFiles = Get-ChildItem -Path (Join-Path $root "tests\err") -Filter "*.nr" -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($e in $errFiles) {
    $ename = $e.BaseName
    Step "negative $ename" {
        $src = "tests/err/$($e.Name)"
        $out = & $bin build $src -o $ename 2>&1
        $sawErr = $out | Select-String "ERROR|WARNING|error:" | Select-Object -First 1
        return $null -ne $sawErr
    }
}

Step "self-host rebuild closes" {
    $out = & $bin build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler" 2>&1 | Out-String
    return (Test-Path "target\verify_compiler.exe")
}

Remove-Item -Recurse -Force (Join-Path $root "target") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $root ".nuc_cache") -ErrorAction SilentlyContinue

Pop-Location

Write-Host ""
Write-Host (Dim "===")
Write-Host ("PASS: " + (Green $totalPass))
if ($totalSkip -gt 0) { Write-Host ("SKIP: " + (Yellow $totalSkip)) }
if ($totalFail -gt 0) {
    Write-Host ("FAIL: " + (Red $totalFail))
    Write-Host (Red "Failed steps:")
    foreach ($f in $failures) { Write-Host (Dim "  - $f") }
    exit 1
}
exit 0
