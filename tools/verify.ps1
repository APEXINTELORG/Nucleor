# verify.ps1 — Windows smoke gate for the Nucleor OSS distribution.
# Mirrors tools/verify.sh — same step counter, same exit code, same gates.
#
# Usage: powershell.exe -ExecutionPolicy Bypass -File tools\verify.ps1
#
# Step shape (203 steps total as of v0.2.111):
#   1.  Binary present + loads
#   2.  ABI parity (s1 ↔ tools-suite, via WSL bash if available)
#   3.  Tools-suite rebuild (since v0.2.79)
#   4.  Mojibake clean (since v0.2.91, via bash if available)
#   5.  Help-coverage (since v0.2.84) — every dispatched cmd in `nuc help`
#   6.  Utility smoke (zen / mco / registry / stage-dump / fix; v0.2.85)
#   7.  JSON-flag smoke (11 commands; v0.2.86)
#   8.  Version aliases (--version / -v / -V / version; v0.2.87)
#   9.  Showcase build (lorenz / vqe_h2 / market_maker / wing_simulator; v0.2.90)
#   10. CLI: explain NUM-001 (single quick-fail canary; v0.2.64/v0.2.65)
#   11. CLI: explain — full 130-code spec catalog (v0.2.79+v0.2.80)
#   12. CLI: bootstrap status + Contract: file resolves (v0.2.70+v0.2.82)
#   13. CLI: check + abi inspect (v0.2.70)
#   14. CLI: summary/audit/query/impact (inspectors; v0.2.71)
#   15. CLI: policy/certify/translate/evidence/graph/perf/bench (diagnostics; v0.2.72)
#   16. CLI: init scaffolding (v0.2.66)
#   17. CLI: doc generator (v0.2.67)
#   18. CLI: lock writes Nucleor.lock (v0.2.68)
#   19. CLI: test runs #[test] functions (v0.2.69)
#   20..N. Build + run every example under examples/
#   N+1.. Build + run every positive test under tests\{lang,attrs,runtime,rods,features}
#   ...   Confirm every tests\err\*.nr fails with at least a diagnostic line
#   final Self-host rebuild closes (compile s1 source via current binary)
#
# Exit code: 0 = ship-ready; 1 = a step failed.
#
# Output: progress counter [N/T] per step, colored OK/FAIL/SKIP labels when
# stdout is a TTY. Honors NO_COLOR (https://no-color.org/) and --no-color.

param(
    [switch]$NoColor
)

$ErrorActionPreference = "Continue"

# T1.1 safety: cap process working set / commit at 2 GB so a runaway
# compile or test fails fast. Healthy compiles are sub-1 GB; the prior
# blowups we hunted hit ~20 GB, so 2 GB is the right "alarm" threshold.
# Override via env NUCLEOR_MEM_CAP_MB (units: MB; "0" = no cap).
if (-not $env:NUCLEOR_MEM_CAP_MB) { $env:NUCLEOR_MEM_CAP_MB = "2048" }
if ($env:NUCLEOR_MEM_CAP_MB -ne "0") {
    try {
        $proc = [System.Diagnostics.Process]::GetCurrentProcess()
        # MaxWorkingSet is a soft cap (Windows can grow past on memory
        # pressure) — sufficient hint to fail fast on multi-GB compiles.
        $cap_bytes = [int64]$env:NUCLEOR_MEM_CAP_MB * 1MB
        $proc.MaxWorkingSet = [System.IntPtr]::new($cap_bytes)
    } catch {
        # Soft-fail; some Windows hosts don't allow setting WS limits.
    }
}

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

# Force UTF-8 console encoding so multibyte characters (em-dash, box-drawing
# glyphs, etc.) round-trip cleanly through Out-String. This is required even
# in -NoColor mode — several Step bodies regex-match text that contains
# em-dashes ("OK — no diagnostics", "ERROR — ..."), and without UTF-8 the
# bytes get reinterpreted as the Windows OEM codepage and the regex misses.
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
try { [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new() } catch { }

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
# 1 (mojibake check) + 1 (err-EXPECT-headers) + 1 (help coverage)
# + 1 (utility smoke) + 1 (json smoke) + 1 (version aliases) +
# 1 (showcase build) + 1 (CLI explain smoke) + 1 (explain-full) +
# 1 (bootstrap) + 1 (check+abi) + 1 (inspectors) + 1 (diagnostics)
# + 1 (init) + 1 (doc) + 1 (lock) + 1 (test) + N examples +
# N tests + N err + 1 (self-host) + 1 T1.3 + 1 T1.9 + 1 FFI smoke
# + 1 self-host fixpoint + 1 T1.7 bootstrap seed
$stepTotal = 20 + $examples.Count + $testCount + $errCount + 107 # +1 T1.8, +4 RFC-NRT-004 §A/§B/§C/stress (v0.3.235), +3 RFC-NRT-004 §F/§D/§H (v0.4.1), +1 RFC-NRT-004 §G (v0.4.2), +1 Option<str> bind (v0.4.4), +1 RFC-NRT-001 .nucprov (v0.4.5), +1 extern-redecl-diag (v0.4.6), +1 RFC-NRT-003 verify-reproducible (v0.4.7), +1 Option<str> macro path (v0.4.9), +1 Option<MyStruct> bare-ident (v0.4.11)

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

Step "no UTF-8 mojibake in source/docs" {
    # Mirrors verify.sh mojibake_clean (added v0.2.91). Shells out
    # to tools/check_mojibake.sh because grepping raw byte sequences
    # is bash-native and the PowerShell equivalent would be slower
    # and error-prone. Skips silently if bash isn't available
    # (Windows host without Git for Windows / msys2).
    $bash = $env:NUCLEOR_BASH_PATH
    if (-not $bash -or -not (Test-Path $bash)) {
        if (Test-Path "C:\Program Files\Git\bin\bash.exe") {
            $bash = "C:\Program Files\Git\bin\bash.exe"
        } elseif (Test-Path "C:\msys64\usr\bin\bash.exe") {
            $bash = "C:\msys64\usr\bin\bash.exe"
        } else {
            return $true
        }
    }
    & $bash (Join-Path $root "tools\check_mojibake.sh") *> $null
    return ($LASTEXITCODE -eq 0)
}

Step "tests/err/*.nr have EXPECT headers" {
    # Mirrors verify.sh err_tests_have_expect_smoke (added v0.2.118).
    # Locks down the v0.2.117 bulk-add (33/33 tests headerized).
    $missing = @()
    foreach ($f in (Get-ChildItem -Path (Join-Path $root "tests\err") -Filter "*.nr" -ErrorAction SilentlyContinue)) {
        $head = (Get-Content $f.FullName -TotalCount 3) -join "`n"
        if ($head -notmatch "(?m)^// EXPECT:") {
            $missing += $f.Name
        }
    }
    if ($missing.Count -gt 0) {
        return $false
    }
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
        # OWN series — borrow checker (expansion of NR031, since v0.2.119;
        # OWN-013 added v0.2.131 — spawn-capture for non-Send DeviceBuffer)
        "OWN-001", "OWN-002", "OWN-003", "OWN-004", "OWN-005", "OWN-006",
        "OWN-007", "OWN-008", "OWN-009", "OWN-010", "OWN-011", "OWN-012",
        "OWN-013",
        # GOV series — governance policies (since v0.2.131)
        "GOV-001", "GOV-002",
        # TNT series — taint analysis (expansion of NR033, since v0.2.120)
        "TNT-001",
        # TYP series — type checker (expansion of NR030, since v0.2.119)
        "TYP-001", "TYP-002", "TYP-003", "TYP-004", "TYP-005",
        "TYP-006", "TYP-007", "TYP-008", "TYP-009", "TYP-010",
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
        # T1.1 Phase 10 (v0.2.319): expanded NUM namespace.
        "NUM-006", "NUM-007", "NUM-008", "NUM-009", "NUM-010",
        "NUM-011", "NUM-012", "NUM-013", "NUM-014", "NUM-015",
        "NUM-016", "NUM-017", "NUM-018", "NUM-019", "NUM-020",
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
        "EFF-001", "EFF-002", "EFF-003", "EFF-004", "EFF-005",
        # RFC-0020 DIAG (minted v0.3.36 -- first DIAG-NNN code)
        "DIAG-001"
    )
    foreach ($c in $codes) {
        $out = & $bin explain $c 2>&1 | Out-String
        if ($out -match "unknown error code") { return $false }
        if ($out -notmatch [regex]::Escape($c)) { return $false }
        # v0.3.41: tightened from synopsis-only to full-entry
        # check. explain_error_known() only checks title; a code
        # with title but missing summary or explanation passed
        # silently. Now also assert the cause line (2) and hint
        # line (3) are non-empty -- catches drift where a
        # contributor adds a code to the title registry but
        # forgets the matching summary or explanation entry.
        $lines = $out -split "`r?`n"
        if ($lines.Length -lt 4) {
            Write-Host ("       " + $c + ": explain output has fewer than 4 lines (missing summary or explanation)")
            return $false
        }
        if ([string]::IsNullOrWhiteSpace($lines[1])) {
            Write-Host ("       " + $c + ": missing cause/summary line in explain output")
            return $false
        }
        if ([string]::IsNullOrWhiteSpace($lines[2])) {
            Write-Host ("       " + $c + ": missing hint/explanation line in explain output")
            return $false
        }
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
        # --no-cache: see v0.3.26 — diagnostic-dependent tests must
        # skip the source cache, or a stale .nuc_cache silently
        # swallows the error/warning the assertion is grepping for.
        $out = & $bin build $src -o $ename --no-cache 2>&1
        $sawErr = $out | Select-String "ERROR|WARNING|error:" | Select-Object -First 1
        return $null -ne $sawErr
    }
}

Step "self-host rebuild closes" {
    $out = & $bin build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler" 2>&1 | Out-String
    return (Test-Path "target\verify_compiler.exe")
}

# T1.1 (v0.2.309+): bootstrap-stability check. The compiler change must
# be FIXPOINT — compiling the source twice in succession must produce
# the same binary. Prevents the class of bug where a compiler change
# silently poisons the next compile (Phase 1's narrow_via_as truncating
# stdlib's `let val: i32 = n` for str_from_int was caught this way).
Step "T1.3 HashMap + String smoke" {
    # T1.3 (v0.2.338): HashMap (string-keyed i64 + open-addressed) +
    # String (heap-owned mutable UTF-8) round-trip via nuc test.
    # Exercises the harness #cfile-import bridge fix.
    $src = Join-Path $root "tests\smoke\t13_hashmap_string.nr"
    if (-not (Test-Path $src)) { return $false }
    $out = & $bin test $src 2>&1 | Out-String
    if ($out -notmatch "PASS: test_string_make_and_push") { return $false }
    if ($out -notmatch "PASS: test_hashmap_insert_get") { return $false }
    if ($out -notmatch "PASS: test_hashmap_overwrite") { return $false }
    if ($out -notmatch "PASS: test_hms_open_addressed") { return $false }
    if ($out -notmatch "test result: PASS \(6 tests\)") { return $false }
    return $true
}

Step "T1.9 nuc test framework smoke" {
    # Verifies `nuc test` discovers #[test] functions and reports PASS
    # for each. The harness fixture is `tests/smoke/t19_test_framework.nr`.
    $src = Join-Path $root "tests\smoke\t19_test_framework.nr"
    if (-not (Test-Path $src)) { return $false }
    $out = & $bin test $src 2>&1 | Out-String
    if ($out -notmatch "PASS: test_arithmetic_addition") { return $false }
    if ($out -notmatch "PASS: test_arithmetic_subtraction") { return $false }
    if ($out -notmatch "PASS: test_assert_ne_distinct") { return $false }
    if ($out -notmatch "PASS: test_division") { return $false }
    if ($out -notmatch "PASS: test_narrow_wrap_u8_in_test_fn") { return $false }
    if ($out -notmatch "test result: PASS \(5 tests\)") { return $false }
    return $true
}

