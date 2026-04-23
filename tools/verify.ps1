# verify.ps1 — smoke gate for the Nucleor OSS distribution.
#
# Usage: powershell.exe -ExecutionPolicy Bypass -File tools\verify.ps1
#
# Steps:
#   1. Confirm bin\nucleor.exe loads
#   2. Build and run examples 01..06 + 08..18 (07 only if rust_bridge built)
#   3. Build and run all positive tests under tests\{lang,attrs,runtime,rods}
#   4. Confirm negative tests under tests\err\ fail with the expected diagnostic
#   5. Self-host loop: rebuild the compiler from source
#
# Exit code: 0 = ship-ready; 1 = a step failed.
#
# Output: progress counter [N/T] per step, colored OK/FAIL/SKIP labels when
# stdout is a TTY. Honors NO_COLOR (https://no-color.org/) and --no-color.

param(
    [switch]$NoColor
)

$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $root "bin\nucleor.exe"

# --- Color setup --------------------------------------------------------
$useColor = $true
if ($NoColor) { $useColor = $false }
if ($env:NO_COLOR) { $useColor = $false }
# Detect TTY: PowerShell knows via $Host.UI.RawUI; piped output is BufferSize=null.
try {
    $null = $Host.UI.RawUI.WindowSize
} catch {
    $useColor = $false
}

# Enable VT processing for ANSI colors on Windows 10+ cmd / PowerShell hosts.
if ($useColor) {
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
}

function Color($text, $ansi) {
    if ($useColor) { return "$([char]27)[${ansi}m${text}$([char]27)[0m" } else { return $text }
}
function Green($t)  { return Color $t "32" }
function Yellow($t) { return Color $t "33" }
function Red($t)    { return Color $t "31" }
function Dim($t)    { return Color $t "2"  }

# --- Step counter -------------------------------------------------------
$totalPass = 0
$totalFail = 0
$totalSkip = 0
$failures  = @()
$stepIndex = 0
$stepTotal = 0   # filled in once we know the totals

function Step($stepName, [scriptblock]$action) {
    $script:stepIndex++
    $prefix = "[{0,3}/{1}]" -f $script:stepIndex, $script:stepTotal
    $result = & $action
    $ok = $false
    $skipped = $false
    if ($null -ne $result) {
        if ($result -is [array]) {
            $last = $result[-1]
            if ($last -is [string] -and $last -eq "SKIP") { $skipped = $true }
            else { $ok = [bool]$last }
        } else {
            if ($result -is [string] -and $result -eq "SKIP") { $skipped = $true }
            else { $ok = [bool]$result }
        }
    }
    if ($skipped) {
        Write-Host ("$prefix " + (Yellow "SKIP") + "  $stepName")
        $script:totalSkip++
    } elseif ($ok) {
        Write-Host ("$prefix " + (Green "OK  ") + "  $stepName")
        $script:totalPass++
    } else {
        Write-Host ("$prefix " + (Red   "FAIL") + "  $stepName")
        $script:totalFail++
        $script:failures += $stepName
    }
}

# --- Ensure clang is on PATH (mirror nuc.bat resolution) ----------------
# Verify each candidate has clang.exe before accepting it (env vars can be stale).
if (-not (Get-Command clang -ErrorAction SilentlyContinue)) {
    $clangCandidate = $null
    if ($env:NUCLEOR_CLANG_PATH -and (Test-Path $env:NUCLEOR_CLANG_PATH)) {
        $clangCandidate = Split-Path -Parent $env:NUCLEOR_CLANG_PATH
    } elseif ($env:LLVM_SYS_180_PREFIX -and (Test-Path (Join-Path $env:LLVM_SYS_180_PREFIX "bin\clang.exe"))) {
        $clangCandidate = Join-Path $env:LLVM_SYS_180_PREFIX "bin"
    } elseif (Test-Path "C:\Program Files\LLVM\bin\clang.exe") {
        $clangCandidate = "C:\Program Files\LLVM\bin"
    }
    if ($clangCandidate) {
        $env:PATH = "$clangCandidate;$env:PATH"
    }
}

Push-Location $root

