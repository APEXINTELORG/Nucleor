param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$ArtifactRoot = "",
    [string]$OutputDir = "",
    [switch]$RequireSigned
)

$ErrorActionPreference = "Stop"

$Root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
    $ArtifactRoot = Join-Path $Root "bin"
} elseif (-not [System.IO.Path]::IsPathRooted($ArtifactRoot)) {
    $ArtifactRoot = [System.IO.Path]::GetFullPath((Join-Path $Root $ArtifactRoot))
} else {
    $ArtifactRoot = [System.IO.Path]::GetFullPath($ArtifactRoot)
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $Root "target\release"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir = [System.IO.Path]::GetFullPath((Join-Path $Root $OutputDir))
} else {
    $OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
}

$ArtifactNames = @(
    "nucleor.exe",
    "nucleor-lsp.exe",
    "nucleor.exe.bootstrap"
)

$CheckArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $Root "tools\check_windows_release_artifacts.ps1"),
    "-ArtifactRoot", $ArtifactRoot,
    "-ArtifactPaths", ($ArtifactNames -join ","),
    "-JsonOut", (Join-Path $OutputDir "windows-authenticode.json")
)
if ($RequireSigned) {
    $CheckArgs += "-RequireSigned"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
& powershell.exe @CheckArgs
if ($LASTEXITCODE -ne 0) {
    throw "Windows release artifact verification failed"
}

$ReleaseName = "nucleor-v$Version-windows-x86_64"
$StageRoot = Join-Path $OutputDir $ReleaseName
$ZipPath = Join-Path $OutputDir "$ReleaseName.zip"
$ZipHashPath = Join-Path $OutputDir "$ReleaseName.zip.sha256"
$ArtifactHashPath = Join-Path $OutputDir "windows-artifacts.sha256"
$SummaryPath = Join-Path $OutputDir "windows-release-summary.md"

if (Test-Path -LiteralPath $StageRoot) {
    Remove-Item -LiteralPath $StageRoot -Recurse -Force
}
if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

New-Item -ItemType Directory -Force -Path (Join-Path $StageRoot "bin") | Out-Null

foreach ($Name in $ArtifactNames) {
    Copy-Item -LiteralPath (Join-Path $ArtifactRoot $Name) -Destination (Join-Path $StageRoot "bin\$Name") -Force
}

foreach ($RelPath in @("nuc.bat", "README.md", "LICENSE", "NOTICE", "CHANGELOG.md", "RELEASES.md")) {
    $Source = Join-Path $Root $RelPath
    if (Test-Path -LiteralPath $Source) {
        Copy-Item -LiteralPath $Source -Destination (Join-Path $StageRoot $RelPath) -Force
    }
}

$Readme = @"
# Nucleor Windows Binary Overlay

Version: $Version

This archive contains the Windows x86_64 release binaries and a minimal set of
release metadata. Use it together with the source archive from the same GitHub
release tag, or extract it over a clean checkout of the matching tag.

Included binaries:

- bin/nucleor.exe
- bin/nucleor-lsp.exe
- bin/nucleor.exe.bootstrap

After extraction, run:

```powershell
.\nuc.bat --version
.\nuc.bat build examples\01_hello.nr -o hello
.\target\hello.exe
```
"@
$Readme | Set-Content -LiteralPath (Join-Path $StageRoot "README-WINDOWS-ARTIFACTS.md") -Encoding UTF8

Compress-Archive -Path (Join-Path $StageRoot "*") -DestinationPath $ZipPath -Force

$HashLines = New-Object System.Collections.Generic.List[string]
foreach ($Name in $ArtifactNames) {
    $Path = Join-Path $StageRoot "bin\$Name"
    $Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $HashLines.Add(("{0}  bin/{1}" -f $Hash, $Name)) | Out-Null
}
$HashLines | Set-Content -LiteralPath $ArtifactHashPath -Encoding ASCII

$ZipHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
("{0}  {1}" -f $ZipHash, (Split-Path -Leaf $ZipPath)) | Set-Content -LiteralPath $ZipHashPath -Encoding ASCII

$Commit = (& git -C $Root rev-parse HEAD).Trim()
$SignedMode = if ($RequireSigned) { "required" } else { "not required for this local package build" }
$Summary = @"
# Windows Release Summary

- Version: $Version
- Commit: $Commit
- Package: $(Split-Path -Leaf $ZipPath)
- Package SHA256: $ZipHash
- Authenticode signature mode: $SignedMode

Release assets to attach:

- $(Split-Path -Leaf $ZipPath)
- $(Split-Path -Leaf $ZipHashPath)
- windows-artifacts.sha256
- windows-authenticode.json

The GitHub source archive for the same tag remains the source-of-truth source
package. This zip is the Windows binary overlay for that source archive.
"@
$Summary | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

Write-Host ("wrote {0}" -f $ZipPath)
Write-Host ("wrote {0}" -f $ZipHashPath)
Write-Host ("wrote {0}" -f $ArtifactHashPath)
Write-Host ("wrote {0}" -f $SummaryPath)