Step "nuc gen-headers FFI smoke" {
    # T1.1 Phase 9 (v0.2.318): nuc gen-headers should turn an .nr
    # file's extern fn declarations into a matching C header. This
    # smoke verifies the subcommand exists, accepts narrow types,
    # and emits a header containing every extern decl.
    $nrf = Join-Path $root "target\_genh_demo.nr"
    @"
extern fn frob_u8(x: u8, y: u32) -> i64;
extern fn frob_f32(a: f32, b: f64) -> f32;
extern fn frob_void();
fn main() -> i64 { return 0; }
"@ | Out-File -FilePath $nrf -Encoding ASCII
    $hdr = Join-Path $root "target\_genh_demo.h"
    & $bin gen-headers $nrf -o $hdr 2>&1 | Out-Null
    if (-not (Test-Path $hdr)) { return $false }
    $h = Get-Content $hdr -Raw
    if ($h -notmatch "uint8_t") { return $false }
    if ($h -notmatch "uint32_t") { return $false }
    if ($h -notmatch "float frob_f32") { return $false }
    if ($h -notmatch "void frob_void\(void\)") { return $false }
    return $true
}

Step "self-host bootstrap fixpoint (stage-2)" {
    if (-not (Test-Path "target\verify_compiler.exe")) { return $false }
    $out = & "target\verify_compiler.exe" build "compiler/nucleor_s1_compiler.nr" -o "verify_compiler_2" 2>&1 | Out-String
    if (-not (Test-Path "target\verify_compiler_2.exe")) { return $false }
    # Stage-2 must compile the same hand-rolled smoke that the stage-1
    # binary compiles. Cheap proxy: same byte-size of the emitted IR for
    # a trivial test. (Stronger: exact-match diff; deferred to v0.2.310+.)
    $smoke = "tests\lang\arith.nr"
    & $bin build $smoke -o "_boot_s1" 2>&1 | Out-Null
    & "target\verify_compiler_2.exe" build $smoke -o "_boot_s2" 2>&1 | Out-Null
    $s1 = "target\_boot_s1.ll"; $s2 = "target\_boot_s2.ll"
    if (-not (Test-Path $s1) -or -not (Test-Path $s2)) { return $false }
    $h1 = (Get-FileHash $s1 -Algorithm SHA256).Hash
    $h2 = (Get-FileHash $s2 -Algorithm SHA256).Hash
    return $h1 -eq $h2
}

Step "T3.3 static WCET v1 estimator emits warning[RT-004]" {
    # v0.3.2 take-2 (T3.3): rewritten without nested-while+continue
    # after the prior draft caused a 2960 MB allocation runaway at
    # verify gate step 349. New estimator counts stmts + while
    # keywords with a coarse multiplier ladder + 1e6 stmt cap.
    $out = & $bin build "tests/fixtures/t33_wcet_overrun.nr" -o "_t33_wcet_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-004\]: static WCET estimate \d+ us") { return $false }
    if ($out -notmatch "exceeds #\[deadline = 1 us\]") { return $false }
    if ($out -notmatch "v1 estimator") { return $false }
    return $true
}

Step "T3.5 RT-007 fires when #[deadline] lacks no_alloc/no_panic" {
    # v0.3.3 (T3.5): cross-check that complements RT-004. When a
    # #[deadline] fn has neither #[no_alloc] nor #[no_panic],
    # allocations / panics in the body can blow the budget non-
    # deterministically. Warning, not error — `#[allow(RT-007)]`
    # suppresses for unusual cases.
    $out = & $bin build "tests/fixtures/t35_rt007.nr" -o "_t35_rt007_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-007\]:") { return $false }
    if ($out -notmatch "has #\[deadline\] but neither #\[no_alloc\] nor #\[no_panic\]") { return $false }
    return $true
}

Step "T3.11 bare arena_* builtins link + run end-to-end" {
    # v0.3.11 (T3.11): #[test]-framework coverage for the bare
    # arena_new / arena_alloc / arena_reset / arena_destroy
    # builtin path. The runtime fix shipped in v0.2.154 but the
    # only existing fixture (tests/lang/arena_builtin.nr) was a
    # main-fn shape. This step proves the builtin path works
    # end-to-end through the test framework too.
    $out = & $bin test "tests/smoke/t311_arena_builtin.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_arena_round_trip") { return $false }
    if ($out -notmatch "test result: PASS \(1 test\)") { return $false }
    return $true
}

Step "T3.10 RT-008 fires on direct recursion in deadline fn" {
    # v0.3.9 (T3.10): RFC-0001 RT-008 — direct self-recursion in
    # a #[deadline] fn warns. Bounded recursion opts out via
    # #[max_depth = N]. Two paired fixtures: unbounded fires,
    # bounded stays clean.
    $out = & $bin build "tests/fixtures/t310_rt008_recursion.nr" -o "_t310_rt008_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-008\]: 'fib_unbounded' has #\[deadline\] and recursively calls itself") { return $false }
    if ($out -notmatch "add #\[max_depth") { return $false }
    $out2 = & $bin build "tests/fixtures/t310_rt008_bounded.nr" -o "_t310_bounded_check" --no-cache 2>&1 | Out-String
    if ($out2 -match "RT-008") { return $false }
    return $true
}

Step "T3.15 #[ffi_no_alloc] marker silences RT-005 for that extern" {
    # v0.3.24 (T3.15): per-symbol opt-out for the v0.3.8 RT-005
    # check. Annotated extern stays clean from a #[no_alloc]
    # caller; un-annotated still fires.
    # --no-cache: see T3.16 comment — diagnostic-dependent
    # tests must skip the source cache or they silently pass
    # on stale cache entries.
    $out = & $bin build "tests/fixtures/t324_ffi_no_alloc.nr" -o "_t324_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-005\]: FFI call 'host_unsafe'") { return $false }
    if ($out -match "warning\[RT-005\]: FFI call 'host_safe'") { return $false }
    return $true
}

Step "T3.16 #[deadline] needs BOTH ffi_no_* markers (intersection rule)" {
    # v0.3.26 (T3.16): #[deadline] determinism subsumes both
    # no-alloc and no-panic, so a #[deadline] body considers an
    # extern RT-safe iff it carries BOTH markers (intersection
    # of #[ffi_no_alloc]-marked and #[ffi_no_panic]-marked).
    # Three externs (alloc-only / panic-only / both); a
    # #[deadline] caller invokes all three. Single-marker
    # externs still fire RT-005; the both-marker extern does not.
    #
    # --no-cache: the source cache hit short-circuits the
    # parse/typecheck/emit pipeline that emits RT-005, so a
    # stale .nuc_cache would silently swallow the diagnostic.
    $out = & $bin build "tests/fixtures/t326_ffi_intersection.nr" -o "_t326_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-005\]: FFI call 'h_alloc_only'") { return $false }
    if ($out -notmatch "warning\[RT-005\]: FFI call 'h_panic_only'") { return $false }
    if ($out -match "warning\[RT-005\]: FFI call 'h_both'") { return $false }
    return $true
}

Step "T3.9 RT-005 fires on FFI call from RT fn body" {
    # v0.3.8 (T3.9): RFC-0001 RT-005 — extern fn call from inside
    # an RT-marked fn body warns. v1 is text-scan: every literal
    # `<extern_name>(` substring in the stripped body fires.
    $out = & $bin build "tests/fixtures/t39_rt005_ffi.nr" -o "_t39_rt005_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-005\]: FFI call 'host_telemetry'") { return $false }
    if ($out -notmatch "from #\[no_alloc\] fn 'rt_path'") { return $false }
    return $true
}

Step "T3.26 cli-help cmds drift (verify.sh <-> verify.ps1)" {
    # v0.3.44 (T3.26): drift gate for the cli_help_coverage_smoke
    # cmds list. Both verify.sh and verify.ps1 hardcode the same
    # ~39-entry CLI command set; a new command added to one but
    # forgotten in the other would leave the smoke check half-blind
    # on the corresponding OS.
    $shPath  = Join-Path $root "tools\verify.sh"
    $ps1Path = Join-Path $root "tools\verify.ps1"
    function _ExtractCmds($path, $startPattern) {
        $lines = Get-Content $path
        $inBlock = $false
        $body = New-Object System.Collections.ArrayList
        foreach ($line in $lines) {
            if ($line -match $startPattern) { $inBlock = $true; continue }
            if ($inBlock -and $line -match '^\s*\)\s*$') { $inBlock = $false; continue }
            if ($inBlock) { [void]$body.Add($line) }
        }
        $body | Select-String -AllMatches -Pattern '"([a-z][a-z0-9-]*)"' `
            | ForEach-Object { $_.Matches } `
            | ForEach-Object { $_.Groups[1].Value } `
            | Sort-Object -Unique
    }
    $shCmds  = _ExtractCmds $shPath  '^\s*local cmds=\('
    $psCmds  = _ExtractCmds $ps1Path '^\s*\$cmds = @\('
    $missingFromPs = $shCmds | Where-Object { $psCmds -notcontains $_ }
    $missingFromSh = $psCmds | Where-Object { $shCmds -notcontains $_ }
    if ($missingFromPs) {
        Write-Host ("       drift: cli help cmds in verify.sh but missing from verify.ps1: " + ($missingFromPs -join ", "))
        return $false
    }
    if ($missingFromSh) {
        Write-Host ("       drift: cli help cmds in verify.ps1 but missing from verify.sh: " + ($missingFromSh -join ", "))
        return $false
    }
    return $true
}

Step "T3.25 examples-list drift (examples/*.nr vs examples.list)" {
    # v0.3.43 (T3.25): drift gate for tools/examples.list against
    # the actual examples/ directory. Every .nr file in examples/
    # must appear in examples.list, OR be in the explicit
    # conditional allowlist (07_rust_interop is added by both
    # verify scripts only when RUST_BRIDGE_LIB is set).
    $exDir = Join-Path $root "examples"
    $listPath = Join-Path $root "tools\examples.list"
    $dirSet = Get-ChildItem -Path $exDir -Filter "*.nr" -ErrorAction SilentlyContinue `
        | ForEach-Object { $_.BaseName } `
        | Sort-Object -Unique
    $listSet = Get-Content $listPath `
        | Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' } `
        | ForEach-Object { $_.Trim() } `
        | Sort-Object -Unique
    # Conditional allowlist — mirror in verify.sh's t325_examples_list_drift.
    $allowed = @($listSet) + @("07_rust_interop") | Sort-Object -Unique
    $extras = $dirSet | Where-Object { $allowed -notcontains $_ }
    if ($extras) {
        Write-Host ("       drift: examples/*.nr not in examples.list (or conditional allowlist): " + ($extras -join ", "))
        return $false
    }
    $missing = $listSet | Where-Object { $dirSet -notcontains $_ }
    if ($missing) {
        Write-Host ("       drift: examples.list entries with no matching examples/*.nr file: " + ($missing -join ", "))
        return $false
    }
    return $true
}

Step "T3.24 spec-doc drift (canonical codes vs Nucleor_Error_Codes.md)" {
    # v0.3.42 (T3.24): drift gate against the spec doc Markdown
    # table. Every canonical code (verify.ps1 codes array) must
    # appear in the spec doc; every spec doc code must be in the
    # canonical set. Catches the drift class that left
    # NUM-006..020 missing from the spec for ~80 ships after
    # their v0.2.319 introduction.
    $shPath   = Join-Path $root "tools\verify.ps1"
    $specPath = Join-Path $root "docs\spec\Nucleor_Error_Codes.md"
    function _ExtractCanonical($path) {
        $lines = Get-Content $path
        $inBlock = $false
        $body = New-Object System.Collections.ArrayList
        foreach ($line in $lines) {
            if ($line -match '^\s*\$codes\s*=\s*@\(') { $inBlock = $true; continue }
            if ($inBlock -and $line -match '^\s*\)\s*$') { $inBlock = $false; continue }
            if ($inBlock) { [void]$body.Add($line) }
        }
        $body | Select-String -AllMatches -Pattern '"([A-Z]+-?[0-9]+)"' `
            | ForEach-Object { $_.Matches } `
            | ForEach-Object { $_.Groups[1].Value } `
            | Sort-Object -Unique
    }
    $canon = _ExtractCanonical $shPath
    $spec = Get-Content $specPath `
        | Select-String -AllMatches -Pattern '\| (NR[0-9]+|[A-Z]+-[0-9]+) \|' `
        | ForEach-Object { $_.Matches } `
        | ForEach-Object { $_.Groups[1].Value } `
        | Sort-Object -Unique
    $missingFromSpec  = $canon | Where-Object { $spec  -notcontains $_ }
    $missingFromCanon = $spec  | Where-Object { $canon -notcontains $_ }
    if ($missingFromSpec) {
        Write-Host ("       drift: codes in canonical set but missing from spec doc: " + ($missingFromSpec -join ", "))
        return $false
    }
    if ($missingFromCanon) {
        Write-Host ("       drift: codes in spec doc but missing from canonical set: " + ($missingFromCanon -join ", "))
        return $false
    }
    return $true
}