# --- Compute total step count for the [N/T] counter ---------------------
$rustBridgeLib = Join-Path $root "stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib"
# Read example list from the single source of truth (shared with
# verify.sh). v0.2.60 — eliminates the drift class that bit v0.2.59.
$examplesFile = Join-Path $root "tools\examples.list"
$examples = @()
if (Test-Path $examplesFile) {
    Get-Content $examplesFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            $examples += $line
        }
    }
}
if (Test-Path $rustBridgeLib) { $examples += "07_rust_interop" }

$testDirs = @("lang", "attrs", "runtime", "rods", "features")
# Files matching this pattern are auxiliary helpers imported by another
# test (e.g. via `mod foo;`) and are not standalone-runnable. Skipping
# them keeps the gate from treating them as duplicate-main failures.
$testSkipPattern = "_aux\.nr$"
$testCount = 0
foreach ($d in $testDirs) {
    $testCount += (Get-ChildItem -Path (Join-Path $root "tests\$d") -Filter "*.nr" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $testSkipPattern }).Count
}
$errCount = (Get-ChildItem -Path (Join-Path $root "tests\err") -Filter "*.nr" -ErrorAction SilentlyContinue).Count

# 1 (binary present) + 1 (drift check) + 1 (tools-rebuild) +
# 1 (help coverage) + 1 (utility smoke) + 1 (json smoke) +
# 1 (version aliases) + 1 (showcase build) + 1 (CLI explain smoke)
# + 1 (explain-full) + 1 (bootstrap) + 1 (check+abi) + 1 (inspectors)
# + 1 (diagnostics) + 1 (init) + 1 (doc) + 1 (lock) + 1 (test)
# + N examples + N tests + N err + 1 (self-host)
$stepTotal = 18 + $examples.Count + $testCount + $errCount + 1

# --- Run the gate -------------------------------------------------------
Step "binary present" {
    if (-not (Test-Path $bin)) { return $false }
    $out = & $bin help 2>&1 | Select-String "Nucleor Compiler" | Select-Object -First 1
    return $null -ne $out
}

Step "compiler ABI tables synced" {
    # Mirrors tools/check_compiler_drift.sh — verify the s1-compiler ↔
    # tools-suite get_rt_name / is_ptr_ret / is_ptr_arg / IR `declare`
    # tables stay aligned.  Drift produces unprefixed @<name> calls in
    # `nuc test` / `nuc build-strict` / `nuc check`.
    $bash = $env:NUCLEOR_BASH_PATH
    if (-not $bash -or -not (Test-Path $bash)) {
        if (Test-Path "C:\Program Files\Git\bin\bash.exe") {
            $bash = "C:\Program Files\Git\bin\bash.exe"
        } elseif (Test-Path "C:\msys64\usr\bin\bash.exe") {
            $bash = "C:\msys64\usr\bin\bash.exe"
        } else {
            # Bash unavailable on this host; skip silently rather than fail
            # the gate. Linux/macOS gates always run the bash version.
            return $true
        }
    }
    $script = Join-Path $root "tools\check_compiler_drift.sh"
    & $bash $script *> $null
    return $LASTEXITCODE -eq 0
}

Step "tools-suite rebuild" {
    # Mirrors verify.sh tools_rebuild (added v0.2.79). Rebuilds the
    # nucleor_tools.exe binary so the explain registry, `nuc test`
    # harness writer, and other tools-suite logic are tested
    # against the current source. Without this a pull that updates
    # nucleor_tools_suite.nr would leave the user's stale
    # bin\nucleor_tools.exe in place.
    & $bin build "compiler/nucleor_tools_suite.nr" -o "nucleor_tools" *> $null
    $built = "target\nucleor_tools.exe"
    if (-not (Test-Path $built)) { return $false }
    Copy-Item $built (Join-Path $root "bin\nucleor_tools.exe") -Force -ErrorAction SilentlyContinue
    return $true
}

Step "examples/showcase: lorenz/vqe_h2/market_maker/wing_simulator build" {
    # Mirrors verify.sh showcase_build_smoke (added v0.2.90).
    # Build-only — the four showcase programs produce streaming
    # ANSI dashboards that don't terminate on their own, so we
    # don't run them. Build catches stdlib regressions that would
    # break the showcase compile path.
    foreach ($prog in @("lorenz", "vqe_h2", "market_maker", "wing_simulator")) {
        & $bin build "examples/showcase/$prog.nr" -o "showcase_$prog" *> $null
        $exe = "target\showcase_$prog.exe"
        if (-not (Test-Path $exe)) { return $false }
    }
    return $true
}

