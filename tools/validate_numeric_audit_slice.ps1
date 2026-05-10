param(
    [ValidateSet("F-NUM-001","F-NUM-002","F-NUM-003","F-NUM-004","all")]
    [string]$Finding = "all",
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"

if ($Root -eq "") {
    $scriptDir = $PSScriptRoot
    if ($scriptDir -eq "") {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $Root = (Resolve-Path (Join-Path $scriptDir "..")).Path
}

function Invoke-Build {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName
    )

    Push-Location $Root
    try {
        $old = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $out = & (Join-Path $Root "bin\nucleor.exe") build $Source -o $OutName --no-cache 2>&1
        $rc = $LASTEXITCODE
        $ErrorActionPreference = $old
        if ($rc -ne 0) {
            $out | ForEach-Object { Write-Output $_ }
            throw "build failed for $Source rc=$rc"
        }
    } finally {
        Pop-Location
    }
}

function Invoke-Target {
    param(
        [Parameter(Mandatory = $true)][string]$OutName,
        [int]$ExpectedExitCode = 0,
        [string]$ExpectedText = ""
    )

    $exe = Join-Path $Root ("target\" + $OutName + ".exe")
    if (-not (Test-Path -LiteralPath $exe)) {
        $exe = Join-Path $Root ("target\" + $OutName)
    }
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "target executable not found for $OutName"
    }

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $exe 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $old
    $text = ($out | Out-String)

    if ($rc -ne $ExpectedExitCode) {
        $out | ForEach-Object { Write-Output $_ }
        throw "target $OutName exited $rc; expected $ExpectedExitCode"
    }
    if ($ExpectedText -ne "" -and $text -notmatch [regex]::Escape($ExpectedText)) {
        $out | ForEach-Object { Write-Output $_ }
        throw "target $OutName did not contain expected text: $ExpectedText"
    }
}

function Invoke-Positive {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName
    )

    Invoke-Build -Source $Source -OutName $OutName
    Invoke-Target -OutName $OutName
}

function Invoke-NegativeBuild {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName,
        [Parameter(Mandatory = $true)][string]$Diagnostic
    )

    Push-Location $Root
    try {
        $old = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $out = & (Join-Path $Root "bin\nucleor.exe") build $Source -o $OutName --no-cache 2>&1
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
    } finally {
        Pop-Location
    }
}

function Invoke-RuntimePanic {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$OutName,
        [Parameter(Mandatory = $true)][string]$Diagnostic
    )

    Invoke-Build -Source $Source -OutName $OutName
    Invoke-Target -OutName $OutName -ExpectedExitCode 1 -ExpectedText $Diagnostic
}

function Assert-SourceContains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Needles
    )

    $text = Get-Content -LiteralPath (Join-Path $Root $Path) -Raw
    foreach ($needle in $Needles) {
        if ($text -notmatch [regex]::Escape($needle)) {
            throw "$Path missing required marker: $needle"
        }
    }
}

function Test-Finding {
    param([string]$Id)

    if ($Id -eq "F-NUM-001") {
        Assert-SourceContains "stdlib\runtime\nucleor_llvm_rt.c" @(
            "__nucleor_f64_to_i8",
            "__nucleor_f64_to_u8",
            "__nucleor_f64_to_i16",
            "__nucleor_f64_to_u16",
            "__nucleor_f32_to_i8",
            "__nucleor_f32_to_u8",
            "__nucleor_f32_to_i16",
            "__nucleor_f32_to_u16"
        )
        Invoke-Positive "tests\lang\audit_lane1_f_to_narrow.nr" "_audit_f_num_001"
    } elseif ($Id -eq "F-NUM-002") {
        Assert-SourceContains "stdlib\runtime\units_rt.c" @("UNIT-DIM-001", "UNIT-DIM-002", "unit_category")
        Invoke-Positive "tests\rods\lane6_units_legit.nr" "_audit_f_num_002_positive"
        Invoke-RuntimePanic "tests\rods\lane8_units_cross_dim_panic.nr" "_audit_f_num_002_cross_dim" "UNIT-DIM-001"
        Invoke-RuntimePanic "tests\rods\lane8_units_unknown_id_panic.nr" "_audit_f_num_002_unknown_id" "UNIT-DIM-002"
    } elseif ($Id -eq "F-NUM-003") {
        Assert-SourceContains "stdlib\rods\bitwise_rt.c" @("BIT-001", "nuc_bit_shift_count_ok", "(unsigned long long)a << n")
        Invoke-Positive "tests\rods\lane6_bitwise_legit.nr" "_audit_f_num_003_positive"
        Invoke-RuntimePanic "tests\rods\lane8_bitwise_shift_oob_panic.nr" "_audit_f_num_003_shift_oob" "BIT-001"
        Invoke-RuntimePanic "tests\rods\lane8_bitwise_bitpos_oob_panic.nr" "_audit_f_num_003_bitpos_oob" "BIT-001"
    } elseif ($Id -eq "F-NUM-004") {
        Assert-SourceContains "compiler\nucleor_s1_compiler.nr" @("F-NUM-004", "NUM-001", "mixed-width integer arithmetic")
        Invoke-Positive "tests\lang\audit_lane8_mixed_width_explicit_cast.nr" "_audit_f_num_004_positive"
        Invoke-NegativeBuild "tests\err\err_num004_i32_u32_arith.nr" "_audit_f_num_004_i32_u32" "NUM-001"
        Invoke-NegativeBuild "tests\err\err_num004_i32_i64_arith.nr" "_audit_f_num_004_i32_i64" "NUM-001"
    } else {
        throw "unknown finding $Id"
    }

    Write-Output "PASS ${Id}: numeric audit invariant holds"
}

$all = @("F-NUM-001","F-NUM-002","F-NUM-003","F-NUM-004")

if ($Finding -eq "all") {
    foreach ($id in $all) { Test-Finding $id }
} else {
    Test-Finding $Finding
}