Step "T3.23 diag-code drift (s1 is_known_diag_code vs smoke list)" {
    # v0.3.39 (T3.23, extended v0.3.40): three-way drift gate
    # for the parallel canonical diagnostic code lists. The set
    # lives in THREE places: is_known_diag_code in s1, the local
    # codes=(...) array in verify.sh, the $codes = @(...) array
    # in verify.ps1. v0.3.39 caught s1 vs same-script drift;
    # v0.3.40 closes the cross-script gap (the original
    # NUM-006..020 gap was sh-vs-ps1 drift, which same-script
    # checks can't see). Asserts all three sets pairwise equal.
    $s1Path  = Join-Path $root "compiler\nucleor_s1_compiler.nr"
    $shPath  = Join-Path $root "tools\verify.sh"
    $ps1Path = Join-Path $root "tools\verify.ps1"
    function _ExtractBlock($path, $startPattern) {
        $lines = Get-Content $path
        $inBlock = $false
        $body = New-Object System.Collections.ArrayList
        foreach ($line in $lines) {
            if ($line -match $startPattern) { $inBlock = $true; continue }
            if ($inBlock -and $line -match '^\s*\)\s*$') { $inBlock = $false; continue }
            if ($inBlock) { [void]$body.Add($line) }
        }
        $body | Select-String -AllMatches -Pattern '"([A-Z]+-?[0-9]+)"' `
            | ForEach-Object { $_.Matches } `
            | ForEach-Object { $_.Groups[1].Value } `
            | Sort-Object -Unique
    }
    $s1Codes = Get-Content $s1Path `
        | Select-String -AllMatches -Pattern 'str_eq\(code,\s*"([A-Z]+-?[0-9]+)"\)' `
        | ForEach-Object { $_.Matches } `
        | ForEach-Object { $_.Groups[1].Value } `
        | Sort-Object -Unique
    $shCodes  = _ExtractBlock $shPath  '^\s*local codes=\('
    $ps1Codes = _ExtractBlock $ps1Path '^\s*\$codes\s*=\s*@\('
    function _DriftDiff($labelA, $labelB, $setA, $setB) {
        $missing = $setA | Where-Object { $setB -notcontains $_ }
        if ($missing) {
            Write-Host ("       drift: codes in {0} but missing from {1}: {2}" -f $labelA, $labelB, ($missing -join ", "))
            return $false
        }
        return $true
    }
    if (-not (_DriftDiff "verify.sh"          "is_known_diag_code" $shCodes  $s1Codes))  { return $false }
    if (-not (_DriftDiff "is_known_diag_code" "verify.sh"          $s1Codes  $shCodes))  { return $false }
    if (-not (_DriftDiff "verify.ps1"         "is_known_diag_code" $ps1Codes $s1Codes))  { return $false }
    if (-not (_DriftDiff "is_known_diag_code" "verify.ps1"         $s1Codes  $ps1Codes)) { return $false }
    if (-not (_DriftDiff "verify.sh"          "verify.ps1"         $shCodes  $ps1Codes)) { return $false }
    if (-not (_DriftDiff "verify.ps1"         "verify.sh"          $ps1Codes $shCodes))  { return $false }
    return $true
}

Step "T3.21 #[allow(DIAG-001)] suppresses DIAG-001 itself" {
    # v0.3.37 (T3.21, tightened v0.3.47): #[allow(DIAG-001)]
    # suppresses DIAG-001 itself. Fixture has #[allow(WAT-001)]
    # (would fire DIAG-001 for the WAT- unknown prefix) plus a
    # file-wide #[allow(DIAG-001)]. The suppression pass runs
    # AFTER the emit pass, so the DIAG-001 warning gets dropped
    # before reaching the user.
    #
    # v0.3.47: tightened from 'no DIAG-001 fires' to a real
    # three-way assertion -- build exits 0, no warning fires,
    # no error fires (catches a regression that promotes
    # DIAG-001 to error tier and bypasses the warning suppressor).
    $out = & $bin build "tests/fixtures/t321_diag001_self_suppress.nr" -o "_t321_diag001_self_check" --no-cache 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($out -match "warning\[DIAG-001\]") { return $false }
    if ($out -match "error\[DIAG-001\]") { return $false }
    return $true
}

Step "T3.56 indexed-LHS assignment lowers to vec_set (was diag-only pre-v0.3.124)" {
    # v0.3.124 (T3.56): real `v[i] = X` codegen replaces the
    # v0.3.81 diag-only stub. Fixture exits 999 when the assignment
    # actually mutates (instead of being silently dropped).
    & $bin build "tests/fixtures/t356_indexed_lhs_diagnostic.nr" -o "_t356_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t356_check.exe") { $exe = "target\_t356_check.exe" }
    elseif (Test-Path "target\_t356_check") { $exe = "target\_t356_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    return $LASTEXITCODE -eq 999
}

Step "T3.74 env_get_or runtime helper" {
    & $bin build "tests/fixtures/t374_env_get_or.nr" -o "_t374_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t374_check.exe") { $exe = "target\_t374_check.exe" }
    elseif (Test-Path "target\_t374_check") { $exe = "target\_t374_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 7) { return $false }
    return $true
}

Step "T3.73 bitwise op codegen (`&`/`|`/`^` real impl, was diag-only pre-v0.3.103)" {
    & $bin build "tests/fixtures/t373_bitwise_op_diagnostic.nr" -o "_t373_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t373_check.exe") { $exe = "target\_t373_check.exe" }
    elseif (Test-Path "target\_t373_check") { $exe = "target\_t373_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    # Fixture exits 0 when all three ops produce correct results.
    return $LASTEXITCODE -eq 0
}

Step "T3.72 mut closure capture diagnostic (FnMut silent miscompute pre-v0.3.96)" {
    $out = & $bin build "tests/fixtures/t372_mut_closure_capture_diagnostic.nr" -o "_t372_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "closure cannot mutate captured variable") { return $false }
    if ($out -notmatch "FnMut semantics not yet supported") { return $false }
    return $true
}

Step "T3.71 extended macro set (assert_eq!/assert_ne!/todo!/unimplemented!/unreachable!)" {
    & $bin build "tests/fixtures/t371_extended_macro_set.nr" -o "_t371_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t371_check.exe") { $exe = "target\_t371_check.exe" }
    elseif (Test-Path "target\_t371_check") { $exe = "target\_t371_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.70 panic!/assert!/dbg! macro forms (textual ! strip)" {
    & $bin build "tests/fixtures/t370_panic_assert_macros.nr" -o "_t370_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t370_check.exe") { $exe = "target\_t370_check.exe" }
    elseif (Test-Path "target\_t370_check") { $exe = "target\_t370_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.69 &mut T param diagnostic (HIGH-BLAST silent miscompute pre-v0.3.93)" {
    $out = & $bin build "tests/fixtures/t369_mut_ref_param_diagnostic.nr" -o "_t369_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "&mut reference parameter") { return $false }
    if ($out -notmatch "would silently NOT propagate") { return $false }
    return $true
}

Step "T3.68 dyn keyword parser acceptance (Box<dyn Trait>, fn -> dyn ...)" {
    & $bin build "tests/fixtures/t368_dyn_keyword_parse.nr" -o "_t368_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t368_check.exe") { $exe = "target\_t368_check.exe" }
    elseif (Test-Path "target\_t368_check") { $exe = "target\_t368_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 42) { return $false }
    return $true
}

Step "T3.67 ? operator chain (Ok/Err labels were swapped pre-v0.3.91)" {
    & $bin build "tests/fixtures/t367_question_op_chain.nr" -o "_t367_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t367_check.exe") { $exe = "target\_t367_check.exe" }
    elseif (Test-Path "target\_t367_check") { $exe = "target\_t367_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 100) { return $false }
    return $true
}

Step "T3.66 mixed-shorthand struct init 'Point { x: 5, y }'" {
    # v0.3.90 (T3.66): regression test for shorthand field init.
    & $bin build "tests/fixtures/t366_struct_init_shorthand.nr" -o "_t366_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t366_check.exe") { $exe = "target\_t366_check.exe" }
    elseif (Test-Path "target\_t366_check") { $exe = "target\_t366_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "RFC-NRT-004 §A: recursive enum payload USE (was @inner global)" {
    # v0.3.231 fixed (parser drift sync); pinned by t468 in v0.3.235
    # so it can't silently regress.
    & $bin build "tests/fixtures/t468_recursive_enum_match.nr" -o "_t468_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t468_check.exe") { $exe = "target\_t468_check.exe" }
    elseif (Test-Path "target\_t468_check") { $exe = "target\_t468_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "RFC-NRT-004 §B: multi-payload variant bind USE (was @a/@b global)" {
    # v0.3.235: pin §B working behavior (closed as side effect of §A
    # parser-drift fix). Repro: enum E { Pair(i64,i64), Other }
    # match e { E::Pair(a, b) => ...use a/b... }
    & $bin build "tests/fixtures/t469_multi_payload_bind.nr" -o "_t469_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t469_check.exe") { $exe = "target\_t469_check.exe" }
    elseif (Test-Path "target\_t469_check") { $exe = "target\_t469_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "RFC-NRT-004 §C: multi-multi-payload dispatch (was silent miscompute)" {
    # v0.3.235: pin §C working behavior (CRITICAL silent miscompute --
    # pre-fix, constructing E::BinOp dispatched to E::Call arm body).
    # Most important fixture in this set: build succeeded and runtime
    # was wrong, so a regression here would be invisible w/o pinning.
    & $bin build "tests/fixtures/t470_multi_multi_dispatch.nr" -o "_t470_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t470_check.exe") { $exe = "target\_t470_check.exe" }
    elseif (Test-Path "target\_t470_check") { $exe = "target\_t470_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "RFC-NRT-004 stress: 6-variant recursive enum dispatch + bind USE" {
    # v0.3.235: tortious permutations -- 6 variants in one enum
    # mixing unit / single-payload / 2-payload / 3-payload / 3-payload-
    # with-recursion / 4-payload-with-recursion, all multi-payload
    # bindings USED, recursive payload bindings used as inner-match
    # scrutinees. Anything still broken beyond the minimal repros
    # surfaces here.
    & $bin build "tests/fixtures/t471_recursive_enum_stress.nr" -o "_t471_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t471_check.exe") { $exe = "target\_t471_check.exe" }
    elseif (Test-Path "target\_t471_check") { $exe = "target\_t471_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "RFC-NRT-004 §F: harness path (nuc test) -- multi-payload + recursive enum" {
    # v0.4.1 (§F): tools_suite parse_match_stmt sync from s1.
    # Pre-fix: §A/§B/§C closed via `nuc build` but BROKEN via `nuc test`
    # because the harness routes through nucleor_tools.exe which had drifted
    # parser. Post-fix: all three pass via the harness path. The drift gate
    # is also extended to enforce parser-fn token-shape parity.
    $out = & $bin test "tests/fixtures/t472_rfc_nrt_004_F_harness_path.nr" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($out -notmatch "PASS: pair_use") { return $false }
    if ($out -notmatch "PASS: recursive_use") { return $false }
    if ($out -notmatch "PASS: multi_multi_dispatch") { return $false }
    return $true
}

Step "RFC-NRT-004 §D: pub on struct fields no longer crashes" {
    # v0.4.1 (§D): parse_struct_decl in s1 + tools_suite now skips
    # optional `pub` token before each field name. Pre-fix: cascading
    # parse errors + segfault on some hosts.
    & $bin build "tests/fixtures/t473_rfc_nrt_004_D_pub_field.nr" -o "_t473_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t473_check.exe") { $exe = "target\_t473_check.exe" }
    elseif (Test-Path "target\_t473_check") { $exe = "target\_t473_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "RFC-NRT-003: nuc verify-reproducible PASSes on a sample fixture" {
    # v0.4.7 RFC-NRT-003: verify-reproducible builds a file twice with
    # --no-cache and asserts byte-identical IR. The self-host fixed
    # point gate (T1.7) already covers the compiler itself; this Step
    # exercises the new subcommand on a small fixture.
    $out = & $bin verify-reproducible "tests/fixtures/t477_provenance_section.nr" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($out -notmatch "PASS: byte-identical IR") { return $false }
    return $true
}

Step "extern fn that redeclares __nucleor_* helper emits clean diagnostic (negative)" {
    # v0.4.6: NEGATIVE regression. extern fn __nucleor_X with a typed
    # signature would conflict with the compiler-emitted i64-ABI declare.
    # Pre-fix: clang failed late with `invalid redefinition`. Post-fix:
    # s1 emit pass detects the collision in emit_user_externs and panics
    # with a precise diagnostic + workaround.
    $out = & $bin build "tests/fixtures/t478_extern_runtime_helper_diag.nr" -o "_t478_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "extern fn redeclares runtime helper") { return $false }
    if ($out -notmatch "f64_erf") { return $false }
    return $true
}

Step "RFC-NRT-001: .nucprov section present in built binary (empty default)" {
    # v0.4.5 RFC-NRT-001: every binary the compiler produces has a
    # .nucprov section (PE/COFF + ELF). Empty default = 1-byte null
    # placeholder. External tooling (Nucleor_Translate) populates via
    # `nuc build --provenance <path.json>`.
    & $bin build "tests/fixtures/t477_provenance_section.nr" -o "_t477_check" --no-cache 2>&1 | Out-Null
    if (-not (Test-Path "target\_t477_check.exe")) { return $false }
    # Confirm the section is in the linked binary via llvm-readobj.
    $llvmReadObj = $null
    foreach ($candidate in @("C:\Program Files\LLVM\bin\llvm-readobj.exe", "llvm-readobj.exe")) {
        try {
            if (Test-Path -LiteralPath $candidate) { $llvmReadObj = $candidate; break }
            $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($cmd) { $llvmReadObj = $cmd.Source; break }
        } catch {}
    }
    if (-not $llvmReadObj) { return $true }   # skip the section check if the tool isn't present
    $out = & $llvmReadObj --sections "target\_t477_check.exe" 2>&1 | Out-String
    if ($out -notmatch "\.nucprov") { return $false }
    return $true
}

Step "Option<MyStruct> with bare-ident scrutinee — field access on Some payload" {
    # v0.4.11 Phase B: full generic Option<T> propagation via the
    # compile-src side table (Phase A landed v0.4.10). bare-ident
    # scrutinee `let gr: Option<GapReport> = ...; match gr { Some(g) =>
    # g.severity }` works. Field-access scrutinee (match self.gap_report)
    # still needs the v0.4.12 follow-up.
    & $bin build "tests/fixtures/t480_option_struct_bareident.nr" -o "_t480_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t480_check.exe") { $exe = "target\_t480_check.exe" }
    elseif (Test-Path "target\_t480_check") { $exe = "target\_t480_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "Option<str>::Some(s) + Result<i64,str>::Err(e) flow through println! macro" {
    # v0.4.9: format-macro pattern-binding inference. Closes the
    # SPEC-1.5 wishlist item the Translate team called out (and
    # explicitly noted as still pending in their PROGRESS.md).
    & $bin build "tests/fixtures/t479_option_str_macro_println.nr" -o "_t479_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t479_check.exe") { $exe = "target\_t479_check.exe" }
    elseif (Test-Path "target\_t479_check") { $exe = "target\_t479_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch "alias: hello") { return $false }
    if ($out -notmatch "err: bad input") { return $false }
    return $true
}

Step "Option<str> Some payload binding flows through let-assign + str_eq" {
    # v0.4.4 SPEC-1.5 wishlist (partial -- non-macro path):
    # match Some(s) where s is bound from Option<str> field now sets
    # __type_s = "str" so subsequent let assign / str_eq compare /
    # field access work. Macro-path println!("{}", s) still pending
    # the deeper format-expansion redesign.
    & $bin build "tests/fixtures/t476_option_str_payload_letassign.nr" -o "_t476_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t476_check.exe") { $exe = "target\_t476_check.exe" }
    elseif (Test-Path "target\_t476_check") { $exe = "target\_t476_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "RFC-NRT-004 §G: struct-typed enum payload field access (nuc test arm)" {
    # v0.4.2 (§G): tools_suite enum_populate_sym sync of __epayload<i>_*
    # storage + match_bind_payloads_typed sync from s1. Pre-fix the
    # harness path (`nuc test`) emitted %r.-1 invalid SSA register on
    # `e.message` where e was bound from `Outcome::Err(e)` and
    # `Err(ErrInfo)` declared a struct payload.
    $out = & $bin test "tests/fixtures/t475_rfc_nrt_004_G_struct_payload_field.nr" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($out -notmatch "PASS: struct_payload_field_access") { return $false }
    return $true
}

Step "RFC-NRT-004 §H: same-name pub fn collision diagnostic (negative regression)" {
    # v0.4.1 (§H): emit clean diagnostic instead of cryptic clang
    # 'invalid redefinition' when two modules declare same-name pub fn.
    # NEGATIVE regression: this fixture must FAIL with the diagnostic.
    $out = & $bin build "tests/fixtures/t474_rfc_nrt_004_H_collision_diag.nr" -o "_t474_check" --no-cache 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) { return $false }   # build must FAIL
    if ($out -notmatch "duplicate.*fn name") { return $false }
    if ($out -notmatch "error_kind_to_str") { return $false }
    return $true
}

Step "T3.65 trait method with generic param 'fn count<T>(self)'" {
    # v0.3.89 (T3.65): regression test for generic trait method.
    & $bin build "tests/fixtures/t365_trait_generic_method.nr" -o "_t365_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t365_check.exe") { $exe = "target\_t365_check.exe" }
    elseif (Test-Path "target\_t365_check") { $exe = "target\_t365_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 3) { return $false }
    return $true
}

Step "T3.64 vec.iter().X() chain (Rust idiom — identity pass-through)" {
    # v0.3.88 (T3.64): regression test for vec.iter().X() chain.
    & $bin build "tests/fixtures/t364_vec_iter_chain.nr" -o "_t364_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t364_check.exe") { $exe = "target\_t364_check.exe" }
    elseif (Test-Path "target\_t364_check") { $exe = "target\_t364_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.63 struct-like enum variant construction 'Variant { field: val }'" {
    # v0.3.87 (T3.63): regression test for struct-like enum construction.
    & $bin build "tests/fixtures/t363_struct_like_enum_variant.nr" -o "_t363_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t363_check.exe") { $exe = "target\_t363_check.exe" }
    elseif (Test-Path "target\_t363_check") { $exe = "target\_t363_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.62 match multi-capture enum patterns 'Variant(a, b, c)'" {
    # v0.3.86 (T3.62): regression test for multi-capture enum patterns.
    & $bin build "tests/fixtures/t362_match_multi_capture.nr" -o "_t362_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t362_check.exe") { $exe = "target\_t362_check.exe" }
    elseif (Test-Path "target\_t362_check") { $exe = "target\_t362_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.61 trait/impl associated-const diagnostic (pre-v0.3.85 cascaded parse errors)" {
    # v0.3.85 (T3.61): negative regression for trait/impl assoc consts.
    $out = & $bin build "tests/fixtures/t361_assoc_const_diagnostic.nr" -o "_t361_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "associated constants in traits") { return $false }
    if ($out -notmatch "associated constants in impl blocks") { return $false }
    return $true
}

Step "T3.60 match-arm assignment body ('pat => x = v')" {
    # v0.3.84 (T3.60): regression test for match-arm assignment.
    & $bin build "tests/fixtures/t360_match_arm_assign.nr" -o "_t360_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t360_check.exe") { $exe = "target\_t360_check.exe" }
    elseif (Test-Path "target\_t360_check") { $exe = "target\_t360_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.59 fn-pointer type syntax 'fn(T) -> R' in param positions" {
    # v0.3.83 (T3.59): regression test for fn-pointer type syntax.
    & $bin build "tests/fixtures/t359_fn_pointer_type.nr" -o "_t359_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t359_check.exe") { $exe = "target\_t359_check.exe" }
    elseif (Test-Path "target\_t359_check") { $exe = "target\_t359_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.58 trait default-method support (impls inherit defaults; Self substitution)" {
    # v0.3.82 (T3.58): regression test for trait default-method support.
    & $bin build "tests/fixtures/t358_trait_default_methods.nr" -o "_t358_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t358_check.exe") { $exe = "target\_t358_check.exe" }
    elseif (Test-Path "target\_t358_check") { $exe = "target\_t358_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.57 tuple-destructure let safety net (pre-v0.3.81 segfault → clean diagnostic)" {
    # v0.3.81 (T3.57): negative regression — must NOT segfault.
    $out = & $bin build "tests/fixtures/t357_tuple_let_diagnostic.nr" -o "_t357_check" --no-cache 2>&1 | Out-String
    if ($LASTEXITCODE -eq -1073741819) { return $false }
    if ($out -notmatch "tuple destructuring in ``let`` is not yet supported") { return $false }
    return $true
}

Step "T3.55 nested struct field assign safety net (pre-v0.3.80 segfault → clean diagnostic)" {
    # v0.3.80 (T3.55): negative regression — must NOT segfault.
    $out = & $bin build "tests/fixtures/t355_nested_field_assign_diagnostic.nr" -o "_t355_check" --no-cache 2>&1 | Out-String
    if ($LASTEXITCODE -eq -1073741819) { return $false }   # ACCESS_VIOLATION
    if ($out -notmatch "nested struct field assignment is not yet supported") { return $false }
    if ($out -notmatch "Workaround:") { return $false }
    return $true
}

Step "T3.54 match-arm stmt bodies (return/break/continue) — T1.2 partial close" {
    # v0.3.79 (T3.54): regression test for stmt-style match-arm bodies.
    & $bin build "tests/fixtures/t354_match_arm_return.nr" -o "_t354_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t354_check.exe") { $exe = "target\_t354_check.exe" }
    elseif (Test-Path "target\_t354_check") { $exe = "target\_t354_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.53 inline closure-with-capture at .map/.filter call sites (T2.1/2/3 partial close)" {
    # v0.3.78 (T3.53): regression test for inline closure with capture.
    & $bin build "tests/fixtures/t353_inline_closure_capture.nr" -o "_t353_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t353_check.exe") { $exe = "target\_t353_check.exe" }
    elseif (Test-Path "target\_t353_check") { $exe = "target\_t353_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    return $true
}

Step "T3.52 compound assignment desugar (+= -= *= /= %=)" {
    # v0.3.77 (T3.52): regression test for compound-assignment desugar.
    & $bin build "tests/fixtures/t352_compound_assignment.nr" -o "_t352_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t352_check.exe") { $exe = "target\_t352_check.exe" }
    elseif (Test-Path "target\_t352_check") { $exe = "target\_t352_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 3) { return $false }
    return $true
}

Step "T3.51 let-shadowing semantics (RHS sees outer binding, not new uninit slot)" {
    # v0.3.76 (T3.51): regression test for shadowing semantics.
    & $bin build "tests/fixtures/t351_shadowing.nr" -o "_t351_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t351_check.exe") { $exe = "target\_t351_check.exe" }
    elseif (Test-Path "target\_t351_check") { $exe = "target\_t351_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 31) { return $false }
    return $true
}

Step "T3.50 module-scope stmt-keyword diagnostic (return/if/while/for/match/loop/break/continue)" {
    # v0.3.75 (T3.50): negative regression. Build may succeed but
    # diagnostic MUST appear in stderr.
    $out = & $bin build "tests/fixtures/t350_module_stmt_keyword_diagnostic.nr" -o "_t350_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "statement-level keyword at module scope") { return $false }
    if ($out -notmatch "Move statement-level constructs into a fn body") { return $false }
    return $true
}

Step "T3.49 trait-method-call indexed operand f64 dispatch (s.samples()[i])" {
    # v0.3.74 (T3.49): regression test for indexed_element_full_type
    # kind==8 (trait method call) -- pre-fix dispatched to integer
    # add on packed-double bit patterns; post-fix correctly resolves
    # the element type from the trait-impl mangled return type.
    & $bin build "tests/fixtures/t349_trait_method_vec_index.nr" -o "_t349_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t349_check.exe") { $exe = "target\_t349_check.exe" }
    elseif (Test-Path "target\_t349_check") { $exe = "target\_t349_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 6) { return $false }
    return $true
}

Step "T3.48 module-scope let diagnostic (parser previously dropped silently)" {
    # v0.3.73 (T3.48): negative regression test for module-scope `let`
    # diagnostic. Build must fail AND stderr must contain the
    # diagnostic mentioning "module scope" and `const`.
    $out = & $bin build "tests/fixtures/t348_module_let_diagnostic.nr" -o "_t348_check" --no-cache 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) { return $false }
    if ($out -notmatch "let.* not allowed at module scope") { return $false }
    if ($out -notmatch "Use .const NAME") { return $false }
    return $true
}

Step "T3.47 closure-capture link correctness (runtime helpers __nucleor_capture_set/get)" {
    # v0.3.72 (T3.47): regression test for closure-with-capture
    # link-time correctness. Pre-v0.3.72, every captured closure
    # failed at link with "unresolved __nucleor_capture_set/get".
    & $bin build "tests/fixtures/t347_closure_capture.nr" -o "_t347_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t347_check.exe") { $exe = "target\_t347_check.exe" }
    elseif (Test-Path "target\_t347_check") { $exe = "target\_t347_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 15) { return $false }
    return $true
}

Step "T3.46 assoc-fn collection aliases (HashMap/HashSet/BTreeMap/BTreeSet/VecDeque ::new)" {
    # v0.3.71 (T3.46): regression test for Rust-style associated-fn
    # aliases on the lowercase collection helpers. Pre-v0.3.71,
    # `HashMap::new()` etc hit "unhandled expr kind 12" + broken
    # `%r.-1` IR. Pins compile-and-run for the five aliases.
    & $bin build "tests/fixtures/t346_assoc_fn_collections.nr" -o "_t346_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t346_check.exe") { $exe = "target\_t346_check.exe" }
    elseif (Test-Path "target\_t346_check") { $exe = "target\_t346_check" }
    if (-not $exe) { return $false }
    & $exe | Out-Null
    if ($LASTEXITCODE -ne 31) { return $false }
    return $true
}

Step "T3.45 Kalman synthesis (v0.3.65-69 nested-composition lock)" {
    # v0.3.70 (T3.45): production-coverage lock for v0.3.65-69
    # nested-composition arc.
    & $bin build "examples/24_rt_kalman_step.nr" -o "_t345_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t345_check.exe") { $exe = "target\_t345_check.exe" }
    elseif (Test-Path "target\_t345_check") { $exe = "target\_t345_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^7\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^6\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^25\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^50\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^16\.66[67]')  { return $false }
    return $true
}

Step "T3.44 method-result-returning-struct field access (v0.3.69 fix)" {
    # v0.3.69 (T3.44): regression test for trait method calls
    # returning structs followed by immediate field access.
    & $bin build "tests/fixtures/t344_method_returning_struct.nr" -o "_t344_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t344_check.exe") { $exe = "target\_t344_check.exe" }
    elseif (Test-Path "target\_t344_check") { $exe = "target\_t344_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    $count2 = ([regex]::Matches($out, '(?m)^2\.0+\s*$')).Count
    if ($count2 -ne 2) { return $false }
    if ($out -notmatch '(?m)^5\.0+\s*$') { return $false }
    return $true
}

Step "T3.43 nested indexing (grid[i][j], v0.3.68 fix - matrix CLOSED)" {
    # v0.3.68 (T3.43): regression test for nested-indexing inline
    # f64 binops. Closes the kind 10 operand cell of the
    # composition matrix in BOTH resolvers.
    & $bin build "tests/fixtures/t343_nested_indexing.nr" -o "_t343_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t343_check.exe") { $exe = "target\_t343_check.exe" }
    elseif (Test-Path "target\_t343_check") { $exe = "target\_t343_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^1\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^6\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^3\.0+\s*$')   { return $false }
    return $true
}

Step "T3.42 indexing on fn-call result (make_vec()[i], v0.3.67 fix)" {
    # v0.3.67 (T3.42): regression test for indexing on fn-call
    # result inside inline f64 binops.
    & $bin build "tests/fixtures/t342_fncall_indexing.nr" -o "_t342_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t342_check.exe") { $exe = "target\_t342_check.exe" }
    elseif (Test-Path "target\_t342_check") { $exe = "target\_t342_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^7\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^15\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    return $true
}

Step "T3.41 method on indexed struct field (p.rects[0].area(), v0.3.66 fix)" {
    # v0.3.66 (T3.41): regression test for method calls on indexed
    # struct field receivers. Mirrors v0.3.65 in expr_struct_type.
    & $bin build "tests/fixtures/t341_method_on_indexed_field.nr" -o "_t341_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t341_check.exe") { $exe = "target\_t341_check.exe" }
    elseif (Test-Path "target\_t341_check") { $exe = "target\_t341_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^6\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^22\.0+\s*$')  { return $false }
    return $true
}

Step "T3.40 nested-operand indexing (self.samples[i], v0.3.65 fix)" {
    # v0.3.65 (T3.40): regression test for nested-operand indexing
    # in trait method bodies.
    & $bin build "tests/fixtures/t340_nested_index_field.nr" -o "_t340_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t340_check.exe") { $exe = "target\_t340_check.exe" }
    elseif (Test-Path "target\_t340_check") { $exe = "target\_t340_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^4\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^2\.50+\s*$')  { return $false }
    return $true
}

Step "T3.39 sensor-fusion synthesis (v0.3.51-63 production lock)" {
    # v0.3.64 (T3.39): production-coverage lock for the v0.3.51 ->
    # v0.3.63 codegen-fix arc.
    & $bin build "examples/23_rt_sensor_fusion.nr" -o "_t339_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t339_check.exe") { $exe = "target\_t339_check.exe" }
    elseif (Test-Path "target\_t339_check") { $exe = "target\_t339_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^25\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^3\.50+\s*$')   { return $false }
    if ($out -notmatch '(?m)^0\.60+\s*$')   { return $false }
    if ($out -notmatch '(?m)^4\.66[67]')    { return $false }
    return $true
}

Step "T3.38 fixed-array-of-struct field access (v0.3.63 fix)" {
    # v0.3.63 (T3.38): regression test for fixed-array-of-struct
    # field access, fixed by mirroring v0.3.62's [T;N] extension
    # into expr_struct_type's kind==10 branch.
    & $bin build "tests/fixtures/t338_fixed_array_of_struct.nr" -o "_t338_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t338_check.exe") { $exe = "target\_t338_check.exe" }
    elseif (Test-Path "target\_t338_check") { $exe = "target\_t338_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^1\.0+\s*$') { return $false }
    if ($out -notmatch '(?m)^5\.0+\s*$') { return $false }
    if ($out -notmatch '(?m)^6\.0+\s*$') { return $false }
    return $true
}

Step "T3.37 fixed-array [T;N] f64 indexing (v0.3.62 fix)" {
    # v0.3.62 (T3.37): regression test for fixed-size array
    # indexing in inline f64 binops, fixed by extending the
    # kind==10 branch in binop_float_type to handle [T; N].
    & $bin build "tests/fixtures/t337_fixed_array_fp_ops.nr" -o "_t337_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t337_check.exe") { $exe = "target\_t337_check.exe" }
    elseif (Test-Path "target\_t337_check") { $exe = "target\_t337_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^-3\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^4\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^2\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^20\.0+\s*$')  { return $false }
    return $true
}

Step "T3.36 as-cast results in inline f64 binops (v0.3.61 fix)" {
    # v0.3.61 (T3.36): regression test for as-cast-result-in-binop
    # codegen, fixed by adding kind==99 branch to binop_float_type.
    & $bin build "tests/fixtures/t336_cast_fp_ops.nr" -o "_t336_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t336_check.exe") { $exe = "target\_t336_check.exe" }
    elseif (Test-Path "target\_t336_check") { $exe = "target\_t336_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    $count8 = ([regex]::Matches($out, '(?m)^8\.0+\s*$')).Count
    if ($count8 -ne 2) { return $false }
    if ($out -notmatch '(?m)^7\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^11\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^14\.0+\s*$')  { return $false }
    return $true
}

Step "T3.35 trait method results in inline f64 binops (v0.3.60 fix)" {
    # v0.3.60 (T3.35): regression test for trait-method-result-in-
    # binop codegen, fixed by extending binop_float_type with kind==8
    # (method call) branch + populating fn_decls with trait-impl
    # mangled methods.
    & $bin build "tests/fixtures/t335_trait_method_fp_ops.nr" -o "_t335_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t335_check.exe") { $exe = "target\_t335_check.exe" }
    elseif (Test-Path "target\_t335_check") { $exe = "target\_t335_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^22\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^24\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^120\.0+\s*$')  { return $false }
    return $true
}

Step "T3.34 Vec-of-struct field access (v0.3.59 fix)" {
    # v0.3.59 (T3.34): regression test for Vec-of-struct
    # field-access codegen, fixed by adding kind==10 branch
    # to expr_struct_type.
    & $bin build "tests/fixtures/t334_vec_of_struct_field.nr" -o "_t334_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t334_check.exe") { $exe = "target\_t334_check.exe" }
    elseif (Test-Path "target\_t334_check") { $exe = "target\_t334_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^1\.0+\s*$') { return $false }
    $count = ([regex]::Matches($out, '(?m)^6\.0+\s*$')).Count
    if ($count -ne 2) { return $false }
    return $true
}

Step "T3.33 chained field access on fn-call result (v0.3.58 fix)" {
    # v0.3.58 (T3.33): regression test for chained field access
    # on fn-call result, fixed by adding kind==7 branch to
    # expr_struct_type.
    & $bin build "tests/fixtures/t333_chained_field_on_fn_call.nr" -o "_t333_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t333_check.exe") { $exe = "target\_t333_check.exe" }
    elseif (Test-Path "target\_t333_check") { $exe = "target\_t333_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    $count = ([regex]::Matches($out, '(?m)^4\.0+\s*$')).Count
    if ($count -ne 2) { return $false }
    if ($out -notmatch '(?m)^3\.50+\s*$') { return $false }
    return $true
}

Step "T3.32 unary minus on f64 operand kinds (v0.3.57 fix)" {
    # v0.3.57 (T3.32): regression test for the f64 unary-minus
    # codegen bug fixed in v0.3.57.
    & $bin build "tests/fixtures/t332_unary_minus_f64.nr" -o "_t332_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t332_check.exe") { $exe = "target\_t332_check.exe" }
    elseif (Test-Path "target\_t332_check") { $exe = "target\_t332_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    $count = ([regex]::Matches($out, '(?m)^-3\.0+\s*$')).Count
    if ($count -ne 2) { return $false }
    if ($out -notmatch '(?m)^-2\.50+\s*$') { return $false }
    if ($out -notmatch '(?m)^-5\.0+\s*$')  { return $false }
    return $true
}

Step "T3.31 mixed-operand f64 binops (v0.3.56 lock)" {
    # v0.3.56 (T3.31): production-coverage lock for f64 inline
    # binops with MIXED operand kinds.
    & $bin build "tests/fixtures/t331_mixed_fp_ops.nr" -o "_t331_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t331_check.exe") { $exe = "target\_t331_check.exe" }
    elseif (Test-Path "target\_t331_check") { $exe = "target\_t331_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^3\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^6\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^21\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^20\.0+\s*$')  { return $false }
    return $true
}

Step "T3.30 inline f64 ops on Vec indexing (v0.3.55 fix)" {
    # v0.3.55 (T3.30): regression test for the f64 inline
    # binop-on-Vec-indexing codegen bug fixed in v0.3.55.
    & $bin build "tests/fixtures/t330_vec_index_fp_ops.nr" -o "_t330_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t330_check.exe") { $exe = "target\_t330_check.exe" }
    elseif (Test-Path "target\_t330_check") { $exe = "target\_t330_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^-3\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^4\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^2\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^32\.0+\s*$')  { return $false }
    return $true
}

Step "T3.29 inline f64 ops on fn-call results (v0.3.54 fix)" {
    # v0.3.54 (T3.29): regression test for the f64 inline
    # binop-on-fn-call codegen bug fixed in v0.3.54.
    & $bin build "tests/fixtures/t329_fn_call_fp_ops.nr" -o "_t329_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t329_check.exe") { $exe = "target\_t329_check.exe" }
    elseif (Test-Path "target\_t329_check") { $exe = "target\_t329_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^-3\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^4\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^2\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^32\.0+\s*$')  { return $false }
    return $true
}

Step "T3.28 inline f64 ops on struct-field operands (v0.3.53 fix)" {
    # v0.3.53 (T3.28): regression test for the f64 inline
    # binary-op-on-struct-field codegen bug fixed in v0.3.53.
    # Builds the fixture, runs it, asserts each of the four
    # primary ops + the nested-binop dot product produce the
    # mathematically correct value.
    & $bin build "tests/fixtures/t328_struct_field_fp_ops.nr" -o "_t328_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t328_check.exe") { $exe = "target\_t328_check.exe" }
    elseif (Test-Path "target\_t328_check") { $exe = "target\_t328_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '(?m)^5\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^-3\.0+\s*$')  { return $false }
    if ($out -notmatch '(?m)^4\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^2\.0+\s*$')   { return $false }
    if ($out -notmatch '(?m)^32\.0+\s*$')  { return $false }
    return $true
}

Step "T3.27 #[export] workaround produces correct dot product" {
    # v0.3.52 (T3.27): regression test for the v0.3.51 codegen
    # workaround. examples/22_rt_export.nr's nuc_print_dot uses
    # lifted-let bindings to compute (1,2,3)·(4,5,6) = 32. The
    # example sweep already builds + runs ex22 but only checks
    # for non-empty stdout; if the workaround broke,
    # nuc_print_dot would print 0 and the sweep would silently
    # pass. T3.27 strictly asserts the example output contains
    # the literal "32.0" -- the dot product the workaround
    # produces.
    & $bin build "examples/22_rt_export.nr" -o "_t327_check" --no-cache 2>&1 | Out-Null
    $exe = $null
    if (Test-Path "target\_t327_check.exe") { $exe = "target\_t327_check.exe" }
    elseif (Test-Path "target\_t327_check") { $exe = "target\_t327_check" }
    if (-not $exe) { return $false }
    $out = & $exe 2>&1 | Out-String
    if ($out -notmatch '32\.0+') { return $false }
    return $true
}

Step "T3.20 DIAG-001 fires for #[allow]/#[deny] unknown codes" {
    # v0.3.36 (T3.20, extended v0.3.38, v0.3.46): DIAG-001
    # warning fires for #[allow(_fn)] / #[deny(_fn)] CODE
    # arguments not in the canonical enumerated diagnostic code
    # set. Fixture has five offending attributes (4 unknown-
    # prefix + 1 within-series typo RT-099) plus one control
    # (#[allow_fn(RT-007)]).
    #
    # v0.3.46 strict-shape extension: also asserts each of the
    # four attribute-shape prefixes emit correctly. Catches
    # regressions where emit_diag001_unknown_codes swaps
    # shapes (e.g., reports an #[allow] code with the
    # #[allow_fn] message body and vice versa).
    $out = & $bin build "tests/fixtures/t320_diag001_unknown_code.nr" -o "_t320_diag001_check" --no-cache 2>&1 | Out-String
    $count = ([regex]::Matches($out, "warning\[DIAG-001\]")).Count
    if ($count -ne 5) { return $false }
    if ($out -notmatch "'WAT-001'")      { return $false }
    if ($out -notmatch "'BOGUS-002'")    { return $false }
    if ($out -notmatch "'GIBBERISH-003'") { return $false }
    if ($out -notmatch "'NONSENSE-004'") { return $false }
    if ($out -notmatch "'RT-099'")       { return $false }
    # Control: RT-007 must NOT trigger DIAG-001.
    if ($out -match "'RT-007'") { return $false }
    # v0.3.46 shape-prefix assertions.
    if ($out -notmatch "'WAT-001' in #\[allow\(\.\.\.\)\]")           { return $false }
    if ($out -notmatch "'BOGUS-002' in #\[deny\(\.\.\.\)\]")          { return $false }
    if ($out -notmatch "'GIBBERISH-003' in #\[allow_fn\(\.\.\.\)\] on fn 'first_unknown'")     { return $false }
    if ($out -notmatch "'NONSENSE-004' in #\[deny_fn\(\.\.\.\)\] on fn 'second_unknown'")      { return $false }
    if ($out -notmatch "'RT-099' in #\[allow_fn\(\.\.\.\)\] on fn 'within_series_typo'")       { return $false }
    return $true
}

Step "T3.19 #[allow_fn(RT-001)] cannot demote error tier (strict)" {
    # v0.3.34 (T3.19): companion to T3.18. The err-sweep already
    # builds err_t323_allow_fn_no_error_suppress.nr and asserts
    # SOME diagnostic fires, but build_negative accepts either
    # error or warning -- so a regression where #[allow_fn(RT-001)]
    # silently demoted errors to warnings would still pass the
    # sweep. T3.19 strictly asserts error[RT-001] fires AND
    # warning[RT-001] does NOT fire (would indicate the allow_fn
    # improperly demoted the diag tier instead of leaving it at
    # error tier untouched).
    $out = & $bin build "tests/err/err_t323_allow_fn_no_error_suppress.nr" -o "_t323_strict_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "error\[RT-001\]") { return $false }
    if ($out -match "warning\[RT-001\]") { return $false }
    return $true
}

Step "T3.18 #[deny_fn(RT-007)] promotes warning to error (strict)" {
    # v0.3.33 (T3.18): the err-sweep already builds
    # err_t321_deny_fn.nr and asserts SOME diagnostic fires, but
    # build_negative accepts either error or warning -- so a
    # regression where #[deny_fn(RT-007)] silently stops promoting
    # (warning stays warning) would still pass the sweep. T3.18
    # strictly asserts error[RT-007] fires AND warning[RT-007]
    # does NOT fire (the original tier was replaced, not added
    # alongside).
    $out = & $bin build "tests/err/err_t321_deny_fn.nr" -o "_t321_strict_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "error\[RT-007\]") { return $false }
    if ($out -match "warning\[RT-007\]") { return $false }
    return $true
}

Step "T3.17 #[allow_fn(RT-004)] suppresses static WCET warning per-fn" {
    # v0.3.32 (T3.17): closes the coverage gap left by T3.12
    # (which proved #[allow_fn] works for RT-007 only). Same
    # shape: two #[deadline = 1] fns whose bodies each blow the
    # v1 WCET estimate; only the second has #[allow_fn(RT-004)],
    # so RT-004 should fire exactly ONCE. Validates the v0.3.31
    # message-text claim that #[allow_fn(RT-004)] is a real
    # opt-out, not vapor advertisement.
    $out = & $bin build "tests/fixtures/t317_allow_fn_rt004.nr" -o "_t317_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-004\]") { return $false }
    $count = ([regex]::Matches($out, "warning\[RT-004\]")).Count
    if ($count -ne 1) { return $false }
    return $true
}

Step "T3.12 #[allow_fn] suppresses one RT diag for one fn" {
    # v0.3.20 (T3.12): per-fn #[allow_fn(CODE)] — narrower
    # cousin of file-wide #[allow]. The fixture has two
    # #[deadline]-marked fns that would each fire RT-007;
    # only the second has #[allow_fn(RT-007)], so RT-007
    # should fire exactly ONCE. File-wide allow would suppress
    # both; per-fn must suppress only the marked one.
    $out = & $bin build "tests/fixtures/t320_allow_fn.nr" -o "_t320_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "warning\[RT-007\]") { return $false }
    $count = ([regex]::Matches($out, "warning\[RT-007\]")).Count
    if ($count -ne 1) { return $false }
    return $true
}

Step "T3.8 RT-006 fires on RT attr + async fn" {
    # v0.3.7 (T3.8): RFC-0001 RT-006 — async fn cannot carry an
    # RT attribute (#[no_alloc] / #[no_panic] / #[no_dyn] /
    # #[deadline]) because async scheduling is non-deterministic.
    # Two negative fixtures cover both attribute spellings; this
    # step asserts the no_alloc variant fires the exact text.
    $out = & $bin build "tests/err/err_rt006_async_no_alloc.nr" -o "_t38_rt006_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "error\[RT-006\]: RT attribute") { return $false }
    if ($out -notmatch "on async fn 'poll_loop'") { return $false }
    if ($out -notmatch "async is non-deterministic") { return $false }
    return $true
}

Step "T3.7 RT body checks strip strings and line comments" {
    # v0.3.6 (T3.7): polish — RT-001/002/003 v1 checkers strip
    # `"..."` string literals and `// ...` line comments before
    # scanning. A forbidden token mentioned only in a quoted or
    # commented region no longer false-triggers. Three #[no_alloc/
    # panic/dyn] fns + 3 PASSing #[test] cases prove the strip pass.
    $out = & $bin test "tests/smoke/t37_rt_string_skip.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_alloc_name_in_string_compiles") { return $false }
    if ($out -notmatch "PASS: test_panic_name_in_comment_compiles") { return $false }
    if ($out -notmatch "PASS: test_dyn_token_in_string_compiles") { return $false }
    if ($out -notmatch "test result: PASS \(3 tests\)") { return $false }
    return $true
}

Step "T3.6 #[no_dyn] passes when body has no dynamic dispatch" {
    # v0.3.5 (T3.6): RFC-0001 RT-003 — dynamic dispatch ban.
    # Same shape as T3.2 #[no_panic]. Two #[no_dyn] fns + 2
    # #[test] cases that PASS verify the marker mechanism works
    # without false-positive on the attribute literal itself.
    $out = & $bin test "tests/smoke/t36_no_dyn_clean.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_no_dyn_pid_static_dispatch") { return $false }
    if ($out -notmatch "PASS: test_no_dyn_fk_static_dispatch") { return $false }
    if ($out -notmatch "test result: PASS \(2 tests\)") { return $false }
    return $true
}

Step "T3.4 #[export] surfaces in nuc gen-headers" {
    # v0.3.4 (T3.4): #[export] attribute prefix → C forward
    # declaration in `nuc gen-headers` output. Lets external
    # C/C++ host code call into Nucleor-compiled fns through
    # the unmangled LLVM symbol. Three exported fns + one
    # private fn (must NOT appear in the header) + one extern
    # import (must still work).
    $hdr = "$env:TEMP\_t34_export_check.h"
    $null = & $bin gen-headers "tests/fixtures/t34_export.nr" -o $hdr 2>&1
    if (-not (Test-Path $hdr)) { return $false }
    $h = Get-Content $hdr -Raw
    if ($h -notmatch 'int64_t nuc_add\(int64_t a, int64_t b\);') { return $false }
    if ($h -notmatch 'double nuc_dot\(Vec3 a, Vec3 b\);') { return $false }
    if ($h -notmatch 'void nuc_noop\(void\);') { return $false }
    if ($h -match 'private_helper') { return $false }
    if ($h -notmatch 'void host_logger\(int64_t msg_ptr, int64_t msg_len\);') { return $false }
    return $true
}

Step "T3.2 #[no_panic] passes when body has no panic-prone calls" {
    # v0.3.1 (T3.2): source-level v1 check mirrors #[no_alloc].
    # Smoke fixture has 2 #[no_panic] fns + 2 #[test] cases that
    # both PASS. Negative case in tests/err/err_no_panic_violation.nr
    # gets auto-discovered by the err sweep and verified to fail
    # the build with "error" in stderr.
    $out = & $bin test "tests/smoke/t32_no_panic_clean.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_no_panic_pure_arithmetic") { return $false }
    if ($out -notmatch "PASS: test_no_panic_loop_with_arithmetic") { return $false }
    if ($out -notmatch "test result: PASS \(2 tests\)") { return $false }
    return $true
}

Step "v0.3.0 #[deadline=N] runtime check passes within budget" {
    # v0.3.0 (T3.1): #[deadline = N] (microseconds) wraps the
    # annotated fn with start-capture + deadline_check at exit.
    # Fixture has 4 #[deadline = 100000] (100 ms) fns + 4 #[test]
    # cases that all complete well within 100 ms and the runtime
    # check passes silently. Verify gate: all 4 PASS.
    $out = & $bin test "tests/smoke/v030_deadline_runtime.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_deadline_pass_simple_add") { return $false }
    if ($out -notmatch "PASS: test_deadline_pass_simple_mul") { return $false }
    if ($out -notmatch "PASS: test_deadline_pass_no_args") { return $false }
    if ($out -notmatch "PASS: test_deadline_pass_with_loop") { return $false }
    if ($out -notmatch "test result: PASS \(4 tests\)") { return $false }
    return $true
}

Step "v0.3.0 #[deadline=N] overrun aborts with RT-004" {
    # Build the overrun fixture, run it, expect non-zero exit
    # and "RT-004" in the captured stderr/stdout.
    $exe = "target\v030_overrun_check.exe"
    if (Test-Path $exe) { Remove-Item -Force $exe -ErrorAction SilentlyContinue }
    $build = & $bin build "tests/fixtures/v030_deadline_overrun.nr" -o "v030_overrun_check" 2>&1 | Out-String
    if (-not (Test-Path $exe)) { return $false }
    $runOut = & $exe 2>&1 | Out-String
    $rc = $LASTEXITCODE
    if ($rc -eq 0) { return $false }
    if ($runOut -notmatch "error\[RT-004\]: #\[deadline\] overrun") { return $false }
    return $true
}

Step "T2.8 async (threads-only): async fn / async_spawn / .await" {
    # v0.2.353 (T2.8): async runtime committed to threads-only per
    # RFC-0027 phase 1 (locked v0.2 design vote). `async fn` strips
    # the keyword; `<ident>.await` rewrites to async_await(<ident>);
    # async_spawn / async_await runtime helpers capture the i64
    # result of the spawned task. 4 #[test] cases cover basic
    # spawn+await, two concurrent tasks, .await in arithmetic
    # context, and zero-result task.
    $out = & $bin test "tests/smoke/t28_async_threads.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_async_basic_spawn_await") { return $false }
    if ($out -notmatch "PASS: test_async_two_concurrent_tasks") { return $false }
    if ($out -notmatch "PASS: test_async_await_in_arithmetic") { return $false }
    if ($out -notmatch "PASS: test_async_zero_arg_fn") { return $false }
    if ($out -notmatch "test result: PASS \(4 tests\)") { return $false }
    return $true
}

