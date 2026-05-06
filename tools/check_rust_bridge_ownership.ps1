param(
    [switch]$Doctor,
    [ValidateRange(1, 100000)]
    [int]$Iterations = 100,
    [string]$Fixture = "string-free",
    [string]$Root = "",
    [string]$OutName = "_rust_bridge_ownership_check",
    [ValidateRange(1, 3600)]
    [int]$BuildTimeoutSec = 180,
    [ValidateRange(1, 3600)]
    [int]$RunTimeoutSec = 30,
    [switch]$Json
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
$targetDir = Join-Path $Root "target"
$compilerCandidates = @(
    (Join-Path $Root "bin\nucleor.exe"),
    (Join-Path $Root "bin\nucleor")
)
$bridgeArtifactCandidates = @(
    (Join-Path $bridgeReleaseDir "nucleor_rust_bridge.lib"),
    (Join-Path $bridgeReleaseDir "libnucleor_rust_bridge.a")
)

$script:completedExecutions = 0
$script:currentBridgeArtifact = ""
$script:lastReadiness = $null
$script:selectedFixtures = @()

function Get-FixtureCycleCount([string]$Path) {
    if ($Path -match "rust_bridge_string_free_repeat_smoke\.nr$") {
        return 700
    }
    if ($Path -match "rust_bridge_hash_determinism_smoke\.nr$") {
        return 2
    }
    return 100
}

function New-FixtureInfo([string]$Key, [string]$Arg, [int]$Cycles) {
    $argForCompiler = $Arg.Replace("\", "/")
    if ([System.IO.Path]::IsPathRooted($Arg)) {
        $path = [System.IO.Path]::GetFullPath($Arg)
        $display = $path
    } else {
        $path = Join-Path $Root $Arg
        $display = $argForCompiler
    }

    return [pscustomobject]@{
        Key = $Key
        Arg = $argForCompiler
        Path = $path
        Display = $display
        Cycles = $Cycles
    }
}

function Resolve-Fixtures([string]$Selector) {
    switch ($Selector) {
        "string-free" {
            return @(New-FixtureInfo "string-free" "tests/features/rust_bridge_string_free_smoke.nr" 100)
        }
        "string-free-repeat" {
            return @(New-FixtureInfo "string-free-repeat" "tests/features/rust_bridge_string_free_repeat_smoke.nr" 700)
        }
        "repeat" {
            return @(New-FixtureInfo "string-free-repeat" "tests/features/rust_bridge_string_free_repeat_smoke.nr" 700)
        }
        "hash" {
            return @(New-FixtureInfo "hash" "tests/features/rust_bridge_hash_determinism_smoke.nr" 2)
        }
        "all" {
            return @(
                (New-FixtureInfo "string-free" "tests/features/rust_bridge_string_free_smoke.nr" 100),
                (New-FixtureInfo "hash" "tests/features/rust_bridge_hash_determinism_smoke.nr" 2)
            )
        }
        default {
            return @(New-FixtureInfo "custom" $Selector (Get-FixtureCycleCount $Selector))
        }
    }
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

function Get-Readiness($Fixtures) {
    $cargo = Get-CommandPath "cargo"
    $compiler = Get-FirstExistingPath $compilerCandidates
    $bridgeArtifact = Get-FirstExistingPath $bridgeArtifactCandidates
    $cratePresent = (Test-Path -LiteralPath $bridgeCargo) -and (Test-Path -LiteralPath $bridgeSrc)
    $fixtureRows = @()
    $allFixturesPresent = $true

    foreach ($fixtureInfo in $Fixtures) {
        $present = Test-Path -LiteralPath $fixtureInfo.Path
        if (-not $present) {
            $allFixturesPresent = $false
        }
        $fixtureRows += [pscustomobject]@{
            Key = $fixtureInfo.Key
            Arg = $fixtureInfo.Arg
            Path = $fixtureInfo.Path
            Present = $present
            Cycles = $fixtureInfo.Cycles
        }
    }

    $canBuildArtifact = (-not [string]::IsNullOrWhiteSpace($cargo)) -and $cratePresent
    $canBuildFixture = (-not [string]::IsNullOrWhiteSpace($cargo)) -and
        (-not [string]::IsNullOrWhiteSpace($compiler)) -and
        $allFixturesPresent -and
        (($bridgeArtifact -ne "") -or $canBuildArtifact)

    return [pscustomobject]@{
        Cargo = $cargo
        Compiler = $compiler
        BridgeArtifact = $bridgeArtifact
        BridgeCratePresent = $cratePresent
        CanBuildArtifact = $canBuildArtifact
        CanBuildFixture = $canBuildFixture
        Fixtures = $fixtureRows
    }
}

function New-JsonPayload {
    param(
        [string]$Status,
        [string]$FailureReason,
        $Readiness,
        $Fixtures,
        [int]$Completed,
        [string]$BridgeArtifact
    )

    if ($null -eq $Readiness) {
        $Readiness = Get-Readiness $Fixtures
    }
    if ([string]::IsNullOrWhiteSpace($BridgeArtifact)) {
        $BridgeArtifact = $Readiness.BridgeArtifact
    }

    return [ordered]@{
        schema_version = 1
        host_family = "windows"
        mode = if ($Doctor) { "doctor" } else { "run" }
        fixture_selector = $Fixture
        iterations_requested = $Iterations
        fixture_executions_completed = $Completed
        cargo = [ordered]@{
            present = ($Readiness.Cargo -ne "")
            path = $Readiness.Cargo
        }
        bridge_artifact = [ordered]@{
            present = ($BridgeArtifact -ne "")
            path = if ($BridgeArtifact -ne "") { $BridgeArtifact } else { ($bridgeArtifactCandidates -join "; ") }
        }
        compiler = [ordered]@{
            present = ($Readiness.Compiler -ne "")
            path = $Readiness.Compiler
        }
        result_status = $Status
        failure_reason = $FailureReason
        fixtures = @($Readiness.Fixtures | ForEach-Object {
            [ordered]@{
                key = $_.Key
                path = $_.Path
                present = $_.Present
                rust_owned_free_cycles_per_execution = $_.Cycles
            }
        })
    }
}

function Exit-Json {
    param(
        [string]$Status,
        [string]$FailureReason,
        [int]$ExitCode,
        $Readiness,
        $Fixtures,
        [int]$Completed,
        [string]$BridgeArtifact
    )

    $payload = New-JsonPayload -Status $Status -FailureReason $FailureReason -Readiness $Readiness -Fixtures $Fixtures -Completed $Completed -BridgeArtifact $BridgeArtifact
    $payload | ConvertTo-Json -Depth 8
    exit $ExitCode
}

function Fail([string]$Message) {
    if ($Json) {
        Exit-Json -Status "failed" -FailureReason $Message -ExitCode 1 -Readiness $script:lastReadiness -Fixtures $script:selectedFixtures -Completed $script:completedExecutions -BridgeArtifact $script:currentBridgeArtifact
    }
    Write-Host ("ERROR rust_bridge ownership: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Run-Doctor {
    $r = Get-Readiness $script:selectedFixtures
    $script:lastReadiness = $r
    $failed = $false

    if ($r.Cargo -eq "") {
        $failed = $true
    }
    if (-not $r.BridgeCratePresent) {
        $failed = $true
    }
    if ($r.Compiler -eq "") {
        $failed = $true
    }
    foreach ($fixtureRow in $r.Fixtures) {
        if (-not $fixtureRow.Present) {
            $failed = $true
        }
    }
    if (-not $r.CanBuildFixture) {
        $failed = $true
    }

    if ($Json) {
        if ($failed) {
            Exit-Json -Status "unsupported" -FailureReason "missing cargo, compiler, bridge crate/artifact, or focused fixture" -ExitCode 96 -Readiness $r -Fixtures $script:selectedFixtures -Completed 0 -BridgeArtifact $r.BridgeArtifact
        }
        Exit-Json -Status "ready" -FailureReason "" -ExitCode 0 -Readiness $r -Fixtures $script:selectedFixtures -Completed 0 -BridgeArtifact $r.BridgeArtifact
    }

    Write-Status "cargo" ($r.Cargo -ne "") $(if ($r.Cargo -ne "") { $r.Cargo } else { "missing from PATH" })
    if ($r.BridgeCratePresent) {
        Write-Status "bridge-crate" $true $bridgeCrate
    } else {
        Write-Status "bridge-crate" $false ("missing Cargo.toml or src/lib.rs under {0}" -f $bridgeCrate)
    }

    $expected = $bridgeArtifactCandidates -join "; "
    if ($r.BridgeArtifact -ne "") {
        Write-Status "release-artifact" $true $r.BridgeArtifact
    } elseif ($r.CanBuildArtifact) {
        Write-Status "release-artifact" $true ("not present yet; normal run will attempt cargo build --release; expected {0}" -f $expected)
    } else {
        Write-Status "release-artifact" $false ("missing and cannot be built; expected {0}" -f $expected)
    }

    Write-Status "compiler-binary" ($r.Compiler -ne "") $(if ($r.Compiler -ne "") { $r.Compiler } else { "missing bin/nucleor.exe or bin/nucleor" })

    foreach ($fixtureRow in $r.Fixtures) {
        Write-Status ("focused-fixture:{0}" -f $fixtureRow.Key) $fixtureRow.Present $(if ($fixtureRow.Present) { $fixtureRow.Path } else { "missing $($fixtureRow.Path)" })
    }

    Write-Status "fixture-buildable" $r.CanBuildFixture $(if ($r.CanBuildFixture) { "prerequisites are sufficient to build selector $Fixture" } else { "missing compiler, fixture, cargo, crate, or bridge artifact" })

    if ($failed) {
        Write-Host "doctor result: not ready for rust_bridge ownership harness"
        exit 96
    }
    Write-Host "doctor result: ready for rust_bridge ownership harness"
    exit 0
}

$script:selectedFixtures = Resolve-Fixtures $Fixture

if ($Doctor) {
    Run-Doctor
}

$script:lastReadiness = Get-Readiness $script:selectedFixtures
if ($script:lastReadiness.Cargo -eq "") {
    Fail "cargo is missing from PATH; cannot build rust_bridge release artifact"
}
if (-not $script:lastReadiness.BridgeCratePresent) {
    Fail "rust_bridge crate is missing Cargo.toml or src/lib.rs under $bridgeCrate"
}
if ($script:lastReadiness.Compiler -eq "") {
    Fail "compiler binary missing: expected bin/nucleor.exe or bin/nucleor"
}
foreach ($fixtureRow in $script:lastReadiness.Fixtures) {
    if (-not $fixtureRow.Present) {
        Fail "focused fixture missing: $($fixtureRow.Path)"
    }
}

$script:currentBridgeArtifact = $script:lastReadiness.BridgeArtifact
if ($script:currentBridgeArtifact -eq "") {
    if (-not $Json) {
        Write-Host "rust_bridge artifact missing; running cargo build --release"
    }
    $cargoResult = Invoke-CapturedProcess -FilePath $script:lastReadiness.Cargo -ArgumentList @("build", "--release") -WorkingDirectory $bridgeCrate -TimeoutSec $BuildTimeoutSec
    if ($cargoResult.TimedOut -or $cargoResult.ExitCode -ne 0) {
        Fail ("cargo build --release failed with exit {0}`n{1}" -f $cargoResult.ExitCode, (Format-ProcessTail $cargoResult))
    }
    $script:currentBridgeArtifact = Get-FirstExistingPath $bridgeArtifactCandidates
    if ($script:currentBridgeArtifact -eq "") {
        Fail ("cargo build --release completed but no bridge artifact was found. Expected: {0}" -f ($bridgeArtifactCandidates -join "; "))
    }
    $script:lastReadiness = Get-Readiness $script:selectedFixtures
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
$totalCycles = 0
$lastExe = ""

foreach ($fixtureInfo in $script:selectedFixtures) {
    $oldExe = Get-OutputExecutable $OutName
    if ($oldExe -ne "") {
        Remove-Item -LiteralPath $oldExe -Force -ErrorAction SilentlyContinue
    }

    if (-not $Json) {
        Write-Host ("building focused fixture: {0}" -f $fixtureInfo.Display)
    }
    $buildResult = Invoke-CapturedProcess -FilePath $script:lastReadiness.Compiler -ArgumentList @("build", $fixtureInfo.Arg, "-o", $OutName, "--no-cache") -WorkingDirectory $Root -TimeoutSec $BuildTimeoutSec
    if ($buildResult.TimedOut -or $buildResult.ExitCode -ne 0) {
        Fail ("fixture build failed with exit {0}`n{1}" -f $buildResult.ExitCode, (Format-ProcessTail $buildResult))
    }

    $exe = Get-OutputExecutable $OutName
    if ($exe -eq "") {
        Fail ("fixture build reported success but executable was not found under target for output {0}" -f $OutName)
    }
    $lastExe = $exe

    for ($i = 1; $i -le $Iterations; $i++) {
        $runResult = Invoke-CapturedProcess -FilePath $exe -ArgumentList @() -WorkingDirectory $Root -TimeoutSec $RunTimeoutSec
        if ($runResult.TimedOut -or $runResult.ExitCode -ne 0) {
            Fail ("ownership fixture {0} iteration {1}/{2} failed with exit {3}`n{4}" -f $fixtureInfo.Key, $i, $Iterations, $runResult.ExitCode, (Format-ProcessTail $runResult))
        }
        $script:completedExecutions += 1
    }
    $totalCycles += ($Iterations * $fixtureInfo.Cycles)
}

if ($Json) {
    Exit-Json -Status "passed" -FailureReason "" -ExitCode 0 -Readiness $script:lastReadiness -Fixtures $script:selectedFixtures -Completed $script:completedExecutions -BridgeArtifact $script:currentBridgeArtifact
}

Write-Host ("OK rust_bridge ownership: fixture_selector={0} iterations={1} fixture_executions={2} fixture_alloc_free_cycles={3} bridge_artifact={4} executable={5}" -f $Fixture, $Iterations, $script:completedExecutions, $totalCycles, $script:currentBridgeArtifact, $lastExe)
exit 0
