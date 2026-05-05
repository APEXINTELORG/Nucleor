$ErrorActionPreference = "Stop"

$Root = [System.IO.Path]::GetDirectoryName($PSCommandPath)
$Self = Join-Path $Root "target\nucleor.exe"
function Resolve-ExtBinary {
    $existing = New-Object System.Collections.Generic.List[object]
    foreach ($candidate in @(
        (Join-Path $Root "target\nucleor_ext_llvm.exe"),
        (Join-Path $Root "target\rust_llvm\release\nucleor.exe"),
        (Join-Path $Root "target\release\nucleor.exe"),
        (Join-Path $Root "target\nucleor_ext.exe")
    )) {
        if (Test-Path -LiteralPath $candidate) {
            $existing.Add((Get-Item -LiteralPath $candidate))
        }
    }
    if ($existing.Count -gt 0) {
        return (($existing | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName)
    }
    return (Join-Path $Root "target\release\nucleor.exe")
}

function Resolve-LlvmBin {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:LLVM_SYS_180_PREFIX) {
        $candidates.Add((Join-Path $env:LLVM_SYS_180_PREFIX "bin"))
    }
    $candidates.Add("C:\Program Files\LLVM\bin")
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    return $null
}

function Resolve-ToolCommand {
    param([string[]]$Names)
    foreach ($name in $Names) {
        try {
            $cmd = Get-Command $name -ErrorAction Stop | Select-Object -First 1
            if ($cmd.Source) {
                return $cmd.Source
            }
            if ($cmd.Path) {
                return $cmd.Path
            }
        } catch {
        }
    }
    return $null
}

function Add-DoctorCheck {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [string]$Status,
        [string]$Detail,
        [bool]$Required = $false
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        status = $Status
        required = $Required
        detail = $Detail
    })
}

function Invoke-Doctor {
    param([string[]]$AllArgs)

    $jsonOutput = $false
    for ($i = 1; $i -lt $AllArgs.Count; $i++) {
        $arg = $AllArgs[$i]
        if ($arg -ieq "--json" -or $arg -ieq "--output=json") {
            $jsonOutput = $true
        } elseif ($arg -ieq "--output" -and $i + 1 -lt $AllArgs.Count -and $AllArgs[$i + 1] -ieq "json") {
            $jsonOutput = $true
            $i = $i + 1
        }
    }

    $checks = New-Object System.Collections.Generic.List[object]
    $compilerSource = Join-Path $Root "target\nucleor_s1_compiler.nr"
    $manifestPath = Join-Path (Get-Location) "Nucleor.toml"
    $manifestEntry = Resolve-ManifestEntry

    if (Test-Path -LiteralPath $Root) {
        Add-DoctorCheck $checks "repo-root" "PASS" $Root $true
    } else {
        Add-DoctorCheck $checks "repo-root" "FAIL" ("missing repo root: {0}" -f $Root) $true
    }

    if (Test-Path -LiteralPath $Self) {
        Add-DoctorCheck $checks "self-hosted-compiler" "PASS" $Self $true
    } else {
        Add-DoctorCheck $checks "self-hosted-compiler" "FAIL" ("missing compiler binary: {0}" -f $Self) $true
    }

    if (Test-Path -LiteralPath $compilerSource) {
        Add-DoctorCheck $checks "compiler-source" "PASS" $compilerSource $true
    } else {
        Add-DoctorCheck $checks "compiler-source" "FAIL" ("missing compiler source: {0}" -f $compilerSource) $true
    }

    if (Test-Path -LiteralPath $Ext) {
        Add-DoctorCheck $checks "advanced-cli" "PASS" $Ext $false
    } else {
        Add-DoctorCheck $checks "advanced-cli" "WARN" ("advanced CLI not present at {0}" -f $Ext) $false
    }

    $clangPath = Resolve-ToolCommand @("clang")
    $clangFromLlvmBin = $null
    if ($LlvmBin) {
        $candidateClang = Join-Path $LlvmBin "clang.exe"
        if (Test-Path -LiteralPath $candidateClang) {
            $clangFromLlvmBin = $candidateClang
        }
    }
    if ($clangPath) {
        Add-DoctorCheck $checks "clang" "PASS" $clangPath $true
    } elseif ($clangFromLlvmBin) {
        Add-DoctorCheck $checks "clang" "PASS" ("resolved via LLVM bin: {0}" -f $clangFromLlvmBin) $true
    } else {
        Add-DoctorCheck $checks "clang" "FAIL" "clang not found on PATH" $true
    }

    if ($LlvmBin) {
        Add-DoctorCheck $checks "llvm-bin" "PASS" $LlvmBin $false
    } else {
        Add-DoctorCheck $checks "llvm-bin" "WARN" "LLVM bin directory not auto-detected" $false
    }

    $leanPath = Resolve-ToolCommand @("lean")
    if ($leanPath) {
        Add-DoctorCheck $checks "lean4" "PASS" $leanPath $false
    } else {
        Add-DoctorCheck $checks "lean4" "WARN" "Lean 4 not found" $false
    }

    $coqPath = Resolve-ToolCommand @("rocq", "coqc")
    if ($coqPath) {
        Add-DoctorCheck $checks "coq-rocq" "PASS" $coqPath $false
    } else {
        Add-DoctorCheck $checks "coq-rocq" "WARN" "Coq/Rocq not found" $false
    }

    $isabellePath = Resolve-ToolCommand @("isabelle")
    if ($isabellePath) {
        Add-DoctorCheck $checks "isabelle" "PASS" $isabellePath $false
    } else {
        Add-DoctorCheck $checks "isabelle" "WARN" "Isabelle not found" $false
    }

    $pythonPath = Resolve-ToolCommand @("python")
    if ($pythonPath) {
        try {
            & $pythonPath -c "import sympy" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Add-DoctorCheck $checks "python-sympy" "PASS" $pythonPath $false
            } else {
                Add-DoctorCheck $checks "python-sympy" "WARN" ("Python found but SymPy import failed: {0}" -f $pythonPath) $false
            }
        } catch {
            Add-DoctorCheck $checks "python-sympy" "WARN" ("Python found but SymPy check failed: {0}" -f $pythonPath) $false
        }
    } else {
        Add-DoctorCheck $checks "python-sympy" "WARN" "Python not found" $false
    }

    if (Test-Path -LiteralPath $manifestPath) {
        if ($manifestEntry) {
            Add-DoctorCheck $checks "manifest" "PASS" ("{0} -> {1}" -f $manifestPath, $manifestEntry) $false
        } else {
            Add-DoctorCheck $checks "manifest" "WARN" ("manifest present but no entry resolved: {0}" -f $manifestPath) $false
        }
    } else {
        Add-DoctorCheck $checks "manifest" "WARN" ("no Nucleor.toml in current directory: {0}" -f (Get-Location)) $false
    }

    $requiredFailures = @($checks | Where-Object { $_.required -and $_.status -eq "FAIL" })
    $exitCode = if ($requiredFailures.Count -gt 0) { 1 } else { 0 }

    if ($jsonOutput) {
        [pscustomobject]@{
            repo_root = $Root
            cwd = (Get-Location).Path
            status = if ($exitCode -eq 0) { "pass" } else { "fail" }
            checks = $checks
        } | ConvertTo-Json -Depth 5
        exit $exitCode
    }

    Write-Host "Nucleor Doctor"
    Write-Host "=============="
    Write-Host ("repo root: {0}" -f $Root)
    Write-Host ("cwd:       {0}" -f (Get-Location).Path)
    Write-Host ""
    foreach ($check in $checks) {
        Write-Host ("[{0}] {1}: {2}" -f $check.status, $check.name, $check.detail)
    }
    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "doctor result: PASS"
    } else {
        Write-Host "doctor result: FAIL"
    }
    exit $exitCode
}