Step "T2.7 nuc doc --html emits styled standalone HTML" {
    # v0.2.352 (T2.7): nuc doc gains an --html flag (+ auto-detect
    # via .html / .htm extension on --out). Single-file HTML with
    # inline CSS — no external resources. Same two-pass walk as the
    # Markdown renderer: function index + per-fn /// doc + signature.
    $hdr = Join-Path $env:TEMP "_t27_doc.html"
    if (Test-Path $hdr) { Remove-Item -Force $hdr }
    $banner = & $bin doc "tests/fixtures/t27_doc_input.nr" --out $hdr 2>&1 | Out-String
    if ($banner -notmatch "wrote .*HTML") { return $false }
    if (-not (Test-Path $hdr)) { return $false }
    $h = Get-Content $hdr -Raw
    if ($h -notmatch "<!doctype html>") { return $false }
    if ($h -notmatch '<title>tests/fixtures/t27_doc_input.nr</title>') { return $false }
    if ($h -notmatch '<h2 id="dbl"><code>dbl</code></h2>') { return $false }
    if ($h -notmatch '<h2 id="add"><code>add</code></h2>') { return $false }
    if ($h -notmatch '<h2 id="helper_no_doc"><code>helper_no_doc</code></h2>') { return $false }
    if ($h -notmatch '<a href="#dbl">') { return $false }
    if ($h -notmatch 'Doubles its argument') { return $false }
    if ($h -notmatch 'fn dbl\(x: i64\) -&gt; i64') { return $false }
    Remove-Item -Force $hdr -ErrorAction SilentlyContinue
    return $true
}