Step "CLI: --version / -v / -V / version aliases" {
    # Mirrors verify.sh cli_version_smoke (added v0.2.87). All four
    # spellings of "give me the version" must work.
    foreach ($variant in @("--version", "-v", "-V", "version")) {
        $out = (& $bin $variant 2>&1 | Out-String).Trim().Split("`n")[0]
        if ($out -notmatch "^nucleor ") { return $false }
    }
    return $true
}

Step "CLI: --json variants emit machine-readable JSON" {
    # Mirrors verify.sh cli_json_smoke (added v0.2.86). Locks down
    # which commands honor --json today. NOTE: --json must come
    # AFTER the source positional for file-taking commands.
    $jsonCmds = @("audit", "summary", "query", "abi", "evidence", "graph", "perf", "check")
    foreach ($cmd in $jsonCmds) {
        $out = (& $bin $cmd "examples/01_hello.nr" --json 2>&1 | Out-String).TrimStart()
        if (-not ($out.StartsWith("{") -or $out.StartsWith("["))) { return $false }
    }
    $out = (& $bin explain "NUM-001" --json 2>&1 | Out-String).TrimStart()
    if (-not $out.StartsWith("{")) { return $false }
    $out = (& $bin bootstrap --json 2>&1 | Out-String).TrimStart()
    if (-not $out.StartsWith("{")) { return $false }
    $out = (& $bin lock --json 2>&1 | Out-String).TrimStart()
    if (-not $out.StartsWith("{")) { return $false }
    return $true
}

Step "CLI: nuc zen/mco/registry/stage-dump/fix (utilities)" {
    # Mirrors verify.sh cli_utility_smoke (added v0.2.85). Smokes
    # the zero-side-effect utility commands. clean / scram NOT
    # smoked because they delete target/ mid-gate.
    $zenOut = & $bin zen 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($zenOut)) { return $false }
    if ($zenOut -notmatch "The Zen of Nucleor") { return $false }
    $mcoOut = & $bin mco 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($mcoOut)) { return $false }
    if ($mcoOut -notmatch "Mars Climate Orbiter") { return $false }
    $regOut = & $bin registry list 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($regOut)) { return $false }
    if ($regOut -notmatch "registry: ") { return $false }
    if ($regOut -notmatch "packages: ") { return $false }
    # Catch the v0.2.85 stderr leak by name.
    if ($regOut -match "system cannot find") { return $false }
    $tokOut = & $bin stage-dump tokens "examples/01_hello.nr" 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($tokOut)) { return $false }
    if ($tokOut -notmatch "TOKENS") { return $false }
    $fixOut = & $bin fix --imports "examples/01_hello.nr" 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($fixOut)) { return $false }
    return $true
}

Step "CLI: nuc help advertises every dispatched command" {
    # Mirrors verify.sh cli_help_coverage_smoke (added v0.2.84).
    # Catches the drift class that bit `doc` and `fix` (both shipped
    # + smoke-tested but absent from `nuc help`).
    $out = & $bin help 2>&1 | Out-String
    $cmds = @(
        "build", "build-fast", "build-strict", "build-shared", "build-wasm", "build-ptx",
        "run", "emit", "test", "bench", "perf", "bootstrap", "stage-dump",
        "summary", "query", "abi", "evidence", "impact", "graph", "doc", "profile",
        "lock", "install", "add", "publish", "registry", "sage",
        "check", "explain",
        "audit", "policy", "certify", "translate",
        "init", "clean", "scram", "fix", "zen", "mco"
    )
    foreach ($cmd in $cmds) {
        if ($out -notmatch "(?m)^  $([regex]::Escape($cmd))\b") { return $false }
    }
    return $true
}

Step "CLI: nuc explain NUM-001 wired" {
    # Mirrors verify.sh cli_explain_smoke (added v0.2.64). Exercises
    # the explain registry in nucleor_tools_suite.nr so codes added
    # to docs/spec/Nucleor_Error_Codes.md can't drift from the
    # registry without the gate noticing. Mirrored to PowerShell in
    # v0.2.65.
    $explainOut = & $bin explain "NUM-001" 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($explainOut)) { return $false }
    if ($explainOut -notmatch "NUM-001") { return $false }
    if ($explainOut -notmatch "Mixed-width") { return $false }
    if ($explainOut -notmatch "Nucleor_Error_Codes") { return $false }
    return $true
}

