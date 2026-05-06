param(
    [switch]$Doctor,
    [ValidateRange(1, 100000)]
    [int]$Iterations = 100,
    [string]$Fixture = "tests/features/rust_bridge_string_free_smoke.nr",
    [string]$Root = "",
    [string]$OutName = "_rust_bridge_ownership_check",
    [ValidateRange(1, 3600)]
    [int]$BuildTimeoutSec = 180,
    [ValidateRange(1, 3600)]
    [int]$RunTimeoutSec = 30
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)

$bridgeCrate = Join-Path $Root "stdlib\rods\rust_bridge"
$bridgeCargo = Join-Path $bridgeCrate "Cargo.toml"
$bridgeSrc = Join-Path $bridgeCrate "src\lib.rs"
$bridgeReleaseDir = Join-Path $bridgeCrate "target\release"
$fixtureArg = $Fixture.Replace("\", "/")
if ([System.IO.Path]::IsPathRooted($Fixture)) {
    $fixture = [System.IO.Path]::GetFullPath($Fixture)
    $fixtureRel = $fixture
} else {
    $fixtureRel = $fixtureArg
    $fixture = Join-Path $Root $Fixture
}
$targetDir = Join-Path $Root "target"
$compilerCandidates = @(
    (Join-Path $Root "bin\nucleor.exe"),
    (Join-Path $Root "bin\nucleor")
)
$bridgeArtifactCandidates = @(
    (Join-Path $bridgeReleaseDir "nucleor_rust_bridge.lib"),
    (Join-Path $bridgeReleaseDir "libnucleor_rust_bridge.a")
)

function Fail([string]$Message) {
    Write-Host ("ERROR rust_bridge ownership: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Write-Status([string]$Name, [bool]$Ok, [string]$Detail) {
    $state = if ($Ok) { "OK" } else { "FAIL" }
    Write-Host ("doctor {0}: {1} - {2}" -f $Name, $state, $Detail)
}

function Get-CommandPath([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { return "" }
    return [string]$cmd.Source
}

function Get-FirstExistingPath([string[]]$Paths) {
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    return ""
}

function Invoke-CapturedProcess {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [int]$TimeoutSec
    )

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FilePath
    foreach ($arg in $ArgumentList) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        if (-not $proc.WaitForExit($TimeoutSec * 1000)) {
            try { $proc.Kill($true) } catch { try { $proc.Kill() } catch { } }
            return [pscustomobject]@{
                ExitCode = 124
                TimedOut = $true
                Stdout = $stdoutTask.GetAwaiter().GetResult()
                Stderr = $stderrTask.GetAwaiter().GetResult()
            }
        }
        return [pscustomobject]@{
            ExitCode = $proc.ExitCode
            TimedOut = $false
            Stdout = $stdoutTask.GetAwaiter().GetResult()
            Stderr = $stderrTask.GetAwaiter().GetResult()
        }
    } finally {
        $proc.Dispose()
    }
}

function Format-ProcessTail($Result) {
    $lines = @()
    if (-not [string]::IsNullOrWhiteSpace($Result.Stdout)) {
        $lines += "stdout:"
        $lines += (($Result.Stdout -split "`r?`n") | Select-Object -Last 20)
    }
    if (-not [string]::IsNullOrWhiteSpace($Result.Stderr)) {
        $lines += "stderr:"
        $lines += (($Result.Stderr -split "`r?`n") | Select-Object -Last 20)
    }
    return ($lines -join [Environment]::NewLine)
}

function Get-OutputExecutable([string]$Name) {
    $candidates = @(
        (Join-Path $targetDir ($Name + ".exe")),
        (Join-Path $targetDir $Name)
    )
    return Get-FirstExistingPath $candidates
}

function Get-FixtureCycleCount([string]$Path) {
    if ($Path -match "rust_bridge_string_free_repeat_smoke\.nr$") {
        return 700
    }
    return 100
}

function Get-Readiness {
    $cargo = Get-CommandPath "cargo"
    $compiler = Get-FirstExistingPath $compilerCandidates
    $bridgeArtifact = Get-FirstExistingPath $bridgeArtifactCandidates
    $cratePresent = (Test-Path -LiteralPath $bridgeCargo) -and (Test-Path -LiteralPath $bridgeSrc)
    $fixturePresent = Test-Path -LiteralPath $fixture
    $canBuildArtifact = (-not [string]::IsNullOrWhiteSpace($cargo)) -and $cratePresent
    $canBuildFixture = (-not [string]::IsNullOrWhiteSpace($compiler)) -and $fixturePresent -and (($bridgeArtifact -ne "") -or $canBuildArtifact)
    return [pscustomobject]@{
        Cargo = $cargo
        Compiler = $compiler
        BridgeArtifact = $bridgeArtifact
        BridgeCratePresent = $cratePresent
        FixturePresent = $fixturePresent
        CanBuildArtifact = $canBuildArtifact
        CanBuildFixture = $canBuildFixture
    }
}

function Run-Doctor {
    $r = Get-Readiness
    $failed = $false

    Write-Status "cargo" ($r.Cargo -ne "") $(if ($r.Cargo -ne "") { $r.Cargo } else { "missing from PATH" })
    if ($r.BridgeCratePresent) {
        Write-Status "bridge-crate" $true $bridgeCrate
    } else {
        Write-Status "bridge-crate" $false ("missing Cargo.toml or src/lib.rs under {0}" -f $bridgeCrate)
        $failed = $true
    }

    $expected = $bridgeArtifactCandidates -join "; "
    if ($r.BridgeArtifact -ne "") {
        Write-Status "release-artifact" $true $r.BridgeArtifact
    } elseif ($r.CanBuildArtifact) {
        Write-Status "release-artifact" $true ("not present yet; normal run will attempt cargo build --release; expected {0}" -f $expected)
    } else {
        Write-Status "release-artifact" $false ("missing and cannot be built; expected {0}" -f $expected)
        $failed = $true
    }

    Write-Status "compiler-binary" ($r.Compiler -ne "") $(if ($r.Compiler -ne "") { $r.Compiler } else { "missing bin/nucleor.exe or bin/nucleor" })
    if ($r.Compiler -eq "") { $failed = $true }

    Write-Status "focused-fixture" $r.FixturePresent $(if ($r.FixturePresent) { $fixture } else { "missing $fixture" })
    if (-not $r.FixturePresent) { $failed = $true }

    Write-Status "fixture-buildable" $r.CanBuildFixture $(if ($r.CanBuildFixture) { "prerequisites are sufficient to build $fixtureRel" } else { "missing compiler, fixture, cargo, crate, or bridge artifact" })
    if (-not $r.CanBuildFixture) { $failed = $true }

    if ($failed) {
        Write-Host "doctor result: not ready for rust_bridge ownership harness"
        exit 96
    }
    Write-Host "doctor result: ready for rust_bridge ownership harness"
    exit 0
}

if ($Doctor) {
    Run-Doctor
}

if ($Iterations -lt 1) {
    Write-Host "ERROR rust_bridge ownership: Iterations must be > 0" -ForegroundColor Red
    exit 2
}

$readiness = Get-Readiness
if ($readiness.Cargo -eq "") {
    Fail "cargo is missing from PATH; cannot build rust_bridge release artifact"
}
if (-not $readiness.BridgeCratePresent) {
    Fail "rust_bridge crate is missing Cargo.toml or src/lib.rs under $bridgeCrate"
}
if ($readiness.Compiler -eq "") {
    Fail "compiler binary missing: expected bin/nucleor.exe or bin/nucleor"
}
if (-not $readiness.FixturePresent) {
    Fail "focused fixture missing: $fixture"
}

$bridgeArtifact = $readiness.BridgeArtifact
if ($bridgeArtifact -eq "") {
    Write-Host "rust_bridge artifact missing; running cargo build --release"
    $cargoResult = Invoke-CapturedProcess -FilePath $readiness.Cargo -ArgumentList @("build", "--release") -WorkingDirectory $bridgeCrate -TimeoutSec $BuildTimeoutSec
    if ($cargoResult.TimedOut -or $cargoResult.ExitCode -ne 0) {
        Fail ("cargo build --release failed with exit {0}`n{1}" -f $cargoResult.ExitCode, (Format-ProcessTail $cargoResult))
    }
    $bridgeArtifact = Get-FirstExistingPath $bridgeArtifactCandidates
    if ($bridgeArtifact -eq "") {
        Fail ("cargo build --release completed but no bridge artifact was found. Expected: {0}" -f ($bridgeArtifactCandidates -join "; "))
    }
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
$oldExe = Get-OutputExecutable $OutName
if ($oldExe -ne "") {
    Remove-Item -LiteralPath $oldExe -Force -ErrorAction SilentlyContinue
}

Write-Host ("building focused fixture: {0}" -f $fixtureRel)
$buildResult = Invoke-CapturedProcess -FilePath $readiness.Compiler -ArgumentList @("build", $fixtureArg, "-o", $OutName, "--no-cache") -WorkingDirectory $Root -TimeoutSec $BuildTimeoutSec
if ($buildResult.TimedOut -or $buildResult.ExitCode -ne 0) {
    Fail ("fixture build failed with exit {0}`n{1}" -f $buildResult.ExitCode, (Format-ProcessTail $buildResult))
}

$exe = Get-OutputExecutable $OutName
if ($exe -eq "") {
    Fail ("fixture build reported success but executable was not found under target for output {0}" -f $OutName)
}

$fixtureCycles = Get-FixtureCycleCount $fixtureArg
for ($i = 1; $i -le $Iterations; $i++) {
    $runResult = Invoke-CapturedProcess -FilePath $exe -ArgumentList @() -WorkingDirectory $Root -TimeoutSec $RunTimeoutSec
    if ($runResult.TimedOut -or $runResult.ExitCode -ne 0) {
        Fail ("ownership fixture iteration {0}/{1} failed with exit {2}`n{3}" -f $i, $Iterations, $runResult.ExitCode, (Format-ProcessTail $runResult))
    }
}

Write-Host ("OK rust_bridge ownership: iterations={0} fixture_alloc_free_cycles={1} bridge_artifact={2} executable={3}" -f $Iterations, ($Iterations * $fixtureCycles), $bridgeArtifact, $exe)
exit 0