Step "T2.5 lifetime parameters parse cleanly (advisory metadata)" {
    # v0.2.351 (T2.5): lifetime tokens 'a, 'static etc. lex as kind 98
    # and parse as: (a) generic params alongside type params, (b) skip
    # tokens after & in reference types, (c) skip tokens in generic
    # instantiations. No semantic enforcement — annotations are
    # advisory until T2.5b. 4 #[test] cases cover baseline + single +
    # two lifetimes + mixed lifetime/type params.
    $out = & $bin test "tests/smoke/t25_lifetime_params.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_no_lifetime_baseline") { return $false }
    if ($out -notmatch "PASS: test_single_lifetime") { return $false }
    if ($out -notmatch "PASS: test_two_lifetimes") { return $false }
    if ($out -notmatch "PASS: test_mixed_lifetime_and_type_param") { return $false }
    if ($out -notmatch "test result: PASS \(4 tests\)") { return $false }
    return $true
}

Step "T2.4 trait objects (Box<dyn Trait> 2-cell handle helpers)" {
    # v0.2.350 (T2.4): trait object runtime helpers — dyn_box_make,
    # dyn_box_type, dyn_box_data, dyn_box_free. Manual dispatch
    # pattern (auto-dispatch sugar arrives in T2.4b). 5 #[test]
    # cases covering single-impl dispatch, polymorphic collection,
    # unknown-tag default, and free-after-read pattern.
    $out = & $bin test "tests/smoke/t24_trait_objects.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_dyn_box_make_type_data") { return $false }
    if ($out -notmatch "PASS: test_dyn_box_dispatch_a") { return $false }
    if ($out -notmatch "PASS: test_dyn_box_dispatch_b") { return $false }
    if ($out -notmatch "PASS: test_dyn_box_polymorphic_collection") { return $false }
    if ($out -notmatch "PASS: test_dyn_box_unknown_tag_returns_default") { return $false }
    if ($out -notmatch "test result: PASS \(5 tests\)") { return $false }
    return $true
}