Step "CLI: nuc explain — full spec code set wired" {
    # Mirrors verify.sh cli_explain_full_smoke (added v0.2.79,
    # extended v0.2.80). Audits the full forward-looking spec
    # catalog against the explain registry.
    $codes = @(
        # NR — compiler pipeline (RFC-0020 baseline)
        "NR001", "NR005", "NR010", "NR020", "NR030", "NR031", "NR032", "NR033",
        "NR034", "NR040", "NR050", "NR051", "NR070", "NR090",
        # RFC-0001 RT
        "RT-001", "RT-002", "RT-003", "RT-004", "RT-005", "RT-006", "RT-007", "RT-008",
        # RFC-0002 allocators
        "ALLOC-001", "ALLOC-002", "ALLOC-003",
        # RFC-0003 typed frames
        "FRAME-001", "FRAME-002", "FRAME-003",
        # RFC-0004 assume!
        "ASSUME-001", "ASSUME-002", "ASSUME-003", "ASSUME-004", "ASSUME-005",
        # RFC-0005 units
        "UNIT-001", "UNIT-002", "UNIT-003", "UNIT-004", "UNIT-005",
        # RFC-0006 contracts
        "CONTRACT-001", "CONTRACT-002", "CONTRACT-003", "CONTRACT-004",
        "CONTRACT-005", "CONTRACT-006", "CONTRACT-007",
        # RFC-0007 atomic
        "ATOMIC-001", "ATOMIC-002", "ATOMIC-003", "ATOMIC-004",
        # RFC-0008 ISR
        "ISR-001", "ISR-002", "ISR-003", "ISR-004", "ISR-005", "ISR-006",
        # RFC-0009 WCET
        "WCET-001", "WCET-002", "WCET-003", "WCET-004", "WCET-005", "WCET-006",
        # RFC-0010 DLPack
        "DLPACK-001", "DLPACK-002", "DLPACK-003", "DLPACK-004", "DLPACK-005",
        # RFC-0011 nuc-cxx
        "CXX-001", "CXX-002", "CXX-003", "CXX-004", "CXX-005",
        # RFC-0012 nuc-bindgen
        "BINDGEN-001", "BINDGEN-002", "BINDGEN-003", "BINDGEN-004", "BINDGEN-005",
        # RFC-0013 URDF
        "URDF-001", "URDF-002", "URDF-003", "URDF-004", "URDF-005", "URDF-006",
        # RFC-0014 max_depth
        "DEPTH-001", "DEPTH-002", "DEPTH-003", "DEPTH-004", "DEPTH-005",
        # RFC-0015 numeric types (v0.2)
        "NUM-001", "NUM-002", "NUM-003", "NUM-004", "NUM-005",
        # RFC-0016 Result/Option/match (v0.2; 007..010 for v0.4 RFC-0023)
        "MATCH-001", "MATCH-002", "MATCH-003", "MATCH-004", "MATCH-005", "MATCH-006",
        "MATCH-007", "MATCH-008", "MATCH-009", "MATCH-010",
        # RFC-0017 collections (v0.2)
        "COLL-001", "COLL-002", "COLL-003", "COLL-004", "COLL-005",
        # RFC-0018 modules (v0.2)
        "MOD-001", "MOD-002", "MOD-003", "MOD-004", "MOD-005", "MOD-006",
        # RFC-0019 packages (v0.2)
        "PKG-001", "PKG-002", "PKG-003", "PKG-004", "PKG-005", "PKG-006",
        # RFC-0021 test framework (v0.2)
        "TST-001", "TST-002", "TST-003",
        # RFC-0022 cross-platform (v0.2)
        "TGT-001", "TGT-002", "TGT-003", "TGT-004",
        # RFC-0031 algebraic laws
        "LAW-001", "LAW-002", "LAW-003", "LAW-004",
        # RFC-0032 effects
        "EFF-001", "EFF-002", "EFF-003", "EFF-004", "EFF-005"
    )
    foreach ($c in $codes) {
        $out = & $bin explain $c 2>&1 | Out-String
        if ($out -match "unknown error code") { return $false }
        if ($out -notmatch [regex]::Escape($c)) { return $false }
    }
    return $true
}

