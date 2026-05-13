param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Ref = "HEAD",
    [string]$OutputDir = "",
    [switch]$AllowDirty,
    [switch]$RequireSignedWindows
)

$ErrorActionPreference = "Stop"

$Root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $Root "target\release"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir = [System.IO.Path]::GetFullPath((Join-Path $Root $OutputDir))
} else {
    $OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $out = & git -C $Root @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0} failed" -f ($GitArgs -join " "))
    }
    return $out
}

function Write-ShaLine {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Path
    )
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $leaf = Split-Path -Leaf $Path
    $Lines.Add(("{0}  {1}" -f $hash, $leaf)) | Out-Null
}

$CommitRaw = Invoke-Git -GitArgs @("rev-parse", $Ref)
$Commit = ($CommitRaw -join "`n").Trim()
$TreeStatusRaw = Invoke-Git -GitArgs @("status", "--porcelain")
$TreeStatus = if ($null -eq $TreeStatusRaw) { "" } else { ($TreeStatusRaw -join "`n").Trim() }
if (-not $AllowDirty -and -not [string]::IsNullOrWhiteSpace($TreeStatus)) {
    throw "working tree is dirty; commit/stash changes or pass -AllowDirty for a local draft"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$ReleaseName = "nucleor-v$Version"
$SourceZip = Join-Path $OutputDir "$ReleaseName-source.zip"
$SourceTar = Join-Path $OutputDir "$ReleaseName-source.tar"
$SourceTarGz = Join-Path $OutputDir "$ReleaseName-source.tar.gz"
$ShaSums = Join-Path $OutputDir "SHA256SUMS.txt"
$Notes = Join-Path $OutputDir "RELEASE_NOTES_DRAFT.md"

foreach ($Path in @($SourceZip, $SourceTar, $SourceTarGz, $ShaSums, $Notes)) {
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
}

Invoke-Git -GitArgs @("archive", "--format=zip", "--output", $SourceZip, "--prefix", "$ReleaseName/", $Commit) | Out-Null
Invoke-Git -GitArgs @("archive", "--format=tar", "--output", $SourceTar, "--prefix", "$ReleaseName/", $Commit) | Out-Null

$inStream = [System.IO.File]::OpenRead($SourceTar)
try {
    $outStream = [System.IO.File]::Create($SourceTarGz)
    try {
        $gzip = [System.IO.Compression.GZipStream]::new($outStream, [System.IO.Compression.CompressionLevel]::Optimal)
        try {
            $inStream.CopyTo($gzip)
        } finally {
            $gzip.Dispose()
        }
    } finally {
        $outStream.Dispose()
    }
} finally {
    $inStream.Dispose()
}
Remove-Item -LiteralPath $SourceTar -Force

$SignNote = if ($RequireSignedWindows) {
    "signed; Authenticode verification required"
} else {
    "unsigned; Authenticode signing verification pending"
}

$PackageArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $Root "tools\make_windows_release_package.ps1"),
    "-Version", $Version,
    "-OutputDir", $OutputDir,
    "-SigningStatusNote", $SignNote
)
if ($RequireSignedWindows) {
    $PackageArgs += "-RequireSigned"
}
& powershell.exe @PackageArgs
if ($LASTEXITCODE -ne 0) {
    throw "Windows release package generation failed"
}

$WindowsZip = Join-Path $OutputDir "nucleor-v$Version-windows-x86_64.zip"
$WindowsZipSha = Join-Path $OutputDir "nucleor-v$Version-windows-x86_64.zip.sha256"
$WindowsArtifactsSha = Join-Path $OutputDir "windows-artifacts.sha256"
$WindowsAuth = Join-Path $OutputDir "windows-authenticode.json"
$WindowsSummary = Join-Path $OutputDir "windows-release-summary.md"

$Lines = New-Object System.Collections.Generic.List[string]
foreach ($Path in @($SourceZip, $SourceTarGz, $WindowsZip, $WindowsZipSha, $WindowsArtifactsSha, $WindowsAuth, $WindowsSummary)) {
    if (Test-Path -LiteralPath $Path) {
        Write-ShaLine -Lines $Lines -Path $Path
    }
}
$Lines | Set-Content -LiteralPath $ShaSums -Encoding ASCII

$NotesLines = @(
    "# Nucleor $Version Release Notes Draft",
    "",
    "Commit: $Commit",
    "",
    "## Signing Status",
    "",
    "Windows Authenticode signing is awaiting certificate/vendor verification",
    "completion. The release-candidate Windows binaries are unsigned until the",
    'manual `Sign Windows Release Artifacts` workflow succeeds.',
    "",
    "## Assets",
    "",
    "- $ReleaseName-source.zip",
    "- $ReleaseName-source.tar.gz",
    "- nucleor-v$Version-windows-x86_64.zip",
    "- nucleor-v$Version-windows-x86_64.zip.sha256",
    "- windows-artifacts.sha256",
    "- windows-authenticode.json",
    "- windows-release-summary.md",
    "- SHA256SUMS.txt",
    "",
    "## Verification",
    "",
    '- Verify all files with `SHA256SUMS.txt`.',
    "- Verify Windows Authenticode status before publishing signed binaries.",
    "- Run the release smoke test from the downloaded package:",
    "",
    '```powershell',
    ".\nuc.bat --version",
    ".\nuc.bat build examples\01_hello.nr -o hello",
    ".\target\hello.exe",
    '```',
    "",
    "## Current Known Limits",
    "",
    "- Windows binaries in this candidate may be unsigned while signing verification",
    "  is pending.",
    '- Linux users bootstrap from `bootstrap/nucleor_s1_seed.ll`.',
    "- macOS is experimental and not release-gated for this version."
)
$NotesLines | Set-Content -LiteralPath $Notes -Encoding UTF8

Write-Host ("release candidate commit: {0}" -f $Commit)
Write-Host ("wrote {0}" -f $SourceZip)
Write-Host ("wrote {0}" -f $SourceTarGz)
Write-Host ("wrote {0}" -f $ShaSums)
Write-Host ("wrote {0}" -f $Notes)
