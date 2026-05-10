param(
    [ValidateSet(
        "F-001","F-002","F-003","F-004","F-005","F-006","F-007","F-008","F-009","F-010",
        "F-011","F-012","F-013","F-014","F-016","F-017","F-018","F-019","F-020","F-021",
        "F-022","F-023","F-024","F-025","F-026","F-027","F-028","F-029","F-030","F-031",
        "F-032","F-033","F-035","F-036","F-037","F-038","F-039","F-041","F-046","F-047",
        "F-048","F-050","F-051","F-053","F-054","F-056","F-057","F-058","F-060","F-063",
        "F-075","F-076","F-078","all"
    )]
    [string]$Finding = "all"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Invoke-Negative {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName,
        [Parameter(Mandatory = $true)][string]$Diagnostic
    )

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & "bin\nucleor.exe" build $Source -o $OutName --no-cache 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $old
    $text = ($out | Out-String)

    if ($rc -eq 0) {
        $out | ForEach-Object { Write-Output $_ }
        throw "negative build unexpectedly succeeded for $Source"
    }
    if ($text -notmatch [regex]::Escape($Diagnostic)) {
        $out | ForEach-Object { Write-Output $_ }
        throw "negative build for $Source did not contain expected diagnostic: $Diagnostic"
    }
}

function Invoke-Capture {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName,
        [switch]$NoLink
    )

    $args = @("build", $Source, "-o", $OutName, "--no-cache")
    if ($NoLink) {
        $args += "--no-link"
    }

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & "bin\nucleor.exe" @args 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $old
    return @{ ExitCode = $rc; Output = ($out | Out-String) }
}

function Invoke-PositiveNoLink {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName
    )

    $r = Invoke-Capture -Source $Source -OutName $OutName -NoLink
    if ($r.ExitCode -ne 0) {
        Write-Output $r.Output
        throw "positive no-link build failed for $Source"
    }
}

function Invoke-BuildContains {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName,
        [Parameter(Mandatory = $true)][string]$Needle,
        [int]$ExpectedExitCode = 0,
        [switch]$NoLink
    )

    $r = Invoke-Capture -Source $Source -OutName $OutName -NoLink:$NoLink
    if ($r.ExitCode -ne $ExpectedExitCode) {
        Write-Output $r.Output
        throw "build for $Source exited $($r.ExitCode), expected $ExpectedExitCode"
    }
    if ($r.Output -notmatch [regex]::Escape($Needle)) {
        Write-Output $r.Output
        throw "build for $Source did not contain expected text: $Needle"
    }
}

function New-GeneratedBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [byte[]]$Bytes
    )

    $dir = Join-Path $RepoRoot "target\audit_generated\lexer_parser"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $path = Join-Path $dir $Name
    [System.IO.File]::WriteAllBytes($path, $Bytes)
    return $path
}

function New-Utf8Bytes {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    return New-GeneratedBytes -Name $Name -Bytes ([System.Text.Encoding]::UTF8.GetBytes($Text))
}

