param(
    [string]$CompilerPath = ".\bin\nucleor.exe",
    [ValidateSet("all","F-001","F-002","F-003","F-004","F-005","F-006","F-007","F-008","F-009","F-010","F-011","F-012","F-013","F-014","F-015","F-016","F-018","F-019","F-020","F-021","positive")]
    [string]$Finding = "all"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Fail($msg) {
    Write-Error $msg
    exit 1
}

function Pass($msg) {
    Write-Host "PASS: $msg"
}

function Run-Capture {
    param([string[]]$ArgList)
    $out = Join-Path "target" ("typesystem_" + [Guid]::NewGuid().ToString("N") + ".out")
    $err = Join-Path "target" ("typesystem_" + [Guid]::NewGuid().ToString("N") + ".err")
    try {
        $p = Start-Process -FilePath $script:Compiler -ArgumentList $ArgList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
        $text = ""
        if (Test-Path -LiteralPath $out) { $text += Get-Content -LiteralPath $out -Raw }
        if (Test-Path -LiteralPath $err) { $text += Get-Content -LiteralPath $err -Raw }
        return @{ ExitCode = $p.ExitCode; Output = $text }
    } finally {
        Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    }
}

function Expect-FailCode {
    param(
        [string]$Fixture,
        [string]$OutName,
        [string]$Code,
        [string]$Label,
        [string]$Forbidden = ""
    )
    $r = Run-Capture -ArgList @("build", $Fixture, "-o", $OutName, "--no-cache", "--no-link")
    if ($r.ExitCode -eq 0) {
        Fail "$Label unexpectedly compiled successfully"
    }
    if ($r.Output -notmatch [regex]::Escape($Code)) {
        Fail "$Label did not emit $Code. Output:`n$($r.Output)"
    }
    if ($Forbidden -and $r.Output -match [regex]::Escape($Forbidden)) {
        Fail "$Label emitted forbidden text '$Forbidden'. Output:`n$($r.Output)"
    }
    Pass $Label
}

function Expect-BuildRun {
    param(
        [string]$Fixture,
        [string]$OutName,
        [string]$Expected
    )
    $r = Run-Capture -ArgList @("build", $Fixture, "-o", $OutName, "--no-cache")
    if ($r.ExitCode -ne 0) {
        Fail "positive build failed for ${Fixture}:`n$($r.Output)"
    }
    $exe = Join-Path "target" "$OutName.exe"
    $runOut = Join-Path "target" ("typesystem_run_" + [Guid]::NewGuid().ToString("N") + ".out")
    $runErr = Join-Path "target" ("typesystem_run_" + [Guid]::NewGuid().ToString("N") + ".err")
    try {
        $p = Start-Process -FilePath $exe -NoNewWindow -Wait -PassThru -RedirectStandardOutput $runOut -RedirectStandardError $runErr
        $text = ""
        if (Test-Path -LiteralPath $runOut) { $text += Get-Content -LiteralPath $runOut -Raw }
        if (Test-Path -LiteralPath $runErr) { $text += Get-Content -LiteralPath $runErr -Raw }
        if ($p.ExitCode -ne 0 -or $text -notmatch [regex]::Escape($Expected)) {
            Fail "positive run failed for ${Fixture}: rc=$($p.ExitCode), output:`n$text"
        }
    } finally {
        Remove-Item -LiteralPath $runOut,$runErr -Force -ErrorAction SilentlyContinue
    }
    Pass "positive fixture $Fixture"
}

$repo = (Resolve-Path ".").Path
$script:Compiler = (Resolve-Path $CompilerPath).Path
New-Item -ItemType Directory -Force -Path "target" | Out-Null

function Invoke-Finding {
    param([string]$Id)
    switch ($Id) {
        "F-001" { Expect-FailCode "tests\err\err_typ001_generic_arity_struct.nr" "_typ_f001_arity" "TYP-005" "F-001 generic type-argument arity rejected" }
        "F-002" { Expect-FailCode "tests\err\err_audit_lane1_match_pattern_wrong_enum.nr" "_typ_f002_wrong_enum" "MATCH-016" "F-002 cross-enum match rejected" }
        "F-003" { Expect-FailCode "tests\err\err_typ044_implicit_int_narrow.nr" "_typ_f003_narrow" "TYP-044" "F-003 implicit integer narrowing rejected" }
        "F-004" { Expect-FailCode "tests\err\err_typ044_implicit_int_widen.nr" "_typ_f004_widen" "TYP-044" "F-004 implicit integer widening rejected" }
        "F-005" { Expect-FailCode "tests\err\err_typ008_int_literal_to_f64.nr" "_typ_f005_int_to_f64" "TYP-008" "F-005 int literal to f64 rejected" }
        "F-006" { Expect-FailCode "tests\err\err_typ008_generic_enum_payload.nr" "_typ_f006_enum_payload" "TYP-008" "F-006 generic enum payload checked" }
        "F-007" { Expect-FailCode "tests\err\err_typ008_generic_struct_field_substitute.nr" "_typ_f007_struct_field" "TYP-008" "F-007 generic struct field substitution checked" }
        "F-008" { Expect-FailCode "tests\err\err_typ008_generic_struct_field_init.nr" "_typ_f008_struct_init" "TYP-008" "F-008 generic struct field initializer checked" }
        "F-009" { Expect-FailCode "tests\err\err_typ009_impl_missing_method.nr" "_typ_f009_impl_missing" "TYP-008" "F-009 trait impl missing method rejected" }
        "F-010" { Expect-FailCode "tests\err\err_typ010_impl_signature_mismatch.nr" "_typ_f010_impl_sig" "TYP-008" "F-010 trait impl signature mismatch rejected" }
        "F-011" { Expect-FailCode "tests\err\err_typ011_impl_extra_method.nr" "_typ_f011_impl_extra" "TYP-008" "F-011 trait impl extra method rejected" }
        "F-012" { Expect-FailCode "tests\err\err_typ012_mutual_recursive_struct.nr" "_typ_f012_mutual_rec" "NR036" "F-012 mutual recursive structs rejected" }
        "F-013" { Expect-FailCode "tests\err\err_typ013_recursive_generic_struct.nr" "_typ_f013_generic_rec" "NR036" "F-013 generic self-recursive struct rejected" }
        "F-014" { Expect-FailCode "tests\err\err_typ014_where_unknown_type_param.nr" "_typ_f014_where_unknown" "TYP-008" "F-014 unknown where-clause type parameter rejected" }
        "F-015" { Expect-FailCode "tests\err\err_audit_lane1_duplicate_type_param.nr" "_typ_f015_dup_param" "TYP-042" "F-015 duplicate type parameter rejected" }
        "F-016" { Expect-FailCode "tests\err\err_audit_lane1_type_param_shadows_primitive.nr" "_typ_f016_primitive_shadow" "TYP-041" "F-016 primitive-shadow type parameter rejected" }
        "F-018" { Expect-FailCode "tests\err\err_typ018_ambiguous_generic_inference.nr" "_typ_f018_ambiguous_infer" "TYP-027" "F-018 ambiguous generic inference rejected" }
        "F-019" { Expect-FailCode "tests\err\err_method_ambiguity_two_traits.nr" "_typ_f019_ambiguity" "TYP-043" "F-019 ambiguous trait method exits with diagnostic" "PANIC:" }
        "F-020" { Expect-FailCode "tests\err\err_typ020_let_variant_destructure.nr" "_typ_f020_let_variant" "enum or path pattern in" "F-020 variant let-pattern gets clean unsupported diagnostic" "NR020" }
        "F-021" { Expect-FailCode "tests\err\err_typ021_struct_unknown_method_diag.nr" "_typ_f021_struct_method" "receiver type" "F-021 struct unknown method reports actual receiver" "Vec<T>" }
        "positive" {
            Expect-FailCode "tests\err\err_int_var_in_float_let.nr" "_typ_num020_int_var_to_f64" "NUM-020" "existing int expression to f64 rejection preserved"
            Expect-BuildRun "tests\features\generic_struct.nr" "_typ_generic_struct_positive" "30"
            Expect-BuildRun "tests\features\generic_enum.nr" "_typ_generic_enum_positive" "42"
            Expect-BuildRun "tests\features\trait_basic.nr" "_typ_trait_basic_positive" "30"
            Expect-BuildRun "tests\features\trait_default.nr" "_typ_trait_default_positive" "21"
        }
    }
}

if ($Finding -eq "all") {
    @("F-001","F-002","F-003","F-004","F-005","F-006","F-007","F-008","F-009","F-010","F-011","F-012","F-013","F-014","F-015","F-016","F-018","F-019","F-020","F-021","positive") | ForEach-Object { Invoke-Finding $_ }
} else {
    Invoke-Finding $Finding
}

Pass "type system audit slice complete"
