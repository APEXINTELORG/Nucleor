param(
    [string]$Finding = "all",
    [string]$CompilerPath = ".\bin\nucleor.exe"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
    $Global:PSNativeCommandUseErrorActionPreference = $false
}
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Fail($msg) {
    Write-Host "FAIL: $msg"
    exit 1
}

function Pass($msg) {
    Write-Host "PASS: $msg"
}

function Run-Build($src, $outName) {
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & $CompilerPath build $src -o $outName --no-cache 2>&1
        return [pscustomobject]@{ Rc = $LASTEXITCODE; Out = ($out | Out-String) }
    } finally {
        $ErrorActionPreference = $oldEap
    }
}

function Need-Code($src, $outName, $code, [switch]$NeedFrame, [switch]$NeedLineText) {
    $r = Run-Build $src $outName
    if ($r.Rc -eq 0) { Fail "$src unexpectedly built successfully" }
    if ($r.Out -notmatch [regex]::Escape("error[$code]")) { Fail "$src did not emit error[$code]`n$($r.Out)" }
    if ($NeedFrame -and $r.Out -notmatch "-->") { Fail "$src emitted $code without a source frame`n$($r.Out)" }
    if ($NeedLineText -and $r.Out -notmatch "line\s+[0-9]+:[0-9]+") { Fail "$src emitted $code without line:column text`n$($r.Out)" }
    return $r.Out
}

function Check-FDIAG001 {
    Need-Code "tests\err\parse_f013_missing_let_semicolon.nr" "_diag001_parse" "PARSE-LET-SEMI" -NeedLineText | Out-Null
    Need-Code "tests\err\err_nam001_duplicate_param.nr" "_diag001_nam" "NAM-001" -NeedLineText | Out-Null
    Pass "F-DIAG-001 parse-time diagnostics include line:column evidence"
}

function Check-FDIAG003 {
    Need-Code "tests\err\err_use_after_move.nr" "_diag003_own" "OWN-001" -NeedFrame | Out-Null
    Need-Code "tests\err\err_borrow_after_move.nr" "_diag003_borrow" "OWN-001" -NeedFrame | Out-Null
    Need-Code "tests\err\err_box_use_after_move.nr" "_diag003_box" "OWN-001" -NeedFrame | Out-Null
    $s1 = Get-Content "compiler\nucleor_s1_compiler.nr" -Raw
    $suite = Get-Content "compiler\nucleor_tools_suite.nr" -Raw
    if ($s1 -match 'warning", "ownership", "OWN-001"') { Fail "s1 still emits OWN-001 as warning" }
    if ($suite -match 'warning", "ownership", "OWN-001"') { Fail "tools suite still emits OWN-001 as warning" }
    Pass "F-DIAG-003 OWN-001 is an error and exits nonzero"
}

function Check-FDIAG004 {
    $out = Need-Code "tests\err\err_rfc0035_mut_ref_spawn.nr" "_diag004_race" "RACE-005" -NeedFrame
    if ($out -match "@line 0:0") { Fail "RACE-005 still reports line 0:0`n$out" }
    if ($out -notmatch "&mut x") { Fail "RACE-005 did not point at the non-bare argument`n$out" }
    Pass "F-DIAG-004 non-bare spawn arguments have real source locations"
}

function Check-FDIAG005 {
    $s1 = Get-Content "compiler\nucleor_s1_compiler.nr" -Raw
    if ($s1 -match 'diag_add_ex\([^\n]*,\s*0,\s*0') { Fail "main compiler still has diag_add_ex(..., 0, 0) call sites" }
    Need-Code "tests\err\err_atomic_001_blocking.nr" "_diag005_atomic" "ATOMIC-001" -NeedFrame | Out-Null
    Pass "F-DIAG-005 hard-coded 0,0 diagnostic sites removed from s1"
}

function Check-FDIAG006 {
    $codes = @(
        "ASYNC-001","CONTRACT-004","CONTRACT-005","DIAG-001","LAW-001","LAW-004",
        "LAW-006","LAW-007","LAW-008","MATCH-015","NAM-001","PERF-2","PERF-3",
        "PKG-3","PKG-6","RT-005","RT-008","TNT-001"
    )
    $missing = @()
    foreach ($code in $codes) {
        $hit = Select-String -Path "tests\err\*.nr" -Pattern "^\s*//\s*EXPECT:\s+$([regex]::Escape($code))(\s|$)" -List -ErrorAction SilentlyContinue
        if (-not $hit) { $missing += $code }
    }
    if ($missing.Count -gt 0) { Fail "missing tests/err EXPECT coverage for: $($missing -join ', ')" }
    Pass "F-DIAG-006 emitted diagnostic codes have tests/err EXPECT coverage"
}

function Check-FDIAG010 {
    Need-Code "tests\err\err_tnt001_taint_into_sensitive.nr" "_diag010_tnt" "TNT-001" -NeedFrame | Out-Null
    Pass "F-DIAG-010 TNT-001 has an emission path with source frame"
}

function Check-FDIAG014 {
    $verify = Get-Content "tools\verify.sh" -Raw
    if ($verify -notmatch 'negative_test_exited_zero') { Fail "verify.sh does not enforce nonzero exit for negative tests" }
    if ($verify -notmatch '_read_expect_code') { Fail "verify.sh does not read EXPECT codes" }
    if ($verify -notmatch '\(error\|warning\)\\\[') { Fail "verify.sh does not match explicit EXPECT diagnostic codes" }
    $ps = Get-Content "tools\verify.ps1" -Raw
    if ($ps -notmatch '\$rc -eq 0') { Fail "verify.ps1 does not reject zero-exit negative tests" }
    if ($ps -notmatch 'EXPECT') { Fail "verify.ps1 does not read EXPECT codes" }
    Pass "F-DIAG-014 negative runner is exit-code and EXPECT-code aware"
}

$all = @(
    "F-DIAG-001","F-DIAG-003","F-DIAG-004","F-DIAG-005",
    "F-DIAG-006","F-DIAG-010","F-DIAG-014"
)

foreach ($f in $all) {
    if ($Finding -eq "all" -or $Finding -eq $f) {
        switch ($f) {
            "F-DIAG-001" { Check-FDIAG001 }
            "F-DIAG-003" { Check-FDIAG003 }
            "F-DIAG-004" { Check-FDIAG004 }
            "F-DIAG-005" { Check-FDIAG005 }
            "F-DIAG-006" { Check-FDIAG006 }
            "F-DIAG-010" { Check-FDIAG010 }
            "F-DIAG-014" { Check-FDIAG014 }
        }
    }
}

Pass "diagnostics audit slice complete"
