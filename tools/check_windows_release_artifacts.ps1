param(
    [switch]$RequireSigned,
    [string]$JsonOut = ""
)

$ErrorActionPreference = "Stop"

$Root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

$Artifacts = @(
    "bin/nucleor.exe",
    "bin/nucleor-lsp.exe",
    "bin/nucleor_tools.exe",
    "bin/nucleor.exe.bootstrap"
)

function Test-PeHeader {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 2) {
            return $false
        }
        $first = $stream.ReadByte()
        $second = $stream.ReadByte()
        return ($first -eq 0x4d -and $second -eq 0x5a)
    } finally {
        $stream.Dispose()
    }
}

$Results = New-Object System.Collections.Generic.List[object]

foreach ($RelPath in $Artifacts) {
    $Path = Join-Path $Root $RelPath
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "missing Windows release artifact: $RelPath"
    }

    $Item = Get-Item -LiteralPath $Path
    if ($Item.Length -le 0) {
        throw "empty Windows release artifact: $RelPath"
    }
    if (-not (Test-PeHeader -Path $Path)) {
        throw "Windows release artifact is not a PE/MZ executable: $RelPath"
    }

    $Hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $Sig = Get-AuthenticodeSignature -LiteralPath $Path
    if ($RequireSigned -and $Sig.Status -ne "Valid") {
        throw ("invalid Authenticode signature for {0}: {1}" -f $RelPath, $Sig.Status)
    }

    $SignerSubject = $null
    $SignerThumbprint = $null
    if ($Sig.SignerCertificate) {
        $SignerSubject = $Sig.SignerCertificate.Subject
        $SignerThumbprint = $Sig.SignerCertificate.Thumbprint
    }

    $Result = [ordered]@{
        path = $RelPath.Replace("\", "/")
        bytes = [int64]$Item.Length
        sha256 = $Hash
        authenticode_status = [string]$Sig.Status
        signer_subject = $SignerSubject
        signer_thumbprint = $SignerThumbprint
    }
    $Results.Add([pscustomobject]$Result) | Out-Null

    Write-Host ("artifact {0}: bytes={1} sha256={2} authenticode={3}" -f $RelPath, $Item.Length, $Hash, $Sig.Status)
}

if (-not [string]::IsNullOrWhiteSpace($JsonOut)) {
    $OutPath = if ([System.IO.Path]::IsPathRooted($JsonOut)) {
        [System.IO.Path]::GetFullPath($JsonOut)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $Root $JsonOut))
    }
    $Parent = [System.IO.Path]::GetDirectoryName($OutPath)
    if (-not [string]::IsNullOrWhiteSpace($Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding UTF8
    Write-Host ("wrote {0}" -f $OutPath)
}
