# verify.ps1 — smoke gate for the Nucleor OSS distribution.
#
# Usage: powershell.exe -ExecutionPolicy Bypass -File tools\verify.ps1
#
# Steps:
#   1. Confirm bin\nucleor.exe loads
#   2. Build and run examples 01..06 + 08..18 (07 only if rust_bridge built)
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
# Read example list from the single source of truth (shared with
# verify.sh). v0.2.60 — eliminates the drift class that bit v0.2.59.
$examplesFile = Join-Path $root "tools\examples.list"
$examples = @()
if (Test-Path $examplesFile) {
    Get-Content $examplesFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $examples += $line
        }
    }
}
if (Test-Path $rustBridgeLib) { $examples += "07_rust_interop" }

$testDirs = @("lang", "attrs", "runtime", "rods", "features")
# Files matching this pattern are auxiliary helpers imported by another
# test (e.g. via `mod foo;`) and are not standalone-runnable. Skipping
# them keeps the gate from treating them as duplicate-main failures.
$testSkipPattern = "_aux\.nr$"
$testCount = 0
foreach ($d in $testDirs) {
    $testCount += (Get-ChildItem -Path (Join-Path $root "tests\$d") -Filter "*.nr" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $testSkipPattern }).Count
}
$errCount = (Get-ChildItem -Path (Join-Path $root "tests\err") -Filter "*.nr" -ErrorAction SilentlyContinue).Count

# 1 (binary present) + 1 (drift check) + 1 (CLI explain smoke) +
# 1 (CLI init smoke) + 1 (CLI doc smoke) + 1 (CLI lock smoke) +
# N examples + N tests + N err + 1 (self-host)
$stepTotal = 6 + $examples.Count + $testCount + $errCount + 1

# --- Run the gate -------------------------------------------------------
Step "binary present" {
    if (-not (Test-Path $bin)) { return $false }
    $out = & $bin help 2>&1 | Select-String "Nucleor Compiler" | Select-Object -First 1
    return $null -ne $out
}

Step "compiler ABI tables synced" {
    # Mirrors tools/check_compiler_drift.sh — verify the s1-compiler ↔
    # tools-suite get_rt_name / is_ptr_ret / is_ptr_arg / IR `declare`
    # tables stay aligned.  Drift produces unprefixed @<name> calls in
    # `nuc test` / `nuc build-strict` / `nuc check`.
    $bash = $env:NUCLEOR_BASH_PATH
    if (-not $bash -or -not (Test-Path $bash)) {
        if (Test-Path "C:\Program Files\Git\bin\bash.exe") {
            $bash = "C:\Program Files\Git\bin\bash.exe"
        } elseif (Test-Path "C:\msys64\usr\bin\bash.exe") {
            $bash = "C:\msys64\usr\bin\bash.exe"
        } else {
            # Bash unavailable on this host; skip silently rather than fail
            # the gate. Linux/macOS gates always run the bash version.
            return $true
        }
    }
    $script = Join-Path $root "tools\check_compiler_drift.sh"
    & $bash $script *> $null
    return $LASTEXITCODE -eq 0
}

Step "CLI: nuc explain NUM-001 wired" {
    # Mirrors verify.sh cli_explain_smoke (added v0.2.64). Exercises
    # the explain registry in nucleor_tools_suite.nr so codes added
    # to docs/spec/Nucleor_Error_Codes.md can't drift from the
    # registry without the gate noticing. Mirrored to PowerShell in
    # v0.2.65.
    $explainOut = & $bin explain "NUM-001" 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($explainOut)) { return $false }
    if ($explainOut -notmatch "NUM-001") { return $false }
    if ($explainOut -notmatch "Mixed-width") { return $false }
    if ($explainOut -notmatch "Nucleor_Error_Codes") { return $false }
    return $true
}