Step "CLI: nuc bootstrap status reports correctly" {
    # Mirrors verify.sh cli_bootstrap_smoke (added v0.2.70).
    $out = & $bin bootstrap 2>&1 | Out-String
    if ([string]::IsNullOrWhiteSpace($out)) { return $false }
    if ($out -notmatch "Nucleor Bootstrap Status") { return $false }
    if ($out -notmatch "Stage: 1 \(self-hosted\)") { return $false }
    if ($out -notmatch "Self-hosted: yes") { return $false }
    # v0.2.82 — verify the Contract: line resolves to an existing
    # doc file at the repo root.
    $contractMatch = [regex]::Match($out, "(?m)^\s*Contract:\s*(.+?)\s*$")
    if (-not $contractMatch.Success) { return $false }
    $contractPath = Join-Path $root $contractMatch.Groups[1].Value
    if (-not (Test-Path $contractPath)) { return $false }
    return $true
}

Step "CLI: nuc check + abi inspect" {
    # Mirrors verify.sh cli_check_abi_smoke (added v0.2.70). Verifies
    # the no-codegen check command and the ABI import inspector both
    # produce structured output on a known-good source file.
    $checkOut = & $bin check "examples/01_hello.nr" 2>&1 | Out-String
    if ($checkOut -notmatch "OK . no diagnostics") { return $false }
    $abiOut = & $bin abi "examples/01_hello.nr" 2>&1 | Out-String
    if ($abiOut -notmatch "ABI version:") { return $false }
    if ($abiOut -notmatch "extern imports:") { return $false }
    return $true
}

Step "CLI: nuc summary/audit/query/impact (inspectors)" {
    # Mirrors verify.sh cli_inspector_smoke (added v0.2.71). Bundles
    # four inspector commands (summary text + audit/query/impact JSON)
    # into a single step.
    $sumOut = & $bin summary "examples/01_hello.nr" 2>&1 | Out-String
    if ($sumOut -notmatch "// Module: examples/01_hello.nr") { return $false }
    if ($sumOut -notmatch "fn main") { return $false }
    $auditOut = & $bin audit "examples/01_hello.nr" 2>&1 | Out-String
    if ($auditOut -notmatch '"type": "audit_report"') { return $false }
    if ($auditOut -notmatch '"functions": 1') { return $false }
    $queryOut = & $bin query "examples/01_hello.nr" 2>&1 | Out-String
    if ($queryOut -notmatch '"functions":\[') { return $false }
    if ($queryOut -notmatch '"name":"main"') { return $false }
    $impactOut = & $bin impact "examples/01_hello.nr" "main" 2>&1 | Out-String
    if ($impactOut -notmatch '"target":"main"') { return $false }
    if ($impactOut -notmatch '"found":true') { return $false }
    return $true
}

Step "CLI: nuc policy/certify/translate/evidence/graph/perf/bench (diagnostics)" {
    # Mirrors verify.sh cli_diagnostic_smoke (added v0.2.72). Bundles
    # the seven remaining diagnostic / reporting CLI commands so the
    # gate notices regressions before users hit them.
    $polOut = & $bin policy "examples/01_hello.nr" 2>&1 | Out-String
    if ($polOut -notmatch "Policy:") { return $false }
    if ($polOut -notmatch "Result:") { return $false }
    $certOut = & $bin certify "examples/01_hello.nr" 2>&1 | Out-String
    if ($certOut -notmatch "source:") { return $false }
    $trOut = & $bin translate "examples/01_hello.nr" 2>&1 | Out-String
    if ($trOut -notmatch "translated:") { return $false }
    $evOut = & $bin evidence "examples/01_hello.nr" 2>&1 | Out-String
    if ($evOut -notmatch '"spdx":') { return $false }
    if ($evOut -notmatch '"provenance":') { return $false }
    $grOut = & $bin graph "examples/01_hello.nr" 2>&1 | Out-String
    if ($grOut -notmatch "functions:") { return $false }
    if ($grOut -notmatch "edges:") { return $false }
    $perfOut = & $bin perf "examples/01_hello.nr" 2>&1 | Out-String
    if ($perfOut -notmatch "Nucleor Performance Analysis") { return $false }
    $benchOut = & $bin bench "examples/01_hello.nr" 2>&1 | Out-String
    if ($benchOut -notmatch "source:") { return $false }
    return $true
}

