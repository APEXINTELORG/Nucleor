# run_numerics_matrix.ps1 — runs the T1.1 numerics test matrix.
#
# Walks tests/lang/numerics_matrix/p*/ subdirectories. For each
# .nr file: builds, runs, classifies as PASS / FAIL / BUILD_ERROR.
# Prints per-test status and a per-phase summary at the end.
#
# Designed to ALWAYS exit 0 — the matrix is informational, not a
# CI gate. Track progress via the printed summary.
#
# Usage: pwsh tools/run_numerics_matrix.ps1

$root = (Resolve-Path "$PSScriptRoot\..").Path
$matrix = Join-Path $root "tests\lang\numerics_matrix"
$nucleor = Join-Path $root "bin\nucleor.exe"
$tgt = Join-Path $root "target"

if (-not (Test-Path $nucleor)) {
    Write-Host "ERROR: $nucleor not found. Build the compiler first." -ForegroundColor Red
    exit 0
}

# Ensure clang is on PATH.
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\LLVM\bin\clang.exe") {
        $env:PATH = "C:\Program Files\LLVM\bin;$env:PATH"
    }
}

$phases = Get-ChildItem -Path $matrix -Directory | Where-Object { $_.Name -like "p*" } | Sort-Object Name
$total = 0; $pass = 0; $fail = 0; $berr = 0
$summary = @()

foreach ($ph in $phases) {
    $ph_pass = 0; $ph_fail = 0; $ph_berr = 0
    $files = Get-ChildItem -Path $ph.FullName -Filter "*.nr" | Sort-Object Name
    foreach ($f in $files) {
        $total++
        $rel = $f.FullName.Substring($root.Length + 1)
        # Build with stderr captured.
        $build = & $nucleor build $rel 2>&1
        if ($LASTEXITCODE -ne 0) {
            $berr++; $ph_berr++
            Write-Host ("[{0,-12}] {1,-30} BUILD_ERROR" -f $ph.Name, $f.BaseName) -ForegroundColor DarkYellow
            continue
        }
        $exe = Join-Path $tgt ($f.BaseName + ".exe")
        if (-not (Test-Path $exe)) {
            $berr++; $ph_berr++
            Write-Host ("[{0,-12}] {1,-30} NO_EXE" -f $ph.Name, $f.BaseName) -ForegroundColor DarkYellow
            continue
        }
        # Run; treat exit 0 as pass.
        $out = & $exe 2>&1
        if ($LASTEXITCODE -eq 0) {
            $pass++; $ph_pass++
            Write-Host ("[{0,-12}] {1,-30} PASS" -f $ph.Name, $f.BaseName) -ForegroundColor Green
        } else {
            $fail++; $ph_fail++
            Write-Host ("[{0,-12}] {1,-30} FAIL" -f $ph.Name, $f.BaseName) -ForegroundColor Red
        }
    }
    $summary += [pscustomobject]@{ Phase = $ph.Name; Pass = $ph_pass; Fail = $ph_fail; BuildError = $ph_berr; Total = ($ph_pass + $ph_fail + $ph_berr) }
}

Write-Host ""
Write-Host "===== Numerics matrix summary =====" -ForegroundColor Cyan
$summary | Format-Table -AutoSize | Out-String | Write-Host
Write-Host ("TOTAL: pass={0}  fail={1}  build_error={2}  total={3}" -f $pass, $fail, $berr, $total) -ForegroundColor Cyan
exit 0