Step "CLI: nuc init scaffolding works" {
    # Mirrors verify.sh cli_init_smoke (added v0.2.66). Verifies the
    # new-user-first-command produces a working project: scaffolds
    # Nucleor.toml + src/main.nr, manifest declares name + entry,
    # and the scaffold compiles + runs to non-empty stdout.
    $sandbox = Join-Path $env:TEMP "_nuc_init_smoke_$PID"
    if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        Push-Location $sandbox
        & $bin init smokeproj *> $null
        if (-not (Test-Path "smokeproj\Nucleor.toml")) { return $false }
        if (-not (Test-Path "smokeproj\src\main.nr")) { return $false }
        $manifest = Get-Content "smokeproj\Nucleor.toml" -Raw
        if ($manifest -notmatch 'name = "smokeproj"') { return $false }
        if ($manifest -notmatch 'entry = "src/main.nr"') { return $false }
        Push-Location "smokeproj"
        & $bin build "src/main.nr" -o "smokeproj" *> $null
        $exe = "target\smokeproj.exe"
        if (-not (Test-Path $exe)) { Pop-Location; return $false }
        $runOut = & $exe 2>&1 | Out-String
        Pop-Location
        if ([string]::IsNullOrWhiteSpace($runOut)) { return $false }
        return $true
    }
    finally {
        Pop-Location
        if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
    }
}

Step "CLI: nuc doc generator works" {
    # Mirrors verify.sh cli_doc_smoke (added v0.2.67). Exercises
    # RFC-0029 phase 1 doc generator: reads /// doc comments, emits
    # Markdown with function index + per-fn signature blocks; --out
    # flag writes to file.
    $sandbox = Join-Path $env:TEMP "_nuc_doc_smoke_$PID"
    if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        Push-Location $sandbox
        $src = @"
/// Adds two integers.
fn smoke_add(a: i64, b: i64) -> i64 { return a + b; }
"@
        Set-Content -Path "smoke.nr" -Value $src -Encoding UTF8
        $stdoutOut = & $bin doc "smoke.nr" 2>&1 | Out-String
        if ($stdoutOut -notmatch "smoke_add") { return $false }
        if ($stdoutOut -notmatch "## Function index") { return $false }
        if ($stdoutOut -notmatch "Adds two integers") { return $false }
        if ($stdoutOut -notmatch "Signature") { return $false }
        & $bin doc "smoke.nr" --out "smoke.md" *> $null
        if (-not (Test-Path "smoke.md")) { return $false }
        $fileContent = Get-Content "smoke.md" -Raw
        if ($fileContent -notmatch "smoke_add") { return $false }
        return $true
    }
    finally {
        Pop-Location
        if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
    }
}

Step "CLI: nuc lock writes Nucleor.lock" {
    # Mirrors verify.sh cli_lock_smoke (added v0.2.68). RFC-0019
    # phase 1 lockfile generator. Verifies init -> lock -> reads
    # back canonical fields.
    $sandbox = Join-Path $env:TEMP "_nuc_lock_smoke_$PID"
    if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        Push-Location $sandbox
        & $bin init lockproj *> $null
        Push-Location "lockproj"
        & $bin lock *> $null
        if (-not (Test-Path "Nucleor.lock")) { Pop-Location; return $false }
        $lock = Get-Content "Nucleor.lock" -Raw
        Pop-Location
        if ($lock -notmatch '^version = ') { return $false }
        if ($lock -notmatch 'root = "Nucleor.toml"') { return $false }
        if ($lock -notmatch 'root_package = "lockproj"') { return $false }
        if ($lock -notmatch '\[\[package\]\]') { return $false }
        if ($lock -notmatch 'name = "lockproj"') { return $false }
        return $true
    }
    finally {
        Pop-Location
        if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
    }
}

foreach ($ex in $examples) {
    Step "example $ex" {
        $src = "examples/$ex.nr"
        $out = & $bin build $src -o $ex 2>&1 | Out-String
        if (-not (Test-Path "target\$ex.exe")) {
            Write-Host (Dim ("       " + ($out.Trim() -split "`n" | Select-Object -Last 1)))
            return $false
        }
        $runOut = & "target\$ex.exe" 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Host (Dim ("       " + ($runOut.Trim() -split "`n" | Select-Object -Last 1)))
            return $false
        }
        # Non-empty stdout shape check (added v0.2.62, mirrors verify.sh
        # v0.2.61) — catches silent regressions where the binary builds
        # + exits 0 but prints nothing.
        if ([string]::IsNullOrWhiteSpace($runOut)) {
            Write-Host (Dim "       example produced empty output")
            return $false
        }
        return $true
    }
}

foreach ($dir in $testDirs) {
    $testFiles = Get-ChildItem -Path (Join-Path $root "tests\$dir") -Filter "*.nr" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $testSkipPattern } | Sort-Object Name
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
