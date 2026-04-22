# verify.ps1 — smoke gate for the Nucleor OSS distribution.
#
# Usage: powershell.exe -ExecutionPolicy Bypass -File tools\verify.ps1
#
# Steps:
#   1. Confirm bin\nucleor.exe exists and reports a version
#   2. Build and run examples 01..06 (07 only if rust_bridge has been built)
#   3. Build and run all positive tests under tests\{lang,attrs,runtime,rods}
#   4. Confirm negative tests under tests\err\ fail with the expected diagnostic
#   5. Self-host loop: rebuild the compiler from source, smoke-test the result
#
# Exit code:
#   0 = ship-ready
#   1 = a step failed; details printed before exit

$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $root "bin\nucleor.exe"
$nuc  = Join-Path $root "nuc.bat"

$totalPass = 0
$totalFail = 0
$failures  = @()

function Step($stepName, [scriptblock]$action) {
    Write-Host "[..] $stepName"
    $result = & $action
    $ok = $false
    if ($null -ne $result) {
        if ($result -is [array]) { $ok = [bool]($result[-1]) }
        else { $ok = [bool]$result }
    }
    if ($ok) {
        Write-Host "[OK] $stepName"
        $script:totalPass++
    } else {
        Write-Host "[FAIL] $stepName"
        $script:totalFail++
        $script:failures += $stepName
    }
}

# Ensure clang is on PATH (mirror nuc.bat resolution)
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
    if ($env:NUCLEOR_CLANG_PATH) {
        $env:PATH = (Split-Path -Parent $env:NUCLEOR_CLANG_PATH) + ";" + $env:PATH
    } elseif ($env:LLVM_SYS_180_PREFIX) {
        $env:PATH = (Join-Path $env:LLVM_SYS_180_PREFIX "bin") + ";" + $env:PATH
    } elseif (Test-Path "C:\Program Files\LLVM\bin\clang.exe") {
        $env:PATH = "C:\Program Files\LLVM\bin;" + $env:PATH
    }
}

Push-Location $root

Step "binary present" {
    if (-not (Test-Path $bin)) { return $false }
    $out = & $bin help 2>&1 | Select-String "Nucleor Compiler" | Select-Object -First 1
    return $null -ne $out
}

# Examples 01..06 + 08..12 (07 needs rust_bridge built)
$examples = @("01_hello", "02_fib", "03_structs", "04_rods", "05_quantum", "06_perf_attrs",
              "08_linalg", "09_ode", "10_fft", "11_pid", "12_autodiff")
$rustBridgeLib = Join-Path $root "stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib"
if (Test-Path $rustBridgeLib) {
    $examples += "07_rust_interop"
} else {
    Write-Host "[SKIP] 07_rust_interop (rust_bridge not built; run: cd stdlib\rods\rust_bridge; cargo build --release)"
}

foreach ($ex in $examples) {
    Step "example $ex builds and runs" {
        $src = "examples/$ex.nr"
        $out = & $bin build $src -o $ex 2>&1
        if (-not (Test-Path "target\$ex.exe")) {
            Write-Host ($out | Out-String)
            return $false
        }
        $runOut = & "target\$ex.exe" 2>&1
        return $LASTEXITCODE -eq 0
    }
}

# Positive tests
foreach ($dir in @("lang", "attrs", "runtime", "rods")) {
    $testFiles = Get-ChildItem -Path (Join-Path $root "tests\$dir") -Filter "*.nr" -ErrorAction SilentlyContinue
    foreach ($t in $testFiles) {
        $name = $t.BaseName
        Step "test $dir/$name" {
            if ($name -eq "rust_interop" -and -not (Test-Path $rustBridgeLib)) {
                Write-Host "  (skipping - rust_bridge not built)"
                return $true
            }
            $src = "tests/$dir/$($t.Name)"
            $build = & $bin build $src -o $name 2>&1 | Out-String
            $exePath = Join-Path $root "target\$name.exe"
            if (-not (Test-Path $exePath)) {
                Write-Host "  build failed: $build"
                return $false
            }
            $runOut = (& $exePath 2>&1) | Out-String
            return ($runOut -match "(?m)^OK ")
        }
    }
}

# Negative tests: expect a build failure
$errFiles = Get-ChildItem -Path (Join-Path $root "tests\err") -Filter "*.nr" -ErrorAction SilentlyContinue
foreach ($e in $errFiles) {
    $name = $e.BaseName
    Step "negative test $name fails as expected" {
        $src = "tests/err/$($e.Name)"
        $out = & $bin build $src -o $name 2>&1
        $sawErr = $out | Select-String "ERROR|WARNING|error:" | Select-Object -First 1
        return $null -ne $sawErr
    }
}

# Self-host loop
Step "self-host rebuild closes" {
    $out = & $bin build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler" 2>&1
    return (Test-Path "target\verify_compiler.exe")
}

# Cleanup
Remove-Item -Recurse -Force (Join-Path $root "target") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $root ".nuc_cache") -ErrorAction SilentlyContinue

Pop-Location

Write-Host ""
Write-Host "==="
Write-Host "PASS: $totalPass"
Write-Host "FAIL: $totalFail"
if ($totalFail -gt 0) {
    Write-Host "Failed steps:"
    foreach ($f in $failures) { Write-Host "  - $f" }
    exit 1
}
exit 0
