param(
    [ValidateSet("C-004", "all")]
    [string]$Finding = "all"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [int[]]$ExpectedExitCodes = @(0)
    )

    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $FilePath @Arguments 2>&1
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $old

    if ($ExpectedExitCodes -notcontains $rc) {
        $output | ForEach-Object { Write-Output $_ }
        throw "$FilePath $($Arguments -join ' ') exited $rc; expected one of $($ExpectedExitCodes -join ', ')"
    }

    [pscustomobject]@{
        ExitCode = $rc
        Output = $output
    }
}

function Assert-NoConstBitwiseIR {
    param([Parameter(Mandatory = $true)][string]$LlPath)

    if (-not (Test-Path -LiteralPath $LlPath)) {
        throw "expected LLVM output not found: $LlPath"
    }

    $hits = Select-String -LiteralPath $LlPath -Pattern '\b(and|or|xor) i64\b'
    if ($hits) {
        $hits | Select-Object -First 20 | ForEach-Object { Write-Output $_.Line }
        throw "C-004 failed: negative constant bitwise expressions were not fully folded"
    }
}

function Test-C004 {
    $name = "audit_lane1_bitwise_fold_neg"
    $src = "tests\lang\$name.nr"
    $ll = "target\$name.ll"
    $exe = "target\$name.exe"

    Remove-Item -LiteralPath $ll, $exe -Force -ErrorAction SilentlyContinue

    Invoke-NativeChecked -FilePath "bin\nucleor.exe" -Arguments @(
        "build", $src, "-o", $name, "--no-cache", "--emit=llvm"
    ) | Out-Null

    Invoke-NativeChecked -FilePath $exe -Arguments @() -ExpectedExitCodes @(42) | Out-Null
    Assert-NoConstBitwiseIR -LlPath $ll

    Write-Output "PASS C-004: negative i64 bitwise constants fold to LLVM-free constants and runtime result is 42"
}

switch ($Finding) {
    "C-004" { Test-C004 }
    "all" { Test-C004 }
}