Step "T2.3 closure literals |args| body (no-capture)" {
    # v0.2.349 (T2.3): closure literals in argument position get
    # lifted into synthesized top-level fns. Disambiguation from
    # bitwise `|` uses preceding-non-ws-char arg-position test
    # (after `(`, `,`, `=`, `=>`, `[`, `{`, `;`, or source start).
    # 4 #[test] cases including a 3-step pipeline.
    $out = & $bin test "tests/smoke/t23_closure_literals.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_map_with_closure") { return $false }
    if ($out -notmatch "PASS: test_filter_with_closure") { return $false }
    if ($out -notmatch "PASS: test_fold_with_closure") { return $false }
    if ($out -notmatch "PASS: test_chain_with_closures") { return $false }
    if ($out -notmatch "test result: PASS \(4 tests\)") { return $false }
    return $true
}

Step "T2.2 Vec iterator methods (.map/.filter/.fold/.sum/.min/.max)" {
    # v0.2.348 (T2.2): Vec method-call dispatch routes iterator-method
    # names through the typed `vec_*_i64` runtime helpers in
    # nucleor_llvm_rt.c. Synced across both compilers. 5 #[test]
    # cases including a `.map().filter().fold()` chain.
    $out = & $bin test "tests/smoke/t22_iter_methods.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_map") { return $false }
    if ($out -notmatch "PASS: test_filter") { return $false }
    if ($out -notmatch "PASS: test_fold_and_sum") { return $false }
    if ($out -notmatch "PASS: test_min_max") { return $false }
    if ($out -notmatch "PASS: test_chain") { return $false }
    if ($out -notmatch "test result: PASS \(5 tests\)") { return $false }
    return $true
}