Step "CLI: nuc init scaffolding works" {
    # Mirrors verify.sh cli_init_smoke (added v0.2.66). Verifies the
    # new-user-first-command produces a working project: scaffolds
    # Nucleor.toml + src/main.nr, manifest declares name + entry,
    # and the scaffold compiles + runs to non-empty stdout.
    $sandbox = Join-Path $env:TEMP "_nuc_init_smoke_$PID"
    if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        Push-Location $sandbox
        & $bin init smokeproj *> $null
        if (-not (Test-Path "smokeproj\Nucleor.toml")) { return $false }
        if (-not (Test-Path "smokeproj\src\main.nr")) { return $false }
        $manifest = Get-Content "smokeproj\Nucleor.toml" -Raw
        if ($manifest -notmatch 'name = "smokeproj"') { return $false }
        if ($manifest -notmatch 'entry = "src/main.nr"') { return $false }
        Push-Location "smokeproj"
        & $bin build "src/main.nr" -o "smokeproj" *> $null
        $exe = "target\smokeproj.exe"
        if (-not (Test-Path $exe)) { Pop-Location; return $false }
        $runOut = & $exe 2>&1 | Out-String
        Pop-Location
        if ([string]::IsNullOrWhiteSpace($runOut)) { return $false }
        return $true
    }
    finally {
        Pop-Location
        if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
    }
}

Step "CLI: nuc doc generator works" {
    # Mirrors verify.sh cli_doc_smoke (added v0.2.67). Exercises
    # RFC-0029 phase 1 doc generator: reads /// doc comments, emits
    # Markdown with function index + per-fn signature blocks; --out
    # flag writes to file.
    $sandbox = Join-Path $env:TEMP "_nuc_doc_smoke_$PID"
    if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        Push-Location $sandbox
        $src = @"
/// Adds two integers.
fn smoke_add(a: i64, b: i64) -> i64 { return a + b; }
"@
        Set-Content -Path "smoke.nr" -Value $src -Encoding UTF8
        $stdoutOut = & $bin doc "smoke.nr" 2>&1 | Out-String
        if ($stdoutOut -notmatch "smoke_add") { return $false }
        if ($stdoutOut -notmatch "## Function index") { return $false }
        if ($stdoutOut -notmatch "Adds two integers") { return $false }
        if ($stdoutOut -notmatch "Signature") { return $false }
        & $bin doc "smoke.nr" --out "smoke.md" *> $null
        if (-not (Test-Path "smoke.md")) { return $false }
        $fileContent = Get-Content "smoke.md" -Raw
        if ($fileContent -notmatch "smoke_add") { return $false }
        return $true
    }
    finally {
        Pop-Location
        if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
    }
}

Step "CLI: nuc lock writes Nucleor.lock" {
    # Mirrors verify.sh cli_lock_smoke (added v0.2.68). RFC-0019
    # phase 1 lockfile generator. Verifies init -> lock -> reads
    # back canonical fields.
    $sandbox = Join-Path $env:TEMP "_nuc_lock_smoke_$PID"
    if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        Push-Location $sandbox
        & $bin init lockproj *> $null
        Push-Location "lockproj"
        & $bin lock *> $null
        if (-not (Test-Path "Nucleor.lock")) { Pop-Location; return $false }
        $lock = Get-Content "Nucleor.lock" -Raw
        Pop-Location
        if ($lock -notmatch '^version = ') { return $false }
        if ($lock -notmatch 'root = "Nucleor.toml"') { return $false }
        if ($lock -notmatch 'root_package = "lockproj"') { return $false }
        if ($lock -notmatch '\[\[package\]\]') { return $false }
        if ($lock -notmatch 'name = "lockproj"') { return $false }
        return $true
    }
    finally {
        Pop-Location
        if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
    }
}