function Get-CommandSurfaceObject {
    $canonicalCommands = @(
        [pscustomobject]@{ name = "build"; kind = "compile"; routes = @("self-hosted", "rust-opt-in"); source_optional = $true; outputs = @(".exe", ".ll"); summary = "Build a program or project entrypoint" },
        [pscustomobject]@{ name = "build-fast"; kind = "compile"; routes = @("self-hosted"); source_optional = $true; outputs = @(".exe", ".ll"); summary = "Build with the faster self-hosted path" },
        [pscustomobject]@{ name = "build-strict"; kind = "compile"; routes = @("self-hosted"); source_optional = $true; outputs = @(".exe", ".ll"); summary = "Build with the strict self-hosted path" },
        [pscustomobject]@{ name = "build-shared"; kind = "compile"; routes = @("self-hosted"); source_optional = $true; outputs = @(".dll", ".lib", ".ll"); summary = "Build a shared library from `pub fn` exports" },
        [pscustomobject]@{ name = "run"; kind = "compile"; routes = @("self-hosted"); source_optional = $true; outputs = @(".exe"); summary = "Build and run a program or project entrypoint" },
        [pscustomobject]@{ name = "emit"; kind = "compile"; routes = @("self-hosted"); source_optional = $true; outputs = @(".ll"); summary = "Emit LLVM IR without linking" },
        [pscustomobject]@{ name = "build-ptx"; kind = "compile"; routes = @("self-hosted"); source_optional = $true; outputs = @(".ptx", ".ll"); summary = "Compile a target to NVIDIA PTX" },
        [pscustomobject]@{ name = "check"; kind = "analysis"; routes = @("self-hosted", "rust-opt-in"); source_optional = $true; outputs = @(); summary = "Run static analysis and checks" },
        [pscustomobject]@{ name = "explain"; kind = "analysis"; routes = @("self-hosted"); source_optional = $false; outputs = @(); summary = "Explain a compiler error code" },
        [pscustomobject]@{ name = "summary"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Compact module interface card" },
        [pscustomobject]@{ name = "query"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Machine-readable module interface" },
        [pscustomobject]@{ name = "abi"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Inspect C / Rust ABI for extern imports" },
        [pscustomobject]@{ name = "evidence"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Governance evidence report" },
        [pscustomobject]@{ name = "impact"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Reverse call impact for a function" },
        [pscustomobject]@{ name = "graph"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Source-level call/effect graph" },
        [pscustomobject]@{ name = "test"; kind = "analysis"; routes = @("self-hosted", "rust-opt-in"); source_optional = $true; outputs = @(".exe"); summary = "Discover and run @test / test_* functions" },
        [pscustomobject]@{ name = "bench"; kind = "analysis"; routes = @("self-hosted", "rust-opt-in"); source_optional = $true; outputs = @(".exe"); summary = "Build once and benchmark repeated runs" },
        [pscustomobject]@{ name = "perf"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Compile-path performance analysis" },
        [pscustomobject]@{ name = "build-wasm"; kind = "compile"; routes = @("self-hosted", "rust-opt-in"); source_optional = $true; outputs = @(".wasm"); summary = "Build a WebAssembly target" },
        [pscustomobject]@{ name = "audit"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Run audit checks" },
        [pscustomobject]@{ name = "policy"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Run policy checks" },
        [pscustomobject]@{ name = "certify"; kind = "analysis"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Run certification checks" },
        [pscustomobject]@{ name = "translate"; kind = "tool"; routes = @("self-hosted"); source_optional = $true; outputs = @(); summary = "Run translation helpers" },
        [pscustomobject]@{ name = "init"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @("Nucleor.toml", "src/main.nr"); summary = "Initialize a project" },
        [pscustomobject]@{ name = "bootstrap"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @(); summary = "Report bootstrap readiness and corpus state" },
        [pscustomobject]@{ name = "stage-dump"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @(); summary = "Dump compiler stage summaries" },
        [pscustomobject]@{ name = "profile"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @(); summary = "Timed binary execution profile" },
        [pscustomobject]@{ name = "lock"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @("Nucleor.lock"); summary = "Write a local/workspace lockfile" },
        [pscustomobject]@{ name = "install"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @("Nucleor.toml", "Nucleor.lock"); summary = "Add a path or registry dependency and refresh the lockfile" },
        [pscustomobject]@{ name = "publish"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @("Nucleor.package.sha256", "Nucleor.publish.json", "Nucleor.publish.signature.json"); summary = "Publish a package into a local registry (optionally signed)" },
        [pscustomobject]@{ name = "registry"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @(); summary = "List, search, and verify packages in a local registry" },
        [pscustomobject]@{ name = "sage"; kind = "tool"; routes = @("self-hosted"); source_optional = $false; outputs = @(); summary = "Sage_NS prove / certificate / gap checks" },
        [pscustomobject]@{ name = "fmt"; kind = "tool"; routes = @("wrapper-native"); source_optional = $true; outputs = @(); summary = "Format a Nucleor source file conservatively" },
        [pscustomobject]@{ name = "release"; kind = "tool"; routes = @("wrapper-native"); source_optional = $false; outputs = @("release-signature.json", "release-attestation.json", "release-attestation.dsse.json"); summary = "Manage native release signing and verification" },
        [pscustomobject]@{ name = "lsp"; kind = "tool"; routes = @("wrapper-native"); source_optional = $false; outputs = @(); summary = "Run the native diagnostics-first LSP server" },
        [pscustomobject]@{ name = "doctor"; kind = "tool"; routes = @("wrapper"); source_optional = $false; outputs = @(); summary = "Check compiler, toolchain, and optional backends" },
        [pscustomobject]@{ name = "help"; kind = "tool"; routes = @("wrapper", "self-hosted"); source_optional = $false; outputs = @(); summary = "Show command help" },
        [pscustomobject]@{ name = "commands"; kind = "tool"; routes = @("wrapper"); source_optional = $false; outputs = @(); summary = "Show canonical command surface in text or JSON" }
    )

    $advancedCommands = @()

    $advancedFlags = @(
        "--output", "--out-dir", "--registry", "--evidence", "--check-laws",
        "--release", "--lto", "--strip", "--tier", "--backend", "--features",
        "--opt-level"
    )

    $examples = @(
        [pscustomobject]@{ command = ".\nuc.bat build examples\print_test.nr -o print_test"; purpose = "Build a normal executable" },
        [pscustomobject]@{ command = ".\nuc.bat emit examples\print_test.nr -o print_test_ir"; purpose = "Emit LLVM IR only" },
        [pscustomobject]@{ command = ".\nuc.bat build-shared examples\shared_math.nr -o shared_math"; purpose = "Build a shared library with C/Rust export artifacts" },
        [pscustomobject]@{ command = ".\nuc.bat check examples\01_hello.nr --output json"; purpose = "Machine-readable check output" },
        [pscustomobject]@{ command = ".\nuc.bat explain NR031 --json"; purpose = "Explain an error code in machine-readable form" },
        [pscustomobject]@{ command = ".\nuc.bat query examples\effects_basic.nr"; purpose = "Machine-readable module interface" },
        [pscustomobject]@{ command = ".\nuc.bat abi examples\ffi_basic.nr --rust-extern"; purpose = "Emit Rust FFI declarations for extern imports" },
        [pscustomobject]@{ command = ".\nuc.bat evidence examples\effects_basic.nr"; purpose = "Governance evidence report" },
        [pscustomobject]@{ command = ".\nuc.bat graph examples\effects_basic.nr --json"; purpose = "Machine-readable call/effect graph" },
        [pscustomobject]@{ command = ".\nuc.bat perf examples\effects_basic.nr --json"; purpose = "Machine-readable compile-path perf report" },
        [pscustomobject]@{ command = ".\nuc.bat profile run target\\my_program.exe --iterations 2 --json"; purpose = "Machine-readable execution profile" },
        [pscustomobject]@{ command = ".\nuc.bat lock .\\myproject\\Nucleor.toml --json"; purpose = "Write a local/workspace lockfile" },
        [pscustomobject]@{ command = "cd .\\myproject && ..\\nuc.bat install utils ..\\utils_pkg"; purpose = "Add a local path dependency from a project directory" },
        [pscustomobject]@{ command = ".\nuc.bat publish .\\myproject\\Nucleor.toml --registry .\\local_registry --sign"; purpose = "Publish a signed package into a local registry" },
        [pscustomobject]@{ command = ".\nuc.bat registry verify mypkg@0.1.0 --registry .\\local_registry"; purpose = "Verify a package from a local registry" },
        [pscustomobject]@{ command = ".\nuc.bat build --emit llvm --no-link examples\print_test.nr -o print_test_ir"; purpose = "Explicit IR-only build form" },
        [pscustomobject]@{ command = ".\nuc.bat build"; purpose = "Build from Nucleor.toml in the current directory" },
        [pscustomobject]@{ command = ".\nuc.bat commands --json"; purpose = "Stable machine-readable command surface" }
    )

    return [pscustomobject]@{
        tool = "nuc"
        wrapper = "nuc.bat"
        repo_root = $Root
        default_mode = "plain"
        command_surface_version = "2026-04-02"
        source_resolution = [pscustomobject]@{
            source_optional = $true
            project_manifest = "Nucleor.toml"
            manifest_entry_key = "entry"
            rule = "If no source path is provided, resolve [build].entry from Nucleor.toml in the current directory."
        }
        emit_behavior = [pscustomobject]@{
            command = "emit"
            links_executable = $false
            outputs = @(".ll")
            note = "emit is IR-only in the canonical wrapper surface"
        }
        advanced_routing = [pscustomobject]@{
            commands = $advancedCommands
            compile_commands_with_advanced_flags = $CompileCommands
            advanced_flags = $advancedFlags
            compatibility_fallback = "advanced flags stay on the self-hosted path by default; use --engine rust for explicit Rust CLI routing"
        }
        canonical_commands = $canonicalCommands
        examples = $examples
    }
}

function Show-CommandSurface {
    param([bool]$JsonOutput = $false)

    $surface = Get-CommandSurfaceObject
    if ($JsonOutput) {
        $surface | ConvertTo-Json -Depth 6
        exit 0
    }

    Write-Host "Nucleor Command Surface"
    Write-Host "======================="
    Write-Host ("wrapper:   {0}" -f $surface.wrapper)
    Write-Host ("repo root: {0}" -f $surface.repo_root)
    Write-Host ""
    Write-Host "Canonical commands:"
    foreach ($cmd in $surface.canonical_commands) {
        Write-Host ("  {0,-12} {1}" -f $cmd.name, $cmd.summary)
    }
    Write-Host ""
    Write-Host "Project/source resolution:"
    Write-Host ("  {0}" -f $surface.source_resolution.rule)
    Write-Host ""
    Write-Host "Emit behavior:"
    Write-Host ("  emit writes: {0}" -f (($surface.emit_behavior.outputs) -join ", "))
    Write-Host ("  links exe:   {0}" -f $surface.emit_behavior.links_executable)
    Write-Host ""
    Write-Host "Machine-readable form:"
    Write-Host "  .\nuc.bat commands --json"
    Write-Host "  .\nuc.bat help --json"
    Write-Host ""
    Write-Host "Examples:"
    foreach ($example in $surface.examples) {
        Write-Host ("  {0}" -f $example.command)
    }
    exit 0
}
$Ext = Resolve-ExtBinary
$LlvmBin = Resolve-LlvmBin

$ExtCommands = @()
$CompileCommands = @("build", "check", "test", "bench", "build-wasm")
$SourceCommands = @("build", "build-fast", "build-strict", "build-shared", "run", "emit", "build-wasm", "build-ptx", "check", "audit", "policy", "certify", "translate", "test", "bench", "summary", "query", "abi", "evidence", "impact", "graph", "perf", "fmt")
$AdvancedFlags = @(
    "--output", "--out-dir", "--registry", "--evidence", "--check-laws",
    "--release", "--lto", "--strip", "--tier", "--backend", "--features",
    "--opt-level"
)
$FlagValueNames = @{
    "-o" = $true
    "--out" = $true
    "--output" = $true
    "--out-dir" = $true
    "--registry" = $true
    "--tier" = $true
    "--backend" = $true
    "--features" = $true
    "--opt-level" = $true
    "--check" = $true
    "--review-filter" = $true
    "--iterations" = $true
    "--warmup" = $true
    "--emit" = $true
}

function Show-Help {
    param([bool]$JsonOutput = $false)

    if ($JsonOutput) {
        Show-CommandSurface -JsonOutput $true
    }

    & $Self "help"
    Write-Host ""
    Write-Host "Local wrapper commands:"
    Write-Host "  doctor                              Check toolchain, compiler binaries, and optional backends"
    Write-Host "  commands                            Show canonical command surface"
    Write-Host ""
    Write-Host "Native wrapper tools:"
    Write-Host "  fmt, lsp, release"
    if (Test-Path -LiteralPath $Ext) {
        Write-Host ""
        Write-Host "Engine selection:"
        Write-Host "  default is self-hosted, including advanced compile flags"
        Write-Host "  use --engine rust to route a command through the integrated Rust CLI explicitly"
    }
    exit $LASTEXITCODE
}

function Test-AdvancedFlag {
    param([string[]]$ArgsToScan)
    for ($i = 0; $i -lt $ArgsToScan.Count; $i++) {
        $arg = $ArgsToScan[$i]
        $lower = $arg.ToLowerInvariant()
        if ($lower -eq "--output" -and $i + 1 -lt $ArgsToScan.Count) {
            $next = $ArgsToScan[$i + 1].ToLowerInvariant()
            if ($next -eq "json" -or $next -eq "sarif") {
                $i = $i + 1
                continue
            }
        }
        if ($lower.StartsWith("--output=")) {
            $fmt = $arg.Substring($arg.IndexOf("=") + 1).ToLowerInvariant()
            if ($fmt -eq "json" -or $fmt -eq "sarif") {
                continue
            }
        }
        foreach ($name in $AdvancedFlags) {
            if ($arg -ieq $name -or $arg.StartsWith("$name=", [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }
    return $false
}

function Get-EngineSelection {
    param([string[]]$AllArgs)
    for ($i = 1; $i -lt $AllArgs.Count; $i++) {
        $arg = $AllArgs[$i]
        $lower = $arg.ToLowerInvariant()
        if ($lower -eq "--engine" -and $i + 1 -lt $AllArgs.Count) {
            return $AllArgs[$i + 1].ToLowerInvariant()
        }
        if ($lower.StartsWith("--engine=")) {
            return $arg.Substring($arg.IndexOf("=") + 1).ToLowerInvariant()
        }
    }
    return $null
}

function Remove-EngineFlags {
    param([string[]]$AllArgs)
    $clean = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $AllArgs.Count; $i++) {
        $arg = $AllArgs[$i]
        $lower = $arg.ToLowerInvariant()
        if ($lower -eq "--engine") {
            if ($i + 1 -lt $AllArgs.Count) {
                $i = $i + 1
            }
            continue
        }
        if ($lower.StartsWith("--engine=")) {
            continue
        }
        $clean.Add($arg)
    }
    return $clean.ToArray()
}

function Convert-SelfHostedOutputFlags {
    param([string]$CommandName, [string[]]$AllArgs)
    $converted = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $AllArgs.Count; $i++) {
        $arg = $AllArgs[$i]
        $lower = $arg.ToLowerInvariant()
        if ($CommandName -eq "check") {
            if ($lower -eq "--output" -and $i + 1 -lt $AllArgs.Count) {
                $fmt = $AllArgs[$i + 1].ToLowerInvariant()
                if ($fmt -eq "json") {
                    $converted.Add("--json")
                    $i = $i + 1
                    continue
                }
                if ($fmt -eq "sarif") {
                    $converted.Add("--sarif")
                    $i = $i + 1
                    continue
                }
            }
            if ($lower.StartsWith("--output=")) {
                $fmt = $arg.Substring($arg.IndexOf("=") + 1).ToLowerInvariant()
                if ($fmt -eq "json") {
                    $converted.Add("--json")
                    continue
                }
                if ($fmt -eq "sarif") {
                    $converted.Add("--sarif")
                    continue
                }
            }
        }
        $converted.Add($arg)
    }
    return $converted.ToArray()
}

function Get-SourceArg {
    param([string]$CommandName, [string[]]$AllArgs)
    if ($AllArgs.Count -lt 2) {
        return $null
    }
    $skipNext = $false
    for ($i = 1; $i -lt $AllArgs.Count; $i++) {
        if ($skipNext) {
            $skipNext = $false
            continue
        }
        $arg = $AllArgs[$i]
        if ($FlagValueNames.ContainsKey($arg.ToLowerInvariant())) {
            $skipNext = $true
            continue
        }
        if ($arg.StartsWith("-")) {
            continue
        }
        return $arg
    }
    return $null
}

function Resolve-ManifestEntry {
    $manifest = Join-Path (Get-Location) "Nucleor.toml"
    if (-not (Test-Path -LiteralPath $manifest)) {
        return $null
    }
    $entryLine = Get-Content -LiteralPath $manifest | Where-Object { $_ -match '^\s*entry\s*=\s*["''](.*)["'']\s*$' } | Select-Object -First 1
    if (-not $entryLine) {
        return $null
    }
    $entry = [regex]::Match($entryLine, '^\s*entry\s*=\s*["''](.*)["'']\s*$').Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($entry)) {
        return $null
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $entry))
}

function Resolve-TargetPath {
    param([string]$SourceArg)
    if ([string]::IsNullOrWhiteSpace($SourceArg)) {
        return Resolve-ManifestEntry
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $SourceArg))
}

function Validate-SourceContext {
    param([string]$CommandName, [string[]]$AllArgs)

    if (-not ($SourceCommands -contains $CommandName)) {
        return $null
    }

    $manifest = Join-Path (Get-Location) "Nucleor.toml"
    $sourceArg = Get-SourceArg -CommandName $CommandName -AllArgs $AllArgs
    $resolvedTarget = Resolve-TargetPath -SourceArg $sourceArg

    if ([string]::IsNullOrWhiteSpace($sourceArg)) {
        if (-not (Test-Path -LiteralPath $manifest)) {
            return @(
                "ERROR: no source file provided and no Nucleor.toml found in the current directory",
                ("  cwd: {0}" -f (Get-Location).Path),
                "  fix: pass a .nr source path or run the command from a project directory with Nucleor.toml"
            )
        }
        if (-not $resolvedTarget) {
            return @(
                "ERROR: Nucleor.toml found but [build].entry could not be resolved",
                ("  manifest: {0}" -f $manifest),
                '  expected: entry = "src/main.nr"'
            )
        }
        if (-not (Test-Path -LiteralPath $resolvedTarget)) {
            return @(
                "ERROR: manifest entry points to a missing source file",
                ("  manifest: {0}" -f $manifest),
                ("  entry:    {0}" -f $resolvedTarget)
            )
        }
        return $null
    }

    if (-not (Test-Path -LiteralPath $resolvedTarget)) {
        return @(
            "ERROR: source file not found",
            ("  source: {0}" -f $sourceArg),
            ("  cwd:    {0}" -f (Get-Location).Path)
        )
    }

    return $null
}

function Invoke-NativeFmt {
    param([string[]]$AllArgs)

    $sourceArg = Get-SourceArg -CommandName "fmt" -AllArgs $AllArgs
    $resolvedTarget = Resolve-TargetPath -SourceArg $sourceArg
    $checkMode = $false
    $writeMode = $false
    foreach ($arg in $AllArgs) {
        switch -Regex ($arg.ToLowerInvariant()) {
            '^--check$' { $checkMode = $true; continue }
            '^--write$|^-w$' { $writeMode = $true; continue }
        }
    }
    $scriptPath = Join-Path $Root "tools\native_fmt.ps1"
    . $scriptPath -FilePath $resolvedTarget -Check:$checkMode -Write:$writeMode
    exit $LASTEXITCODE
}

function Invoke-NativeRelease {
    param([string[]]$AllArgs)
    $scriptPath = Join-Path $Root "tools\native_release.ps1"
    $rest = @()
    if ($AllArgs.Count -gt 1) {
        $rest = $AllArgs[1..($AllArgs.Count - 1)]
    }
    . $scriptPath -Root $Root @rest
    exit $LASTEXITCODE
}

function Invoke-NativeLsp {
    $scriptPath = Join-Path $Root "tools\native_lsp.ps1"
    . $scriptPath -Root $Root -CompilerPath $Self
    exit $LASTEXITCODE
}

function Test-CompatTarget {
    param([string]$ResolvedPath)
    if ([string]::IsNullOrWhiteSpace($ResolvedPath)) {
        return $false
    }
    if (Test-Path -LiteralPath $ResolvedPath) {
        $content = Get-Content -LiteralPath $ResolvedPath -Raw
        if ($content -match 'Vec<i32>') {
            return $true
        }
    }
    return $false
}

function Invoke-SelfCompat {
    param([string[]]$AllArgs)

    $cmd = $AllArgs[0]
    $translated = New-Object System.Collections.Generic.List[string]
    $translated.Add($cmd)

    $sourceArg = Get-SourceArg -CommandName $cmd -AllArgs $AllArgs
    if ($sourceArg) {
        $translated.Add($sourceArg)
    }

    $outDir = $null
    $outName = $null
    $ignored = New-Object System.Collections.Generic.List[string]
    $skipNext = $false

    for ($i = 1; $i -lt $AllArgs.Count; $i++) {
        if ($skipNext) {
            $skipNext = $false
            continue
        }
        $arg = $AllArgs[$i]
        $lower = $arg.ToLowerInvariant()

        if ($sourceArg -and $arg -eq $sourceArg) {
            continue
        }

        switch -Regex ($lower) {
            '^--release$|^--lto$|^--strip$' {
                $ignored.Add($arg)
                continue
            }
            '^--check-laws$' {
                # R14-D3 Phase 1 (v0.8.263): no longer silently ignored.
                # The compiler's lex path already emits info[LAW-CAPTURE]
                # for every @law(...) annotation (R14-D1, v0.8.262); this
                # branch acknowledges --check-laws was passed and surfaces
                # the LAW-CAPTURE summary post-build. Phase 2 will
                # generate bounded property tests + return nonzero on
                # counterexamples per BUILD_PLAN_R14_algebraic_laws.md
                # §1 R14-D3 acceptance.
                Write-Host "info[CHECK-LAWS]: --check-laws acknowledged (R14-D3 Phase 1). Compiler emits info[LAW-CAPTURE] per @law annotation; Phase 2 will add property-test generation + counterexample-driven exit code." -ForegroundColor Cyan
                continue
            }
            '^--(tier|backend|features|opt-level|registry|evidence)$' {
                $ignored.Add($arg)
                if ($i + 1 -lt $AllArgs.Count -and -not $AllArgs[$i + 1].StartsWith("-")) {
                    $skipNext = $true
                }
                continue
            }
            '^--(tier|backend|features|opt-level|registry|out-dir)=' {
                $ignored.Add($arg)
                if ($lower.StartsWith("--out-dir=")) {
                    $outDir = $arg.Substring($arg.IndexOf("=") + 1)
                }
                continue
            }
            '^--out-dir$' {
                $ignored.Add($arg)
                if ($i + 1 -lt $AllArgs.Count) {
                    $outDir = $AllArgs[$i + 1]
                    $skipNext = $true
                }
                continue
            }
            '^--output$' {
                $ignored.Add($arg)
                if ($i + 1 -lt $AllArgs.Count) {
                    $fmt = $AllArgs[$i + 1].ToLowerInvariant()
                    if ($cmd -eq "check") {
                        if ($fmt -eq "json") {
                            $translated.Add("--json")
                        } elseif ($fmt -eq "sarif") {
                            $translated.Add("--sarif")
                        }
                    }
                    $skipNext = $true
                }
                continue
            }
            '^--output=' {
                $ignored.Add($arg)
                $fmt = $arg.Substring($arg.IndexOf("=") + 1).ToLowerInvariant()
                if ($cmd -eq "check") {
                    if ($fmt -eq "json") {
                        $translated.Add("--json")
                    } elseif ($fmt -eq "sarif") {
                        $translated.Add("--sarif")
                    }
                }
                continue
            }
            '^-o$|^--out$' {
                $translated.Add($arg)
                if ($i + 1 -lt $AllArgs.Count) {
                    $outName = $AllArgs[$i + 1]
                    $translated.Add($outName)
                    $skipNext = $true
                }
                continue
            }
            '^--emit$' {
                $translated.Add($arg)
                if ($i + 1 -lt $AllArgs.Count) {
                    $translated.Add($AllArgs[$i + 1])
                    $skipNext = $true
                }
                continue
            }
            default {
                $translated.Add($arg)
            }
        }
    }

    if ($ignored.Count -gt 0) {
        Write-Host ("compat fallback: routing {0} to the self-hosted compiler; ignoring Rust-only flags: {1}" -f $cmd, (($ignored | Select-Object -Unique) -join ", "))
    } else {
        Write-Host ("compat fallback: routing {0} to the self-hosted compiler" -f $cmd)
    }

    & $Self @translated
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0 -and $outDir) {
        $resolvedTarget = Resolve-TargetPath -SourceArg $sourceArg
        if ($outName) {
            $artifactBase = [System.IO.Path]::GetFileName($outName)
        } elseif ($resolvedTarget) {
            $artifactBase = [System.IO.Path]::GetFileNameWithoutExtension($resolvedTarget)
        } else {
            $artifactBase = $null
        }
        if ($artifactBase) {
            $targetDir = Join-Path $Root "target"
            $resolvedOutDir = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $outDir))
            New-Item -ItemType Directory -Force -Path $resolvedOutDir | Out-Null
            foreach ($ext in @(".exe", ".ll", ".wasm", ".ptx")) {
                $srcArtifact = Join-Path $targetDir ($artifactBase + $ext)
                if (Test-Path -LiteralPath $srcArtifact) {
                    Copy-Item -LiteralPath $srcArtifact -Destination (Join-Path $resolvedOutDir ([System.IO.Path]::GetFileName($srcArtifact))) -Force
                }
            }
        }
    }

    exit $exitCode
}

if ($args.Count -eq 0) {
    Show-Help
}

$cmd = $args[0].ToLowerInvariant()
$engine = Get-EngineSelection -AllArgs $args
$sanitizedArgs = Remove-EngineFlags -AllArgs $args
$selfHostedArgs = Convert-SelfHostedOutputFlags -CommandName $cmd -AllArgs $sanitizedArgs
if ($cmd -in @("help", "--help", "-h")) {
    $jsonHelp = $false
    foreach ($arg in $sanitizedArgs) {
        if ($arg -ieq "--json" -or $arg -ieq "--output=json") {
            $jsonHelp = $true
        }
    }
    Show-Help -JsonOutput $jsonHelp
}
if ($cmd -eq "commands") {
    $jsonCommands = $false
    foreach ($arg in $sanitizedArgs) {
        if ($arg -ieq "--json" -or $arg -ieq "--output=json") {
            $jsonCommands = $true
        }
    }
    Show-CommandSurface -JsonOutput $jsonCommands
}
if ($cmd -eq "doctor") {
    Invoke-Doctor -AllArgs $selfHostedArgs
}
$sourceDiagnostic = Validate-SourceContext -CommandName $cmd -AllArgs $selfHostedArgs
if ($sourceDiagnostic) {
    foreach ($line in $sourceDiagnostic) {
        Write-Host $line
    }
    exit 1
}

if ($cmd -eq "fmt") {
    Invoke-NativeFmt -AllArgs $selfHostedArgs
}
if ($cmd -eq "release") {
    Invoke-NativeRelease -AllArgs $selfHostedArgs
}
if ($cmd -eq "lsp") {
    Invoke-NativeLsp
}
if ($cmd -eq "build-ptx" -and (Test-AdvancedFlag -ArgsToScan $selfHostedArgs) -and $engine -ne "rust") {
    Invoke-SelfCompat -AllArgs $selfHostedArgs
}

$routeExt = $false
if ($ExtCommands -contains $cmd) {
    $routeExt = $true
}
if ($engine -eq "rust") {
    $routeExt = $true
}

if ($routeExt -and ($CompileCommands -contains $cmd)) {
    $resolvedTarget = Resolve-TargetPath -SourceArg (Get-SourceArg -CommandName $cmd -AllArgs $selfHostedArgs)
    if (Test-CompatTarget -ResolvedPath $resolvedTarget) {
        Invoke-SelfCompat -AllArgs $selfHostedArgs
    }
}

if (-not $routeExt -and ($CompileCommands -contains $cmd) -and (Test-AdvancedFlag -ArgsToScan $selfHostedArgs)) {
    Invoke-SelfCompat -AllArgs $selfHostedArgs
}

if ($routeExt) {
    if (-not (Test-Path -LiteralPath $Ext)) {
        Write-Host ("ERROR: advanced CLI binary not found at `"{0}`"" -f $Ext)
        Write-Host "Build it with: cargo build -p nucleor-cli --release"
        exit 1
    }
    if (($cmd -eq "build-ptx" -or $Ext -like "*nucleor_ext_llvm.exe" -or $Ext -like "*rust_llvm*") -and $LlvmBin) {
        $pathParts = $env:PATH -split ';'
        if (-not ($pathParts | Where-Object { $_ -ieq $LlvmBin })) {
            $env:PATH = $LlvmBin + ";" + $env:PATH
        }
    }
    & $Ext @sanitizedArgs
    exit $LASTEXITCODE
}

# R14-D3 Phase 1 (v0.8.263): if `--check-laws` was passed, surface a
# visible acknowledgment so the flag is no longer silently ignored.
# The compiler's lex path already emits info[LAW-CAPTURE] per @law
# annotation (R14-D1, v0.8.262); this acknowledgment proves the
# router sees the flag and sets the stage for Phase 2 property-test
# generation per BUILD_PLAN_R14_algebraic_laws.md §1 R14-D3.
$checkLawsRequested = $false
foreach ($_chkArg in $selfHostedArgs) {
    if ($_chkArg -ieq "--check-laws") { $checkLawsRequested = $true }
}
if ($checkLawsRequested) {
    Write-Host "info[CHECK-LAWS]: --check-laws acknowledged (R14-D3 Phase 1). Compiler emits info[LAW-CAPTURE] per @law annotation; Phase 2 will add property-test generation + counterexample-driven exit code."
}

& $Self @selfHostedArgs
exit $LASTEXITCODE