Step "T2.1 range patterns in match (1..=9 / 1..10)" {
    # v0.2.347 (T2.1): inclusive `LO..=HI` and exclusive `LO..HI`
    # range patterns now wire through to the existing __range /
    # __range_bad lowering. Synced across both compilers (s1 had
    # the lowering already; tools-suite needed both ..= lex token
    # AND the __range/__range_bad lower handlers for stmt + expr
    # match forms). 3 #[test] cases verify inclusive/exclusive
    # boundaries + wildcard fall-through.
    $out = & $bin test "tests/smoke/t21_range_patterns.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_range_inclusive_boundaries") { return $false }
    if ($out -notmatch "PASS: test_range_exclusive_normalizes") { return $false }
    if ($out -notmatch "PASS: test_range_falls_through_to_wildcard") { return $false }
    if ($out -notmatch "test result: PASS \(3 tests\)") { return $false }
    return $true
}

Step "T2.6 println!/print!/format! macros expand correctly" {
    # v0.2.346 (T2.6): source-level macro expansion in resolver.
    # Smoke fixture has 6 #[test] cases covering int placeholder, two
    # placeholders, {:s} str passthrough, literal-only, {{ }} escapes,
    # {:b} bool spec. Every test verifies the resulting str matches
    # the expected length and first/middle chars.
    $out = & $bin test "tests/smoke/t26_format_macros.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_format_basic_int") { return $false }
    if ($out -notmatch "PASS: test_format_two_placeholders") { return $false }
    if ($out -notmatch "PASS: test_format_str_passthrough") { return $false }
    if ($out -notmatch "PASS: test_format_literal_only") { return $false }
    if ($out -notmatch "PASS: test_format_escaped_braces") { return $false }
    if ($out -notmatch "PASS: test_format_bool_spec") { return $false }
    if ($out -notmatch "test result: PASS \(6 tests\)") { return $false }
    return $true
}

