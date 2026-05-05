# bootstrap_windows.ps1 -- recover bin\nucleor.exe from the committed IR seed.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Run,
    [switch]$Force,
    [switch]$Verify,
    [string]$ClangPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

function Quote-CommandArg {
    param([string]$Value)
    if ($Value -match '^[A-Za-z0-9_./:\\,=-]+$') {
        return $Value
    }
    return "'" + ($Value -replace "'", "''") + "'"
}

function Format-CommandLine {
    param(
        [string]$Exe,
        [string[]]$CommandArgs
    )
    $parts = @((Quote-CommandArg $Exe))
    foreach ($arg in $CommandArgs) {
        $parts += (Quote-CommandArg $arg)
    }
    return ($parts -join " ")
}

function Test-ClangCandidate {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (Test-Path -LiteralPath $expanded -PathType Leaf) {
        return (Resolve-Path -LiteralPath $expanded).Path
    }
    return $null
}

function Resolve-Clang {
    param([string]$ExplicitPath)

    $checked = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $checked.Add($ExplicitPath)
        $resolved = Test-ClangCandidate $ExplicitPath
        if ($resolved) {
            return $resolved
        }
        Fail "bootstrap_windows: -ClangPath was provided but does not point to a file: $ExplicitPath"
    }

    if (-not [string]::IsNullOrWhiteSpace($env:NUCLEOR_CLANG_PATH)) {
        $checked.Add($env:NUCLEOR_CLANG_PATH)
        $resolved = Test-ClangCandidate $env:NUCLEOR_CLANG_PATH
        if ($resolved) {
            return $resolved
        }
    }

    foreach ($name in @("clang.exe", "clang")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.CommandType -eq "Application") {
            $checked.Add($cmd.Source)
            return $cmd.Source
        }
        $checked.Add("PATH:$name")
    }

    foreach ($prefix in @($env:LLVM_SYS_180_PREFIX, $env:LLVM_HOME, $env:LLVM_DIR)) {
        if (-not [string]::IsNullOrWhiteSpace($prefix)) {
            $candidate = Join-Path $prefix "bin\clang.exe"
            $checked.Add($candidate)
            $resolved = Test-ClangCandidate $candidate
            if ($resolved) {
                return $resolved
            }
        }
    }

    foreach ($candidate in @(
        "C:\Program Files\LLVM\bin\clang.exe",
        "C:\Program Files (x86)\LLVM\bin\clang.exe",
        "C:\msys64\mingw64\bin\clang.exe"
    )) {
        $checked.Add($candidate)
        $resolved = Test-ClangCandidate $candidate
        if ($resolved) {
            return $resolved
        }
    }

    Fail ("bootstrap_windows: clang.exe was not found. Checked: " + ($checked -join "; ") + ". Install LLVM for Windows, set NUCLEOR_CLANG_PATH, or pass -ClangPath <path>.")
}

if ($DryRun -and $Run) {
    Fail "bootstrap_windows: choose either -DryRun or -Run, not both."
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$seed = Join-Path $repoRoot "bootstrap\nucleor_s1_seed.ll"
$runtime = Join-Path $repoRoot "stdlib\runtime\nucleor_llvm_rt.c"
$output = Join-Path $repoRoot "bin\nucleor.exe"
$checkScript = Join-Path $repoRoot "tools\check_self_host_md5.sh"

if (-not (Test-Path -LiteralPath $seed -PathType Leaf)) {
    Fail "bootstrap_windows: missing committed seed: $seed"
}
if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) {
    Fail "bootstrap_windows: missing runtime source: $runtime"
}

$clang = Resolve-Clang $ClangPath
$clangArgs = @(
    "-fuse-ld=lld",
    $seed,
    $runtime,
    "-o",
    $output,
    "-Wl,/STACK:16777216"
)

$commandLine = Format-CommandLine -Exe $clang -CommandArgs $clangArgs

if (-not $Run) {
    Write-Output "bootstrap_windows: dry run"
    Write-Output "repo: $repoRoot"
    Write-Output "clang: $clang"
    Write-Output "command: $commandLine"
    if ($Verify) {
        Write-Output "verify command: bash tools/check_self_host_md5.sh"
    }
    exit 0
}

if ((Test-Path -LiteralPath $output -PathType Leaf) -and -not $Force) {
    Fail "bootstrap_windows: refusing to overwrite $output. Re-run with -Force after reviewing the dry run."
}

$outputDir = Split-Path -Parent $output
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

if ($Verify) {
    $bash = Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $bash) {
        Fail "bootstrap_windows: -Verify requires bash for tools/check_self_host_md5.sh; install Git Bash/MSYS2 bash or rerun without -Verify."
    }
    if (-not (Test-Path -LiteralPath $checkScript -PathType Leaf)) {
        Fail "bootstrap_windows: missing fixed-point checker: $checkScript"
    }
}

Push-Location $repoRoot
try {
    Write-Output "bootstrap_windows: running $commandLine"
    & $clang @clangArgs
    if ($LASTEXITCODE -ne 0) {
        Fail "bootstrap_windows: clang failed with exit code $LASTEXITCODE"
    }

    if ($Verify) {
        Write-Output "bootstrap_windows: running fixed-point check"
        & $bash.Source "tools/check_self_host_md5.sh"
        if ($LASTEXITCODE -ne 0) {
            Fail "bootstrap_windows: fixed-point check failed with exit code $LASTEXITCODE"
        }
    }

    Write-Output "bootstrap_windows: complete"
}
finally {
    Pop-Location
}
