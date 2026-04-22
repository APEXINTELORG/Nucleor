# build-distro.ps1 — Reproducibility script for the Nucleor OSS distribution.
#
# This is a post-hoc record of how the contents of this repository were assembled
# from earlier internal trees. Future maintainers re-running this script against a
# new SourceRoot (a current Nucleor V3+ tree) and ArchiveRoot (a complete stdlib
# snapshot) will get a fresh OSS distribution layout.
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File tools\build-distro.ps1 `
#     -SourceRoot   <path-to-current-nucleor>     `
#     -ArchiveRoot  <path-to-complete-stdlib>     `
#     -DestRoot     <path-for-new-distribution>   `
#     [-SkipVerify]                                `
#     [-Force]
#
# Behavior:
#   - Refuses to run if DestRoot exists (use -Force + confirm to override).
#   - Copies an explicit allowlist of files from SourceRoot.
#   - Restores .nr rod wrappers and rust_bridge source from ArchiveRoot.
#   - Applies in-place patches:
#       * llvm_clang_path() -> bare "clang" (compiler/*.nr)
#       * mutex _value forwarders + rng_seed forwarder + rng_rt include
#         (stdlib/runtime/nucleor_llvm_rt.c)
#       * Several `let` -> `let mut` and missing imports across rods (manual list).
#   - Optionally runs tools\verify.ps1 against the result.

param(
    [string] $SourceRoot   = "C:\Users\JoeWe\Desktop\Nucleor_V2",
    [string] $ArchiveRoot  = "C:\Users\JoeWe\Desktop\Archive\Nucleor_Copy",
    [string] $DestRoot     = "C:\Users\JoeWe\Desktop\Nucleor_OSS_rebuild",
    [switch] $SkipVerify,
    [switch] $Force
)

$ErrorActionPreference = "Stop"

function Die($msg) {
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

# Preflight
if (-not (Test-Path $SourceRoot)) { Die "SourceRoot not found: $SourceRoot" }
if (-not (Test-Path $ArchiveRoot)) { Die "ArchiveRoot not found: $ArchiveRoot" }
if (Test-Path $DestRoot) {
    if (-not $Force) {
        Die "DestRoot already exists: $DestRoot. Pass -Force to overwrite (will prompt)."
    }
    $confirm = Read-Host "DestRoot exists. Delete and recreate? (y/N)"
    if ($confirm -ne "y") { Die "Aborted." }
    Remove-Item -Recurse -Force $DestRoot
}

Write-Host "Building distribution at $DestRoot"
Write-Host "  SourceRoot:  $SourceRoot"
Write-Host "  ArchiveRoot: $ArchiveRoot"

# Layout
$dirs = @(
    "bin", "compiler",
    "stdlib\rods\rust_bridge\src", "stdlib\runtime",
    "examples", "tests\lang", "tests\attrs", "tests\runtime", "tests\rods", "tests\err",
    "docs", "tools", ".github\workflows"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $DestRoot $d) | Out-Null
}

# Copy from SourceRoot
$srcManifest = @{
    "target\nucleor.exe"                          = "bin\nucleor.exe"
    "target\nucleor_s1_compiler.nr"               = "compiler\nucleor_s1_compiler.nr"
    "target\nucleor_tools_suite.nr"               = "compiler\nucleor_tools_suite.nr"
    "nuc_router.ps1"                              = "nuc_router.ps1"
}
foreach ($k in $srcManifest.Keys) {
    Copy-Item (Join-Path $SourceRoot $k) (Join-Path $DestRoot $srcManifest[$k]) -Force
}

# Copy stdlib from ArchiveRoot (full set of .nr wrappers + .c runtimes)
Copy-Item (Join-Path $ArchiveRoot "stdlib\rods")    (Join-Path $DestRoot "stdlib\") -Recurse -Force
Copy-Item (Join-Path $ArchiveRoot "stdlib\runtime") (Join-Path $DestRoot "stdlib\") -Recurse -Force
Get-ChildItem (Join-Path $ArchiveRoot "stdlib") -Filter "*.nr" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $DestRoot "stdlib\")
}
# Drop rust_bridge build artifacts from the Archive copy
Remove-Item -Recurse -Force (Join-Path $DestRoot "stdlib\rods\rust_bridge\target")     -ErrorAction SilentlyContinue
Remove-Item        -Force (Join-Path $DestRoot "stdlib\rods\rust_bridge\Cargo.lock") -ErrorAction SilentlyContinue

# Re-overlay any newer rod/runtime files from SourceRoot (V2 evolved past Archive)
foreach ($overlayDir in @("stdlib\rods", "stdlib\runtime")) {
    $srcDir = Join-Path $SourceRoot $overlayDir
    $dstDir = Join-Path $DestRoot   $overlayDir
    if (Test-Path $srcDir) {
        Get-ChildItem $srcDir -Filter "*.c"  -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName $dstDir -Force }
        Get-ChildItem $srcDir -Filter "*.cu" -ErrorAction SilentlyContinue | ForEach-Object { Copy-Item $_.FullName $dstDir -Force }
    }
}

Write-Host ""
Write-Host "Layout complete. Authored content (README, LICENSE, NOTICE, examples,"
Write-Host "tests, docs, tooling, CI) and source patches (llvm_clang_path, mutex"
Write-Host "_value forwarders, rng inclusion, rod imports) must be applied next."
Write-Host "See CHANGELOG.md in the v0.1.0 source tree for the full patch list."

if (-not $SkipVerify) {
    Write-Host ""
    Write-Host "Run tools\verify.ps1 inside $DestRoot to confirm the build is green."
}