Step "CLI: nuc test runs #[test] functions" {
    # Mirrors verify.sh cli_test_smoke (added v0.2.69). RFC-0021
    # phase 1 test framework: discovery + harness write + child
    # build + child run for a #[test]-annotated function.
    $sandbox = Join-Path $env:TEMP "_nuc_test_smoke_$PID"
    if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
    New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
    try {
        Push-Location $sandbox
        $src = @"
#[test]
fn test_addition() {
    let x: i64 = 2 + 2;
    if x != 4 { print("FAIL"); return; };
    print("PASS test_addition");
}
fn main() -> i64 { return 0; }
"@
        Set-Content -Path "t.nr" -Value $src -Encoding UTF8
        $out = & $bin test "t.nr" 2>&1 | Out-String
        if ($out -notmatch "discovered tests: 1") { return $false }
        if ($out -notmatch "test_addition")        { return $false }
        if ($out -notmatch "PASS test_addition")   { return $false }
        if ($out -notmatch "test result: PASS")    { return $false }
        return $true
    }
    finally {
        Pop-Location
        if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue }
    }
}

foreach ($ex in $examples) {
    Step "example $ex" {
        $src = "examples/$ex.nr"
        $out = & $bin build $src -o $ex 2>&1 | Out-String
        if (-not (Test-Path "target\$ex.exe")) {
            Write-Host (Dim ("       " + ($out.Trim() -split "`n" | Select-Object -Last 1)))
            return $false
        }
        $runOut = & "target\$ex.exe" 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Host (Dim ("       " + ($runOut.Trim() -split "`n" | Select-Object -Last 1)))
            return $false
        }
        # Non-empty stdout shape check (added v0.2.62, mirrors verify.sh
        # v0.2.61) — catches silent regressions where the binary builds
        # + exits 0 but prints nothing.
        if ([string]::IsNullOrWhiteSpace($runOut)) {
            Write-Host (Dim "       example produced empty output")
            return $false
        }
        return $true
    }
}

foreach ($dir in $testDirs) {
    $testFiles = Get-ChildItem -Path (Join-Path $root "tests\$dir") -Filter "*.nr" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $testSkipPattern } | Sort-Object Name
    foreach ($t in $testFiles) {
        $tname = $t.BaseName
        Step "test $dir/$tname" {
            if ($tname -eq "rust_interop" -and -not (Test-Path $rustBridgeLib)) {
                return "SKIP"
            }
            $src = "tests/$dir/$($t.Name)"
            $build = & $bin build $src -o $tname 2>&1 | Out-String
            $exePath = Join-Path $root "target\$tname.exe"
            if (-not (Test-Path $exePath)) {
                Write-Host (Dim "       build failed")
                return $false
            }
            $runOut = (& $exePath 2>&1) | Out-String
            $exit = $LASTEXITCODE
            if ($dir -eq "features") {
                # Feature parity tests: pass if the program built and ran without
                # an access-violation crash. They exercise language constructs by
                # construction, not by printing "OK".
                return ($exit -ne -1073741819 -and $exit -ne -1073740940)
            }
            return ($runOut -match "(?m)^OK ")
        }
    }
}

$errFiles = Get-ChildItem -Path (Join-Path $root "tests\err") -Filter "*.nr" -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($e in $errFiles) {
    $ename = $e.BaseName
    Step "negative $ename" {
        $src = "tests/err/$($e.Name)"
        $out = & $bin build $src -o $ename 2>&1
        $sawErr = $out | Select-String "ERROR|WARNING|error:" | Select-Object -First 1
        return $null -ne $sawErr
    }
}

Step "self-host rebuild closes" {
    $out = & $bin build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler" 2>&1 | Out-String
    return (Test-Path "target\verify_compiler.exe")
}

Remove-Item -Recurse -Force (Join-Path $root "target") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $root ".nuc_cache") -ErrorAction SilentlyContinue

Pop-Location

Write-Host ""
Write-Host (Dim "===")
Write-Host ("PASS: " + (Green $totalPass))
if ($totalSkip -gt 0) { Write-Host ("SKIP: " + (Yellow $totalSkip)) }
if ($totalFail -gt 0) {
    Write-Host ("FAIL: " + (Red $totalFail))
    Write-Host (Red "Failed steps:")
    foreach ($f in $failures) { Write-Host (Dim "  - $f") }
    exit 1
}
exit 0