function Test-StaticFinding {
    param([string]$Id)

    $cases = @{
        "F-001" = @("tests\err\lex_f001_expr_in_type_position.nr", "PARSE-TYPE-001")
        "F-002" = @("tests\err\parse_f002_depth_limit.nr", "PARSE-DEPTH-001")
        "F-003" = @("tests\err\lex_f003_top_level_garbage.nr", "LEX-001")
        "F-004" = @("tests\err\lex_f004_tilde.nr", "LEX-001")
        "F-005" = @("tests\err\lex_f005_dollar.nr", "LEX-001")
        "F-006" = @("tests\err\lex_f006_backslash.nr", "LEX-001")
        "F-012" = @("tests\err\parse_f012_adjacent_tokens.nr", "PARSE-LET-SEMI")
        "F-013" = @("tests\err\parse_f013_missing_let_semicolon.nr", "PARSE-LET-SEMI")
        "F-014" = @("tests\err\parse_f014_extra_close_brace.nr", "PARSE-TOP-001")
        "F-016" = @("tests\err\lex_f016_hex_no_digit.nr", "LEX-NUM-003")
        "F-017" = @("tests\err\lex_f017_hex_underscore_only.nr", "LEX-NUM-001")
        "F-018" = @("tests\err\lex_f018_trailing_underscore.nr", "LEX-NUM-004")
        "F-019" = @("tests\err\lex_f019_double_underscore.nr", "LEX-NUM-002")
        "F-020" = @("tests\err\lex_f020_leading_zero.nr", "LEX-NUM-005")
        "F-021" = @("tests\err\lex_f021_hex_overflow.nr", "NUM-021")
        "F-022" = @("tests\err\lex_f022_unknown_int_suffix.nr", "LEX-NUM-SUFFIX")
        "F-023" = @("tests\err\lex_f023_bad_int_suffix.nr", "LEX-NUM-SUFFIX")
        "F-024" = @("tests\err\lex_f024_invalid_hex_digit.nr", "LEX-NUM-003")
        "F-025" = @("tests\err\lex_f025_empty_char.nr", "LEX-CHAR-EMPTY")
        "F-026" = @("tests\err\lex_f026_multi_char.nr", "LEX-CHAR-MULTI")
        "F-028" = @("tests\err\lex_f028_huge_float.nr", "LEX-NUM-FLOAT-OVERFLOW")
        "F-030" = @("tests\err\parse_f030_back_to_back_str.nr", "PARSE-LET-SEMI")
        "F-031" = @("tests\err\parse_f031_lone_semi.nr", "PARSE-TOP-001")
        "F-036" = @("tests\err\parse_f036_match_no_comma.nr", "PARSE-MATCH-COMMA")
        "F-037" = @("tests\err\parse_f037_args_extra_comma.nr", "PARSE-ARGS-COMMA")
        "F-046" = @("tests\err\lex_f046_cr_only.nr", "LEX-CR-ONLY")
        "F-048" = @("tests\err\parse_f048_bare_type_colon.nr", "PARSE-TYPE-001")
        "F-050" = @("tests\err\parse_f050_unquoted_import.nr", "PARSE-TOP-001")
        "F-051" = @("tests\err\parse_f051_empty_import.nr", "PARSE-IMPORT-EMPTY")
        "F-053" = @("tests\err\parse_f053_closure_no_body.nr", "PARSE-CLOSURE-NO-BODY")
        "F-054" = @("tests\err\parse_f054_keyword_as_binding.nr", "PARSE-LET-001")
    }

    $case = $cases[$Id]
    Invoke-Negative -Source $case[0] -OutName ("_audit_" + $Id.ToLower().Replace("-", "_")) -Diagnostic $case[1]
}

