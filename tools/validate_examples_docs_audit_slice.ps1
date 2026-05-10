param(
    [ValidateSet("Critical-1","Critical-2","High-1","High-2","High-3","High-4","all")]
    [string]$Finding = "all"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Invoke-Nuc {
    param([string[]]$ArgList)

    $out = & "bin\nucleor.exe" @ArgList 2>&1
    $rc = $LASTEXITCODE
    return [pscustomobject]@{
        Rc = $rc
        Text = ($out | Out-String)
        Lines = @($out)
    }
}

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Label)
    if ($Text -notmatch [regex]::Escape($Needle)) {
        throw "$Label did not contain expected text: $Needle"
    }
}

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Label)
    if ($Text -match [regex]::Escape($Needle)) {
        throw "$Label contained forbidden text: $Needle"
    }
}

function Test-Critical1 {
    foreach ($cmd in @("add","remove","update")) {
        $result = Invoke-Nuc -ArgList @($cmd)
        $text = [string]$result.Text
        Assert-NotContains -Text $text -Needle "Unknown command: $cmd" -Label "nuc $cmd"
        if ($text.IndexOf("Usage: nuc install") -lt 0 -and $text.IndexOf("ERROR:") -lt 0) {
            throw "nuc $cmd did not route to the install/package-management path; output=$text"
        }
    }
}

function Test-Critical2 {
    $codes = @(
        "OWN-G4-USE-AFTER-DROP",
        "OWN-G8-COND-MOVE",
        "INIT-G11-READ-BEFORE-INIT",
        "BORROW-G2-LIFETIME",
        "ALIAS-G3-VEC-OF-REFS",
        "ALIAS-G3-HASHMAP-REHASH",
        "SEND-G6-HASHMAP",
        "SEND-G6-CLOSURE-CAPTURE",
        "SEND-G6-TUPLE",
        "SEND-G6-ENUM",
        "FFI-G5-NULL-DEREF",
        "FFI-G9-MISSING-ALLOW-DIRECT-FFI",
        "UNSAFE-G7-MISSING-ALLOW",
        "EFFECT-G10-UNDECLARED",
        "EFFECT-G10-MISSING-ALLOW",
        "EFFECT-G10-WRONG-ROW",
        "PARSE-LET-SEMI"
    )

    foreach ($code in $codes) {
        $result = Invoke-Nuc -ArgList @("explain", $code)
        if ($result.Rc -ne 0) {
            throw "nuc explain $code failed with rc=$($result.Rc)"
        }
        Assert-NotContains -Text $result.Text -Needle "unknown error code" -Label "nuc explain $code"
        Assert-Contains -Text $result.Text -Needle $code -Label "nuc explain $code"
    }
}

function Test-High1 {
    $doc = Get-Content -Raw -LiteralPath "docs\language-reference.md"
    Assert-Contains -Text $doc -Needle "# Nucleor Language Reference (v1.0)" -Label "language-reference header"
    Assert-NotContains -Text $doc -Needle "0.2.0-v2" -Label "language-reference stale version"
    Assert-Contains -Text $doc -Needle "RFC-0062" -Label "language-reference RFC-0062 coverage"
    Assert-Contains -Text $doc -Needle "OWN-G4-USE-AFTER-DROP" -Label "language-reference G-series coverage"
    Assert-Contains -Text $doc -Needle 'rejected with `LEX-001`' -Label "language-reference BOM policy"
    Assert-NotContains -Text $doc -Needle 'byte-order-mark (`EF BB BF`) at the start of a file is silently consumed' -Label "language-reference stale BOM policy"
}

function Test-High2 {
    $doc = Get-Content -Raw -LiteralPath "examples\README.md"
    Assert-Contains -Text $doc -Needle "target/hello.exe" -Label "examples README Windows hello path"
    Assert-Contains -Text $doc -Needle "./target/hello" -Label "examples README POSIX hello path"
    Assert-Contains -Text $doc -Needle "target/my_demo.exe" -Label "examples README Windows demo path"
    Assert-Contains -Text $doc -Needle "./target/my_demo" -Label "examples README POSIX demo path"
    Assert-NotContains -Text $doc -Needle "./hello.exe" -Label "examples README stale root hello path"
    Assert-NotContains -Text $doc -Needle "./my_demo.exe" -Label "examples README stale root demo path"
}

function Test-High3 {
    $unknown = Invoke-Nuc -ArgList @("build", "examples\01_hello.nr", "-o", "_flag_probe_unknown", "--bogus-flag-xyz", "--no-cache", "--no-link")
    if ($unknown.Rc -eq 0) {
        throw "unknown build flag unexpectedly succeeded"
    }
    Assert-Contains -Text $unknown.Text -Needle "ERROR: unknown flag: --bogus-flag-xyz" -Label "unknown flag diagnostic"

    $release = Invoke-Nuc -ArgList @("build", "examples\01_hello.nr", "-o", "_flag_probe_release", "--release", "--no-cache", "--no-link")
    if ($release.Rc -ne 0) {
        throw "--release build probe failed with rc=$($release.Rc)"
    }

    $tier2 = Invoke-Nuc -ArgList @("build", "examples\01_hello.nr", "-o", "_flag_probe_tier2", "--tier", "2", "--no-cache", "--no-link")
    if ($tier2.Rc -ne 0) {
        throw "--tier 2 build probe failed with rc=$($tier2.Rc)"
    }

    $tierBad = Invoke-Nuc -ArgList @("build", "examples\01_hello.nr", "-o", "_flag_probe_tierbad", "--tier", "9", "--no-cache", "--no-link")
    if ($tierBad.Rc -eq 0) {
        throw "--tier 9 unexpectedly succeeded"
    }
    Assert-Contains -Text $tierBad.Text -Needle "ERROR: unsupported --tier value: 9" -Label "bad tier diagnostic"

    $source = Get-Content -Raw -LiteralPath "compiler\nucleor_s1_compiler.nr"
    Assert-Contains -Text $source -Needle 'env_set("NUCLEOR_LLVM_OPT", "-O3")' -Label "s1 release/tier optimizer wiring"
    Assert-Contains -Text $source -Needle "|opt=" -Label "native link cache optimization key"
}

function Test-High4 {
    $doc = Get-Content -Raw -LiteralPath "docs\g1-default-flip-adopter-guide.md"
    Assert-Contains -Text $doc -Needle "auto-drop is the default" -Label "G1 guide v1 status"
    Assert-Contains -Text $doc -Needle "#[manual_drop]" -Label "G1 guide manual drop opt-out"
    Assert-Contains -Text $doc -Needle "NUC_AUTO_DROP_DEFAULT=0" -Label "G1 guide legacy env note"
    Assert-NotContains -Text $doc -Needle "Status: v0.8.39 experiment" -Label "G1 guide stale experiment status"
    Assert-NotContains -Text $doc -Needle "Today (v0.x)" -Label "G1 guide stale v0 wording"
}

$tests = [ordered]@{
    "Critical-1" = { Test-Critical1 }
    "Critical-2" = { Test-Critical2 }
    "High-1" = { Test-High1 }
    "High-2" = { Test-High2 }
    "High-3" = { Test-High3 }
    "High-4" = { Test-High4 }
}

foreach ($name in $tests.Keys) {
    if ($Finding -ne "all" -and $Finding -ne $name) {
        continue
    }
    & $tests[$name]
    Write-Output "PASS $name"
}