Step "T1.6 gen-headers emits #[repr(C)] struct typedefs" {
    # v0.2.345 (T1.6): struct-by-value FFI. nuc gen-headers walks the
    # source for #[repr(C)] structs, emits matching `typedef struct
    # { ... } Name;` in the C header, and accepts struct names in
    # extern fn signatures. Non-repr(C) structs (PrivateInternal in
    # the fixture) must be excluded — the immediately-preceding-line
    # attribute lookback rules out the false-positive that the
    # earlier 200-char lookback in struct_repr suffered from.
    $hdr = Join-Path $env:TEMP "_t16_struct_ffi.h"
    if (Test-Path $hdr) { Remove-Item -Force $hdr }
    $banner = & $bin gen-headers "tests/fixtures/t16_struct_ffi.nr" -o $hdr 2>&1 | Out-String
    if ($banner -notmatch "wrote 2 #\[repr\(C\)\] struct\(s\), 2 extern decl\(s\), 0 #\[export\] decl\(s\)") { return $false }
    if (-not (Test-Path $hdr)) { return $false }
    $h = Get-Content $hdr -Raw
    if ($h -notmatch "typedef struct Point2D \{[^}]*double x;[^}]*double y;[^}]*\} Point2D;") { return $false }
    if ($h -notmatch "typedef struct Color \{[^}]*uint8_t r;[^}]*uint8_t g;[^}]*uint8_t b;[^}]*uint8_t a;[^}]*\} Color;") { return $false }
    if ($h -notmatch "double distance\(Point2D a, Point2D b\)") { return $false }
    if ($h -notmatch "void fill_pixel\(Color c, int64_t count\)") { return $false }
    if ($h -match "PrivateInternal") { return $false }
    Remove-Item -Force $hdr -ErrorAction SilentlyContinue
    return $true
}

Step "T1.4 nuc registry export-static (GH-Pages schema)" {
    # v0.2.344 (T1.4): convert a local registry tree into the
    # GitHub-Pages-publishable static-site shape per RFC-0019 §6.
    # Uses the checked-in fixture at tests/fixtures/t14_registry/
    # (2 packages: foo with 2 versions, bar with 1 version).
    # Asserts the top-level index.json + per-package index.json +
    # per-version manifest copies all land in the expected paths
    # with the expected JSON schema.
    $outDir = Join-Path $env:TEMP "_t14_verify_out"
    if (Test-Path $outDir) { Remove-Item -Recurse -Force $outDir }
    $regDir = "tests/fixtures/t14_registry"
    $out = & $bin registry export-static $outDir --registry $regDir 2>&1 | Out-String
    if ($out -notmatch "packages exported: 2") { return $false }
    if ($out -notmatch "versions exported: 3") { return $false }
    if ($out -notmatch "files copied:\s*7") { return $false }
    if (-not (Test-Path (Join-Path $outDir "index.json"))) { return $false }
    if (-not (Test-Path (Join-Path $outDir "foo/index.json"))) { return $false }
    if (-not (Test-Path (Join-Path $outDir "foo/0.2.0/Nucleor.toml"))) { return $false }
    if (-not (Test-Path (Join-Path $outDir "bar/1.0.0/Nucleor.toml"))) { return $false }
    $top = Get-Content (Join-Path $outDir "index.json") -Raw
    if ($top -notmatch '"schema_version":"1.0"') { return $false }
    if ($top -notmatch '"type":"nucleor_registry_index"') { return $false }
    if ($top -notmatch '"name":"foo"') { return $false }
    if ($top -notmatch '"latest":"0.2.0"') { return $false }
    if ($top -notmatch '"count":2') { return $false }
    Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue
    return $true
}

Step "T1.5d MOD-003 surfaces with origin + pub hint" {
    # v0.2.343 (T1.5d): when the resolver privatizes a fn (T1.5c) and
    # a cross-module caller still references the unmangled name,
    # clang emits "use of undefined value '@<name>'". The compiler
    # captures clang's output and lifts each undefined-symbol that
    # matches a registered private fn name into a friendly
    # `error[MOD-003]: cannot call private fn '<name>' from outside
    # its declaring module` line, plus the origin path and the
    # `add pub` hint. This step builds the err fixture and asserts
    # all three lines appear.
    $out = & $bin build "tests/err/err_priv_cross_module.nr" -o "_t15d_check" --no-cache 2>&1 | Out-String
    if ($out -notmatch "error\[MOD-003\]: cannot call private fn 'lib_helper'") { return $false }
    if ($out -notmatch "declared in: .*lib_optin\.nr") { return $false }
    if ($out -notmatch "hint: add ``pub`` to the fn declaration") { return $false }
    if ($out -notmatch "MOD-003 violation\(s\) — see error\[MOD-003\] above") { return $false }
    return $true
}

Step "T1.5c privatization (cross-module call surfaces succeed)" {
    # v0.2.342 (T1.5c): resolver-layer name privatization with opt-in
    # semantics. Smoke fixture imports two libs:
    #   - tests/smoke/t15c_pkg/lib_optin.nr  (pub fn → opt-in active)
    #   - tests/smoke/t15c_pkg/lib_legacy.nr (no pub fn → opt-out)
    # Asserts that pub fn from opt-in lib AND non-pub fn from
    # opt-out lib BOTH stay callable cross-module. The negative
    # case (cross-module non-pub call from opt-in lib) is covered by
    # the err-fixture tests/err/err_priv_cross_module.nr which the
    # main negative-fixture sweep auto-discovers.
    $out = & $bin test "tests/smoke/t15c_privatization.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_cross_module_pub_call_opt_in_lib") { return $false }
    if ($out -notmatch "PASS: test_cross_module_non_pub_call_opt_out_lib") { return $false }
    if ($out -notmatch "test result: PASS \(2 tests\)") { return $false }
    return $true
}

Step "T1.5b pub introspection (summary surfaces visibility)" {
    # v0.2.341 (T1.5b): the parser now emits a kind-76 marker before
    # each `pub`-prefixed top-level item. `nuc summary` reads the
    # markers and prefixes `pub fn` (etc.) accordingly, so users can
    # see the visibility surface of any module. Smoke fixture has 4
    # top-level fns (2 pub, 2 non-pub) plus 3 #[test] cases that all
    # PASS — verifies the marker mechanism doesn't break intra-module
    # calls. Cross-module enforcement arrives in T1.5c.
    $sumOut = & $bin summary "tests/smoke/t15b_pub_introspection.nr" 2>&1 | Out-String
    if ($sumOut -notmatch "pub fn pub_alpha\(\)") { return $false }
    if ($sumOut -notmatch "pub fn pub_gamma\(\)") { return $false }
    if ($sumOut -notmatch "(?m)^fn priv_beta\(\)") { return $false }
    if ($sumOut -notmatch "(?m)^fn priv_delta\(\)") { return $false }
    $testOut = & $bin test "tests/smoke/t15b_pub_introspection.nr" 2>&1 | Out-String
    if ($testOut -notmatch "PASS: test_pub_fn_callable") { return $false }
    if ($testOut -notmatch "PASS: test_non_pub_fn_still_callable_pre_enforcement") { return $false }
    if ($testOut -notmatch "PASS: test_mixed_pub_arithmetic") { return $false }
    if ($testOut -notmatch "test result: PASS \(3 tests\)") { return $false }
    return $true
}

Step "T1.5a mod block-form inline" {
    # v0.2.340 (T1.5a): the resolver inlines `mod foo { ... }` block
    # contents alongside the existing `mod foo;` file-rooted desugaring.
    # Brace scanner is string- and line-comment-aware. This step runs
    # the smoke fixture via `nuc test` and asserts all three cases PASS.
    $out = & $bin test "tests/smoke/t15a_mod_block_form.nr" 2>&1 | Out-String
    if ($out -notmatch "PASS: test_mod_block_helper_visible_outside") { return $false }
    if ($out -notmatch "PASS: test_mod_block_brace_in_string") { return $false }
    if ($out -notmatch "PASS: test_mod_block_brace_in_comment_does_not_close_early") { return $false }
    if ($out -notmatch "test result: PASS \(3 tests\)") { return $false }
    return $true
}

Step "T1.7 bootstrap seed matches current compiler" {
    # v0.2.339 (T1.7): the Linux verify gate clang-links
    # bootstrap/nucleor_s1_seed.ll against the platform-portable C
    # runtime to produce its own bin/nucleor. The seed must match what
    # the current Windows compiler emits for compiler/nucleor_s1_compiler.nr,
    # otherwise the Linux gate would cross-fail every time the IR shape
    # changed without a developer also refreshing the seed. Refresh
    # workflow: see bootstrap/README.md.
    $seed = "bootstrap\nucleor_s1_seed.ll"
    if (-not (Test-Path $seed)) { return $false }
    & $bin build "compiler/nucleor_s1_compiler.nr" -o "_seed_check" 2>&1 | Out-Null
    $fresh = "target\_seed_check.ll"
    if (-not (Test-Path $fresh)) { return $false }
    $hSeed  = (Get-FileHash $seed  -Algorithm SHA256).Hash
    $hFresh = (Get-FileHash $fresh -Algorithm SHA256).Hash
    return $hSeed -eq $hFresh
}

# v0.3.223: perf + memory regression monitor. Runs check_perf_regression.ps1
# which times cold + hot self-build and measures peak working-set memory,
# compares against tools/perf_baseline.json. Catches the v0.3.205 footgun
# pattern (single line that adds O(N-source) overhead per call) and
# memory blowups automatically on every verify.
Step "T1.8 perf + memory regression monitor" {
    $check = Join-Path $root "tools\check_perf_regression.ps1"
    if (-not (Test-Path $check)) { return $false }
    & pwsh.exe -NoProfile -File $check -Quiet 2>&1 | Out-Null
    return $LASTEXITCODE -eq 0
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