function Test-GeneratedFinding {
    param([string]$Id)

    if ($Id -eq "F-007") {
        $bytes = [byte[]](0xEF,0xBB,0xBF) + [System.Text.Encoding]::UTF8.GetBytes("fn main() -> i32 { return 0; }")
        $src = New-GeneratedBytes -Name "lex_f007_bom.nr" -Bytes $bytes
        Invoke-Negative -Source $src -OutName "_audit_f_007" -Diagnostic "LEX-001"
        return
    }
    if ($Id -eq "F-008") {
        $smart = [string][char]0x201C
        $src = New-Utf8Bytes -Name "lex_f008_smart_quote.nr" -Text ('fn main() -> i32 { let s: str = ' + $smart + 'x' + $smart + '; return 0; }')
        Invoke-Negative -Source $src -OutName "_audit_f_008" -Diagnostic "LEX-001"
        return
    }
    if ($Id -eq "F-009") {
        $zwsp = [string][char]0x200B
        $src = New-Utf8Bytes -Name "lex_f009_zero_width.nr" -Text ("fn main() -> i32 { let" + $zwsp + " x: i64 = 1; return 0; }")
        Invoke-Negative -Source $src -OutName "_audit_f_009" -Diagnostic "LEX-001"
        return
    }
    if ($Id -eq "F-010") {
        $src = New-Utf8Bytes -Name "lex_f010_non_ascii_ident.nr" -Text ('fn main() -> i32 { let caf' + ([string][char]0x00E9) + ': i64 = 1; return 0; }')
        Invoke-Negative -Source $src -OutName "_audit_f_010" -Diagnostic "LEX-001"
        return
    }
    if ($Id -eq "F-011") {
        $prefix = [System.Text.Encoding]::UTF8.GetBytes("fn main() -> i32 { let x: i64 = 1; ")
        $suffix = [System.Text.Encoding]::UTF8.GetBytes("return 0; }")
        $bytes = $prefix + [byte[]](0x00) + $suffix
        $src = New-GeneratedBytes -Name "lex_f011_nul_mid_source.nr" -Bytes $bytes
        Invoke-Negative -Source $src -OutName "_audit_f_011" -Diagnostic "LEX-002"
        return
    }
    if ($Id -eq "F-027") {
        $apos = [char]39
        $src = New-Utf8Bytes -Name "lex_f027_three_apostrophes.nr" -Text ("fn main() -> i32 { let c: i64 = " + $apos + $apos + $apos + "; return 0; }")
        Invoke-Negative -Source $src -OutName "_audit_f_027" -Diagnostic "LEX-CHAR-EMPTY"
        return
    }
    if ($Id -eq "F-029") {
        $src = New-Utf8Bytes -Name "lex_f029_multiline_string.nr" -Text ('fn main() -> i32 { let s: str = "hello' + "`n" + 'world"; return 0; }')
        Invoke-Negative -Source $src -OutName "_audit_f_029" -Diagnostic "LEX-STRING-NEWLINE"
        return
    }
    if ($Id -eq "F-032") {
        $src = New-Utf8Bytes -Name "lex_f032_leading_dot_float.nr" -Text "fn main() -> i32 { let x: f64 = .5; return 0; }"
        Invoke-Negative -Source $src -OutName "_audit_f_032" -Diagnostic "LEX-NUM-FLOAT-FORM"
        return
    }
    if ($Id -eq "F-033") {
        $src = New-Utf8Bytes -Name "lex_f033_trailing_dot_float.nr" -Text "fn main() -> i32 { let x: f64 = 1.; return 0; }"
        Invoke-Negative -Source $src -OutName "_audit_f_033" -Diagnostic "LEX-NUM-FLOAT-FORM"
        return
    }
    if ($Id -eq "F-035") {
        $src = New-Utf8Bytes -Name "parse_f035_many_plus.nr" -Text "fn main() -> i32 { let x: i64 = 1 + + + + + 2; return 0; }"
        Invoke-Negative -Source $src -OutName "_audit_f_035" -Diagnostic "PARSE-UNARY-PLUS"
        return
    }
    if ($Id -eq "F-038") {
        $src = New-Utf8Bytes -Name "parse_f038_empty_struct_enum.nr" -Text "struct Empty { } enum VoidLike { } fn main() -> i32 { return 0; }"
        Invoke-PositiveNoLink -Source $src -OutName "_audit_f_038"
        $doc = Get-Content -LiteralPath (Join-Path $RepoRoot "docs\language-reference.md") -Raw
        if ($doc -notmatch "Functions may omit" -or $doc -notmatch "Line comments are supported") {
            throw "language reference missing audit doc-drift clarifications"
        }
        return
    }
    if ($Id -eq "F-039") {
        $src = New-Utf8Bytes -Name "parse_f039_empty_range_warning.nr" -Text "fn main() -> i32 { for i in 5..1 { } return 0; }"
        Invoke-BuildContains -Source $src -OutName "_audit_f_039" -Needle "warning[RANGE-001]" -NoLink
        return
    }
    if ($Id -eq "F-041" -or $Id -eq "F-075") {
        $src = New-Utf8Bytes -Name "parse_f041_omitted_return_unit.nr" -Text "fn helper() { } fn main() -> i32 { return 0; }"
        Invoke-PositiveNoLink -Source $src -OutName ("_audit_" + $Id.ToLower().Replace("-", "_"))
        $doc = Get-Content -LiteralPath (Join-Path $RepoRoot "docs\language-reference.md") -Raw
        if ($doc -notmatch 'Functions may omit `-> ReturnType`') {
            throw "language reference does not document omitted return type semantics"
        }
        return
    }
    if ($Id -eq "F-047") {
        $src = New-Utf8Bytes -Name "lex_f047_crlf_in_string.nr" -Text ('fn main() -> i32 { let s: str = "a' + "`r`n" + 'b"; return 0; }')
        Invoke-Negative -Source $src -OutName "_audit_f_047" -Diagnostic "LEX-STRING-NEWLINE"
        return
    }
    if ($Id -eq "F-056") {
        $src1 = New-Utf8Bytes -Name "parse_f056_paren_negative.nr" -Text "fn main() -> i32 { let x: i64 = (-5); return 0; }"
        $src2 = New-Utf8Bytes -Name "parse_f056_double_negative.nr" -Text "fn main() -> i32 { let x: i64 = - - 5; return 0; }"
        Invoke-PositiveNoLink -Source $src1 -OutName "_audit_f_056_a"
        Invoke-PositiveNoLink -Source $src2 -OutName "_audit_f_056_b"
        return
    }
    if ($Id -eq "F-057") {
        $src = New-Utf8Bytes -Name "parse_f057_local_import.nr" -Text 'fn main() -> i32 { import "x.nr"; return 0; }'
        Invoke-Negative -Source $src -OutName "_audit_f_057" -Diagnostic "PARSE-IMPORT-LOCAL"
        return
    }
    if ($Id -eq "F-058") {
        $lineDoc = New-Utf8Bytes -Name "parse_f058_line_doc.nr" -Text ("/// doc`nfn main() -> i32 { return 0; }")
        $blockDoc = New-Utf8Bytes -Name "parse_f058_block_doc.nr" -Text ("/** doc */`nfn main() -> i32 { return 0; }")
        Invoke-PositiveNoLink -Source $lineDoc -OutName "_audit_f_058_line"
        Invoke-Negative -Source $blockDoc -OutName "_audit_f_058_block" -Diagnostic "NR020"
        return
    }
    if ($Id -eq "F-060") {
        $src = New-Utf8Bytes -Name "lex_f060_trailing_escape_eof.nr" -Text 'fn main() -> i32 { let s: str = "abc\'
        Invoke-Negative -Source $src -OutName "_audit_f_060" -Diagnostic "LEX-STRING-EOF"
        return
    }
    if ($Id -eq "F-063") {
        $empty = New-GeneratedBytes -Name "parse_f063_empty.nr" -Bytes ([byte[]]@())
        $comment = New-Utf8Bytes -Name "parse_f063_comment_only.nr" -Text "// comment only"
        Invoke-Negative -Source $empty -OutName "_audit_f_063_empty" -Diagnostic "NR022"
        Invoke-Negative -Source $comment -OutName "_audit_f_063_comment" -Diagnostic "NR022"
        return
    }
    if ($Id -eq "F-076") {
        $src = New-Utf8Bytes -Name "lex_f076_unknown_suffix.nr" -Text "fn main() -> i32 { let x: i64 = 1z42; return 0; }"
        Invoke-Negative -Source $src -OutName "_audit_f_076" -Diagnostic "LEX-NUM-SUFFIX"
        return
    }
    if ($Id -eq "F-078") {
        $src = New-Utf8Bytes -Name "parse_f078_missing_separators.nr" -Text "fn main() -> i32 { 1 2 3 return 0; }"
        Invoke-Negative -Source $src -OutName "_audit_f_078" -Diagnostic "PARSE-STMT-SEMI"
        return
    }

    throw "no generated case registered for $Id"
}

function Test-Finding {
    param([string]$Id)

    if (@("F-007","F-008","F-009","F-010","F-011","F-027","F-029","F-032","F-033","F-035","F-038","F-039","F-041","F-047","F-056","F-057","F-058","F-060","F-063","F-075","F-076","F-078") -contains $Id) {
        Test-GeneratedFinding $Id
    } else {
        Test-StaticFinding $Id
    }
    Write-Output "PASS ${Id}: lexer/parser audit invariant holds"
}

$allFindings = @(
    "F-001","F-002","F-003","F-004","F-005","F-006","F-007","F-008","F-009","F-010",
    "F-011","F-012","F-013","F-014","F-016","F-017","F-018","F-019","F-020","F-021",
    "F-022","F-023","F-024","F-025","F-026","F-027","F-028","F-029","F-030","F-031",
    "F-032","F-033","F-035","F-036","F-037","F-038","F-039","F-041","F-046","F-047",
    "F-048","F-050","F-051","F-053","F-054","F-056","F-057","F-058","F-060","F-063",
    "F-075","F-076","F-078"
)

if ($Finding -eq "all") {
    foreach ($id in $allFindings) { Test-Finding $id }
} else {
    Test-Finding $Finding
}
