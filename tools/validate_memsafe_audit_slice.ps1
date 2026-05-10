param(
    [ValidateSet(
        "G1-FN-1","G1-X-1",
        "G2-A-1","G2-FN-1",
        "G3-X-1","G3-FP-1","G3-FN-1",
        "G4-FN-1","G4-A-2","G4-FN-2",
        "G5-P-1","G5-FN-1",
        "G6-A-1",
        "G8-A-2","G8-A-3",
        "G9-FN-1",
        "all"
    )]
    [string]$Finding = "all",
    [string]$CompilerPath = ".\bin\nucleor.exe"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot
$Compiler = (Resolve-Path $CompilerPath).Path
New-Item -ItemType Directory -Force -Path "target" | Out-Null

function Fail($Message) {
    Write-Error $Message
    exit 1
}

function Pass($Message) {
    Write-Output "PASS: $Message"
}

function Invoke-Nuc {
    param([string[]]$Arguments)

    $out = Join-Path "target" ("memsafe_" + [Guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path "target" ("memsafe_" + [Guid]::NewGuid().ToString("N") + ".err")
    try {
        $p = Start-Process -FilePath $Compiler -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ""
        if (Test-Path -LiteralPath $out) { $text += Get-Content -LiteralPath $out -Raw }
        if (Test-Path -LiteralPath $err) { $text += Get-Content -LiteralPath $err -Raw }
        return @{ ExitCode = $p.ExitCode; Text = $text }
    } finally {
        Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Target {
    param(
        [string]$OutName,
        [int]$ExpectedExitCode = 0,
        [string]$ExpectedText = ""
    )

    $exe = Join-Path "target" "$OutName.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        Fail "target executable missing: $exe"
    }

    $out = Join-Path "target" ("memsafe_run_" + [Guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path "target" ("memsafe_run_" + [Guid]::NewGuid().ToString("N") + ".err")
    try {
        $p = Start-Process -FilePath $exe -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ""
        if (Test-Path -LiteralPath $out) { $text += Get-Content -LiteralPath $out -Raw }
        if (Test-Path -LiteralPath $err) { $text += Get-Content -LiteralPath $err -Raw }
        if ($p.ExitCode -ne $ExpectedExitCode) {
            Fail "$OutName exited $($p.ExitCode), expected $ExpectedExitCode. Output:`n$text"
        }
        if ($ExpectedText -ne "" -and $text -notmatch [regex]::Escape($ExpectedText)) {
            Fail "$OutName did not contain expected text '$ExpectedText'. Output:`n$text"
        }
    } finally {
        Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    }
}

function Expect-Negative {
    param(
        [string]$Source,
        [string]$OutName,
        [string]$Diagnostic,
        [string]$Label
    )

    $r = Invoke-Nuc -Arguments @("build", $Source, "-o", $OutName, "--no-cache", "--no-link")
    if ($r.ExitCode -eq 0) {
        Fail "$Label unexpectedly compiled successfully. Output:`n$($r.Text)"
    }
    if ($r.Text -notmatch [regex]::Escape($Diagnostic)) {
        Fail "$Label did not contain diagnostic '$Diagnostic'. Output:`n$($r.Text)"
    }
    Pass $Label
}

function Expect-BuildContains {
    param(
        [string]$Source,
        [string]$OutName,
        [string]$Needle,
        [string]$Label,
        [switch]$Forbid
    )

    $r = Invoke-Nuc -Arguments @("build", $Source, "-o", $OutName, "--no-cache", "--no-link")
    if ($r.ExitCode -ne 0) {
        Fail "$Label build failed. Output:`n$($r.Text)"
    }
    if ($Forbid) {
        if ($r.Text -match [regex]::Escape($Needle)) {
            Fail "$Label emitted forbidden text '$Needle'. Output:`n$($r.Text)"
        }
    } else {
        if ($r.Text -notmatch [regex]::Escape($Needle)) {
            Fail "$Label did not contain expected text '$Needle'. Output:`n$($r.Text)"
        }
    }
    Pass $Label
}

function Expect-BuildRun {
    param(
        [string]$Source,
        [string]$OutName,
        [string]$ExpectedText,
        [string]$Label
    )

    $r = Invoke-Nuc -Arguments @("build", $Source, "-o", $OutName, "--no-cache")
    if ($r.ExitCode -ne 0) {
        Fail "$Label build failed. Output:`n$($r.Text)"
    }
    Invoke-Target -OutName $OutName -ExpectedExitCode 0 -ExpectedText $ExpectedText
    Pass $Label
}

function Expect-VecFreeCallCount {
    param(
        [string]$Source,
        [string]$OutName,
        [int]$ExpectedCount,
        [string]$Label
    )

    $r = Invoke-Nuc -Arguments @("build", $Source, "-o", $OutName, "--no-cache")
    if ($r.ExitCode -ne 0) {
        Fail "$Label build failed. Output:`n$($r.Text)"
    }
    Invoke-Target -OutName $OutName -ExpectedExitCode 0
    $ll = Join-Path "target" "$OutName.ll"
    if (-not (Test-Path -LiteralPath $ll)) {
        Fail "$Label missing LLVM output: $ll"
    }
    $matches = Select-String -Path $ll -Pattern "call void @__nucleor_vec_free" -AllMatches
    $count = @($matches).Count
    if ($count -ne $ExpectedCount) {
        Fail "$Label expected $ExpectedCount vec_free call(s), found $count"
    }
    Pass $Label
}

function Test-Finding {
    param([string]$Id)

    switch ($Id) {
        "G1-FN-1" { Expect-Negative "tests\err\err_g1_raw_handle_cast.nr" "_audit_g1_raw_handle_cast" "OWN-G1-RAW-HANDLE-CAST" "G1-FN-1 raw owned-handle casts rejected"; return }
        "G1-X-1" { Expect-VecFreeCallCount "tests\features\g1_alias_auto_drop_transfer_ok.nr" "_audit_g1_alias_transfer" 1 "G1-X-1 alias auto-drop ownership transfers once"; return }
        "G2-A-1" { Expect-Negative "tests\err\err_borrow_g2_lifetime_multi_input.nr" "_audit_g2_multi_lifetime" "BORROW-G2-LIFETIME" "G2-A-1 multi-input lifetime mismatch rejected"; return }
        "G2-FN-1" { Expect-Negative "tests\err\err_borrow_g2_lifetime_intermediate.nr" "_audit_g2_intermediate" "BORROW-G2-LIFETIME" "G2-FN-1 intermediate lifetime root traced"; return }
        "G3-X-1" { Expect-Negative "tests\err\err_g3_hashmap_free_while_borrowed.nr" "_audit_g3_hashmap_free_borrowed" "ALIAS-G3-HASHMAP-REHASH" "G3-X-1 collection free while borrowed rejected"; return }
        "G3-FP-1" { Expect-BuildContains "tests\features\g3_comment_vec_ref_no_warning.nr" "_audit_g3_comment_no_warning" "ALIAS-G3" "G3-FP-1 comments do not trigger alias warning" -Forbid; return }
        "G3-FN-1" {
            Expect-Negative "tests\err\err_g3_vec_of_refs_extend.nr" "_audit_g3_vec_refs_extend" "ALIAS-G3-VEC-OF-REFS" "G3-FN-1 vec_extend Vec-of-refs rejected"
            Expect-Negative "tests\err\err_g3_vec_of_refs_insert_at.nr" "_audit_g3_vec_refs_insert_at" "ALIAS-G3-VEC-OF-REFS" "G3-FN-1 vec_insert_at Vec-of-refs rejected"
            return
        }
        "G4-FN-1" { Expect-Negative "tests\err\err_g4_alias_double_free.nr" "_audit_g4_alias_double_free" "OWN-G4-USE-AFTER-DROP" "G4-FN-1 alias double-free rejected"; return }
        "G4-A-2" { Expect-Negative "tests\err\err_g4_loop_free.nr" "_audit_g4_loop_free" "OWN-G4-USE-AFTER-DROP" "G4-A-2 loop free flow joined"; return }
        "G4-FN-2" { Expect-Negative "tests\err\err_g4_method_free.nr" "_audit_g4_method_free" "OWN-G4-USE-AFTER-DROP" "G4-FN-2 method-form free marks receiver"; return }
        "G5-P-1" { Expect-BuildRun "tests\lang\ptr_is_null_intrinsic.nr" "_audit_g5_ptr_is_null" "OK ptr_is_null_intrinsic" "G5-P-1 ptr_is_null intrinsic works"; return }
        "G5-FN-1" { Expect-Negative "tests\err\err_g5_extern_i64_null_contract.nr" "_audit_g5_extern_i64_null" "FFI-G5-NULL-DEREF" "G5-FN-1 extern i64 nullable convention guarded"; return }
        "G6-A-1" { Expect-Negative "tests\err\err_g6_struct_with_hashmap_spawn.nr" "_audit_g6_struct_hashmap" "SEND-G6-HASHMAP" "G6-A-1 transitive non-Send struct rejected"; return }
        "G8-A-2" { Expect-Negative "tests\err\err_g8_nested_if_cond_move.nr" "_audit_g8_nested_if" "OWN-G8-COND-MOVE" "G8-A-2 nested conditional move rejected"; return }
        "G8-A-3" { Expect-Negative "tests\err\err_g8_loop_cond_move.nr" "_audit_g8_loop" "OWN-G8-COND-MOVE" "G8-A-3 loop conditional move rejected"; return }
        "G9-FN-1" { Expect-BuildContains "tests\features\g9_opt_in_cliff_disclosure.nr" "_audit_g9_optin_cliff" "EFFECT-G10-OPT-IN-CLIFF" "G9-FN-1 unannotated extern surface discloses inactive effects"; return }
        default { Fail "unknown memsafe finding: $Id" }
    }
}

$allFindings = @(
    "G1-FN-1","G1-X-1",
    "G2-A-1","G2-FN-1",
    "G3-X-1","G3-FP-1","G3-FN-1",
    "G4-FN-1","G4-A-2","G4-FN-2",
    "G5-P-1","G5-FN-1",
    "G6-A-1",
    "G8-A-2","G8-A-3",
    "G9-FN-1"
)

if ($Finding -eq "all") {
    foreach ($id in $allFindings) { Test-Finding $id }
} else {
    Test-Finding $Finding
}

Pass "memory safety/effects audit slice complete"
