param(
    [string]$Root = "",

    [switch]$Help,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ForwardArgs
)

$ErrorActionPreference = "Stop"

function Get-PolicyRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:NUCLEOR_POLICY_ROOT)) {
        return [System.IO.Path]::GetFullPath($env:NUCLEOR_POLICY_ROOT)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return [System.IO.Path]::Combine($env:USERPROFILE, ".nucleor")
    }
    return [System.IO.Path]::Combine($Root, ".nucleor")
}

function Release-SigningDir([string]$PolicyRoot) {
    return [System.IO.Path]::Combine($PolicyRoot, "release-signing-keys")
}

function Release-TrustedDir([string]$PolicyRoot) {
    return [System.IO.Path]::Combine($PolicyRoot, "trusted-release-keys")
}

function Release-KeyPath([string]$PolicyRoot, [string]$KeyId) {
    return [System.IO.Path]::Combine((Release-SigningDir $PolicyRoot), $KeyId)
}

function Release-PubPath([string]$PolicyRoot, [string]$KeyId) {
    return (Release-KeyPath $PolicyRoot $KeyId) + ".pub"
}

function Release-TrustedKeyPath([string]$PolicyRoot, [string]$KeyId) {
    return [System.IO.Path]::Combine((Release-TrustedDir $PolicyRoot), ($KeyId + ".pub"))
}

function Release-UsageText {
    return "Usage: nuc release [keygen [key-id]|sign-bundle <dir>|verify-bundle <dir>|package-sign <dir> [key-id]|package-sign-preflight <dir> [key-id]|package-verify <dir>|export-key <key-id> <path>|trust-key <key-id> <path>] [--json]"
}

function Show-ReleaseUsage {
    Write-Host (Release-UsageText)
    Write-Host "  package-sign-preflight <dir> [key-id]  Report package signing inputs without creating keys or signatures"
}

function Ensure-Dir([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Resolve-PathMaybeRelative([string]$Base, [string]$PathValue) {
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $Base $PathValue))
}

function Get-JsonFile([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Json-Escape([string]$Value) {
    if ($null -eq $Value) { return "" }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Value.ToCharArray()) {
        switch ($ch) {
            '"' { [void]$sb.Append('\"') }
            '\' { [void]$sb.Append('\\') }
            "`b" { [void]$sb.Append('\b') }
            "`f" { [void]$sb.Append('\f') }
            "`n" { [void]$sb.Append('\n') }
            "`r" { [void]$sb.Append('\r') }
            "`t" { [void]$sb.Append('\t') }
            default {
                if ([int][char]$ch -lt 32) {
                    [void]$sb.Append(('\u{0:x4}' -f [int][char]$ch))
                } else {
                    [void]$sb.Append($ch)
                }
            }
        }
    }
    return $sb.ToString()
}

function ConvertTo-DeterministicJson($Value) {
    if ($null -eq $Value) { return "null" }
    if ($Value -is [string]) { return '"' + (Json-Escape $Value) + '"' }
    if ($Value -is [bool]) { return ($(if ($Value) { "true" } else { "false" })) }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) { return ([string]$Value).ToLowerInvariant() }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($key in $Value.Keys) {
            $parts.Add(('"{0}":{1}' -f (Json-Escape ([string]$key)), (ConvertTo-DeterministicJson $Value[$key])))
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $parts = New-Object System.Collections.Generic.List[string]
        foreach ($item in $Value) {
            $parts.Add((ConvertTo-DeterministicJson $item))
        }
        return '[' + ($parts -join ',') + ']'
    }
    $propParts = New-Object System.Collections.Generic.List[string]
    foreach ($prop in $Value.PSObject.Properties) {
        $propParts.Add(('"{0}":{1}' -f (Json-Escape ([string]$prop.Name)), (ConvertTo-DeterministicJson $prop.Value)))
    }
    return '{' + ($propParts -join ',') + '}'
}

function Write-JsonFile([string]$Path, $Value) {
    $json = ConvertTo-DeterministicJson $Value
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Bytes-ToHexLower([byte[]]$Bytes) {
    return ([System.BitConverter]::ToString($Bytes).Replace("-", "").ToLowerInvariant())
}

function Trace-Release([string]$Message) {
    if ($env:NUCLEOR_RELEASE_TRACE -eq "1") {
        Write-Host ("[release-trace] {0}" -f $Message)
    }
    if (-not [string]::IsNullOrWhiteSpace($env:NUCLEOR_RELEASE_TRACE_FILE)) {
        Add-Content -LiteralPath $env:NUCLEOR_RELEASE_TRACE_FILE -Value ("[release-trace] {0}" -f $Message)
    }
}

function Test-OpenSshPublicKeyLine([string]$Line) {
    return (-not [string]::IsNullOrWhiteSpace($Line)) -and $Line.TrimStart().StartsWith("ssh-ed25519 ")
}

function Get-Sha256Hex([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($stream)
        return Bytes-ToHexLower $hash
    } finally {
        $stream.Dispose()
    }
}

function Get-StringSha256Hex([string]$Value) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return Bytes-ToHexLower $hash
    } finally {
        $sha.Dispose()
    }
}

function New-TempPath([string]$Suffix) {
    $base = [System.IO.Path]::GetTempFileName()
    Remove-Item -LiteralPath $base -Force -ErrorAction SilentlyContinue
    return $base + $Suffix
}

function Quote-ProcessArg([string]$Arg) {
    if ($null -eq $Arg) { return '""' }
    $escaped = $Arg.Replace('"', '\"')
    if ($escaped -match '\s' -or $escaped.Contains('"')) {
        return ('"' + $escaped + '"')
    }
    return $escaped
}

function Invoke-ExternalProcess {
    param(
        [string]$FileName,
        [string[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = (($Arguments | ForEach-Object { Quote-ProcessArg ([string]$_) }) -join " ")
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{
        exit_code = $proc.ExitCode
        stdout = $stdout
        stderr = $stderr
    }
}

function Invoke-SshSignBytes {
    param(
        [byte[]]$PayloadBytes,
        [string]$PrivateKeyPath
    )

    $payloadPath = New-TempPath ".payload"
    $sigPath = $payloadPath + ".sig"
    try {
        Trace-Release ("sign:start {0}" -f $payloadPath)
        [System.IO.File]::WriteAllBytes($payloadPath, $PayloadBytes)
        $proc = Invoke-ExternalProcess -FileName "ssh-keygen" -Arguments @("-Y", "sign", "-f", $PrivateKeyPath, "-n", "file", $payloadPath)
        if ($proc.exit_code -ne 0 -or -not (Test-Path -LiteralPath $sigPath)) {
            throw ("ssh-keygen signing failed for {0}: {1}{2}" -f $payloadPath, $proc.stderr, $proc.stdout)
        }
        Trace-Release ("sign:done {0}" -f $payloadPath)
        return Get-Content -LiteralPath $sigPath -Raw
    } finally {
        Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $sigPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-SshVerifyBytes {
    param(
        [byte[]]$PayloadBytes,
        [string]$SignatureText,
        [string]$SignerIdentity,
        [string]$TrustedPublicKeyPath
    )

    $payloadPath = New-TempPath ".payload"
    $sigPath = $payloadPath + ".sig"
    $allowedPath = $payloadPath + ".allowed"
    try {
        [System.IO.File]::WriteAllBytes($payloadPath, $PayloadBytes)
        [System.IO.File]::WriteAllText($sigPath, $SignatureText, [System.Text.UTF8Encoding]::new($false))
        $pubLine = (Get-Content -LiteralPath $TrustedPublicKeyPath -Raw).Trim()
        [System.IO.File]::WriteAllText($allowedPath, "$SignerIdentity $pubLine`n", [System.Text.UTF8Encoding]::new($false))

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "ssh-keygen"
        $psi.Arguments = ((@("-Y", "verify", "-f", $allowedPath, "-I", $SignerIdentity, "-n", "file", "-s", $sigPath) | ForEach-Object { Quote-ProcessArg ([string]$_) }) -join " ")
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.BaseStream.Write($PayloadBytes, 0, $PayloadBytes.Length)
        $proc.StandardInput.Close()
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        if ($proc.ExitCode -ne 0) {
            $message = ($stderr + $stdout).Trim()
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = "ssh-keygen verify failed"
            }
            throw $message
        }
    } finally {
        Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $sigPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $allowedPath -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-ReleaseKey {
    param(
        [string]$PolicyRoot,
        [string]$KeyId,
        [bool]$AutoCreate
    )

    $priv = Release-KeyPath $PolicyRoot $KeyId
    $pub = Release-PubPath $PolicyRoot $KeyId
    $trusted = Release-TrustedKeyPath $PolicyRoot $KeyId
    Ensure-Dir (Release-SigningDir $PolicyRoot)
    Ensure-Dir (Release-TrustedDir $PolicyRoot)

    if (-not (Test-Path -LiteralPath $priv)) {
        if (-not $AutoCreate) {
            throw "release signing key '$KeyId' is missing at $priv"
        }
        $proc = Invoke-ExternalProcess -FileName "ssh-keygen" -Arguments @("-q", "-t", "ed25519", "-N", '""', "-C", ("nucleor-release:" + $KeyId), "-f", $priv)
        if ($proc.exit_code -ne 0 -or -not (Test-Path -LiteralPath $priv) -or -not (Test-Path -LiteralPath $pub)) {
            throw ("failed to generate release signing key '{0}': {1}{2}" -f $KeyId, $proc.stderr, $proc.stdout)
        }
    }

    $trustedNeedsRefresh = $true
    if (Test-Path -LiteralPath $trusted) {
        $trustedNeedsRefresh = -not (Test-OpenSshPublicKeyLine (Get-Content -LiteralPath $trusted -Raw))
    }
    if ($trustedNeedsRefresh -and (Test-Path -LiteralPath $pub)) {
        Copy-Item -LiteralPath $pub -Destination $trusted -Force
    }

    return [pscustomobject]@{
        key_id = $KeyId
        private_key = $priv
        public_key = $pub
        trusted_key = $trusted
        public_key_line = (Get-Content -LiteralPath $pub -Raw).Trim()
    }
}

function Resolve-DefaultKey {
    param([string]$PolicyRoot)
    return Ensure-ReleaseKey -PolicyRoot $PolicyRoot -KeyId "default-local" -AutoCreate $true
}

function Parse-ReleaseArgs([string[]]$RawArgs) {
    $json = $false
    $positionals = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $RawArgs.Count; $i++) {
        $arg = $RawArgs[$i]
        if ($arg -eq "--json" -or $arg -eq "--output=json") {
            $json = $true
            continue
        }
        if ($arg -eq "--output") {
            if ($i + 1 -lt $RawArgs.Count -and $RawArgs[$i + 1].ToLowerInvariant() -eq "json") {
                $json = $true
                $i++
                continue
            }
            throw (Release-UsageText)
        }
        $positionals.Add($arg)
    }
    return [pscustomobject]@{
        json = $json
        positionals = @($positionals.ToArray())
    }
}

function Get-BundleManifest([string]$BundleDir) {
    $manifestPath = Join-Path $BundleDir "release-manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "cannot read $manifestPath"
    }
    $manifest = Get-JsonFile $manifestPath
    if (-not $manifest.package -or -not $manifest.package.name -or -not $manifest.package.version) {
        throw "missing package section in $manifestPath"
    }
    if (-not $manifest.checksum_file) {
        throw "missing checksum_file in $manifestPath"
    }
    return [pscustomobject]@{
        path = $manifestPath
        object = $manifest
        package_name = [string]$manifest.package.name
        version = [string]$manifest.package.version
        checksum_file = [string]$manifest.checksum_file
        signature_file = if ($manifest.signature_file) { [string]$manifest.signature_file } else { "release-signature.json" }
        attestation_file = if ($manifest.attestation_file) { [string]$manifest.attestation_file } else { "release-attestation.json" }
        dsse_file = if ($manifest.dsse_attestation_file) { [string]$manifest.dsse_attestation_file } else { "release-attestation.dsse.json" }
    }
}

function Get-BundleSubjects($ManifestObject) {
    $subjects = New-Object System.Collections.Generic.List[object]
    foreach ($section in @(
        @{ key = "artifacts"; kind = "artifact" },
        @{ key = "docs"; kind = "documentation" },
        @{ key = "supporting_files"; kind = "supporting" }
    )) {
        $entries = $ManifestObject.$($section.key)
        if ($entries) {
            foreach ($entry in $entries) {
                $subjects.Add([pscustomobject]@{
                    kind = $section.kind
                    path = ([string]$entry.relative_path).Replace("\", "/")
                    sha256 = [string]$entry.sha256
                })
            }
        }
    }
    $subjects.Add([pscustomobject]@{
        kind = "manifest"
        path = "release-manifest.json"
        sha256 = $null
    })
    return @($subjects.ToArray())
}

function New-ReleaseSignaturePayload([string]$PackageName, [string]$Version, [string]$ManifestSha, [string]$ChecksumsFile, [string]$ChecksumsSha) {
    return [System.Text.Encoding]::UTF8.GetBytes(("nucleor-release-bundle-v1`n{0}`n{1}`nrelease-manifest.json`n{2}`n{3}`n{4}`n" -f $PackageName, $Version, $ManifestSha, $ChecksumsFile.Replace("\", "/"), $ChecksumsSha))
}

function New-ReleaseAttestationPayload([string]$PackageName, [string]$Version, [string]$ManifestSha, [string]$ChecksumsSha, [string]$PredicateSha) {
    return [System.Text.Encoding]::UTF8.GetBytes(("nucleor-release-attestation-v1`n{0}`n{1}`n{2}`n{3}`n{4}`n" -f $PackageName, $Version, $ManifestSha, $ChecksumsSha, $PredicateSha))
}

function New-DssePaeBytes([string]$PayloadType, [byte[]]$PayloadBytes) {
    $prefix = [System.Text.Encoding]::UTF8.GetBytes(("DSSEv1 {0} {1} {2} " -f $PayloadType.Length, $PayloadType, $PayloadBytes.Length))
    $buffer = New-Object byte[] ($prefix.Length + $PayloadBytes.Length)
    [Array]::Copy($prefix, 0, $buffer, 0, $prefix.Length)
    [Array]::Copy($PayloadBytes, 0, $buffer, $prefix.Length, $PayloadBytes.Length)
    return $buffer
}

function Get-UnixTimeSeconds {
    return [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
}

function Write-ReleaseBundleDocuments {
    param(
        [string]$BundleDir,
        [string]$PolicyRoot
    )

    Trace-Release "bundle:load"
    $bundle = Get-BundleManifest $BundleDir
    $checksumsPath = Join-Path $BundleDir $bundle.checksum_file
    if (-not (Test-Path -LiteralPath $checksumsPath)) {
        throw "cannot read $checksumsPath"
    }
    $manifestSha = Get-Sha256Hex $bundle.path
    $checksumsSha = Get-Sha256Hex $checksumsPath
    Trace-Release "bundle:hashes"
    $key = Resolve-DefaultKey $PolicyRoot
    Trace-Release "bundle:key"
    $signatureArmored = Invoke-SshSignBytes -PayloadBytes (New-ReleaseSignaturePayload $bundle.package_name $bundle.version $manifestSha $bundle.checksum_file $checksumsSha) -PrivateKeyPath $key.private_key
    $signedAt = Get-UnixTimeSeconds
    Trace-Release "bundle:signature-values"

    $signatureDoc = [ordered]@{
        schema_version = 1
        package = [ordered]@{
            name = $bundle.package_name
            version = $bundle.version
        }
        files = [ordered]@{
            manifest = "release-manifest.json"
            manifest_sha256 = $manifestSha
            checksums = $bundle.checksum_file.Replace("\", "/")
            checksums_sha256 = $checksumsSha
        }
        signing = [ordered]@{
            algorithm = "ssh-ed25519"
            mode = "openssh-y-sign"
            key_id = $key.key_id
            public_key = $key.public_key_line
            signature = $signatureArmored
            signed_at_unix_s = $signedAt
        }
    }
    Trace-Release "bundle:signature-doc-obj"
    $signaturePath = Join-Path $BundleDir $bundle.signature_file
    Trace-Release "bundle:signature-write"
    Write-JsonFile $signaturePath $signatureDoc
    Trace-Release "bundle:signature-doc"

    $subjects = New-Object System.Collections.Generic.List[object]
    foreach ($entry in (Get-BundleSubjects $bundle.object | Sort-Object path)) {
        if ($entry.kind -eq "manifest") {
            $subjects.Add([ordered]@{
                kind = "manifest"
                path = "release-manifest.json"
                sha256 = $manifestSha
            })
            $subjects.Add([ordered]@{
                kind = "checksums"
                path = $bundle.checksum_file.Replace("\", "/")
                sha256 = $checksumsSha
            })
            continue
        }
        $subjects.Add([ordered]@{
            kind = $entry.kind
            path = $entry.path
            sha256 = $entry.sha256
        })
    }
    $predicate = [ordered]@{
        predicate_type = "https://nucleor.dev/attestation/release-bundle/v1"
        generated_at_utc = [string]($bundle.object.generated_at_utc)
        subject = @($subjects.ToArray())
        artifact_count = @($bundle.object.artifacts).Count
        documentation_count = @($bundle.object.docs).Count
        supporting_file_count = @($bundle.object.supporting_files).Count
        host = $bundle.object.host
        toolchain = $bundle.object.toolchain
        validation = $bundle.object.validation
    }
    $predicateJson = $predicate | ConvertTo-Json -Depth 16 -Compress
    $predicateSha = Get-StringSha256Hex $predicateJson
    Trace-Release "bundle:predicate"
    $attestationArmored = Invoke-SshSignBytes -PayloadBytes (New-ReleaseAttestationPayload $bundle.package_name $bundle.version $manifestSha $checksumsSha $predicateSha) -PrivateKeyPath $key.private_key
    $attestationDoc = [ordered]@{
        schema_version = 1
        package = [ordered]@{
            name = $bundle.package_name
            version = $bundle.version
        }
        files = [ordered]@{
            manifest = "release-manifest.json"
            manifest_sha256 = $manifestSha
            checksums = $bundle.checksum_file.Replace("\", "/")
            checksums_sha256 = $checksumsSha
            predicate_sha256 = $predicateSha
        }
        predicate = $predicate
        signing = [ordered]@{
            algorithm = "ssh-ed25519"
            mode = "openssh-y-sign"
            key_id = $key.key_id
            public_key = $key.public_key_line
            signature = $attestationArmored
            signed_at_unix_s = $signedAt
        }
    }
    $attestationPath = Join-Path $BundleDir $bundle.attestation_file
    Write-JsonFile $attestationPath $attestationDoc
    Trace-Release "bundle:attestation-doc"

    $statement = [ordered]@{
        _type = "https://in-toto.io/Statement/v1"
        subject = @($subjects.ToArray() | ForEach-Object {
                [ordered]@{
                    name = $_.path
                    digest = [ordered]@{ sha256 = $_.sha256 }
                }
            })
        predicateType = "https://nucleor.dev/attestation/release-bundle/v1"
        predicate = $predicate
    }
    $statementJson = $statement | ConvertTo-Json -Depth 18 -Compress
    $statementBytes = [System.Text.Encoding]::UTF8.GetBytes($statementJson)
    Trace-Release "bundle:statement"
    $dsseArmored = Invoke-SshSignBytes -PayloadBytes (New-DssePaeBytes "application/vnd.in-toto+json" $statementBytes) -PrivateKeyPath $key.private_key
    $dsseDoc = [ordered]@{
        payloadType = "application/vnd.in-toto+json"
        payload = [Convert]::ToBase64String($statementBytes)
        signatures = @(
            [ordered]@{
                keyid = $key.key_id
                format = "openssh-armored"
                sig = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($dsseArmored))
            }
        )
        signing = [ordered]@{
            algorithm = "ssh-ed25519"
            mode = "openssh-y-sign"
            signed_at_unix_s = $signedAt
        }
    }
    $dssePath = Join-Path $BundleDir $bundle.dsse_file
    Write-JsonFile $dssePath $dsseDoc
    Trace-Release "bundle:dsse-doc"

    return [pscustomobject]@{
        bundle_dir = $BundleDir
        package_name = $bundle.package_name
        version = $bundle.version
        key_id = $key.key_id
        signature_file = $bundle.signature_file
        attestation_file = $bundle.attestation_file
        dsse_attestation_file = $bundle.dsse_file
        signature_path = $signaturePath
        attestation_path = $attestationPath
        dsse_path = $dssePath
        policy_root = $PolicyRoot
    }
}

function Verify-ReleaseBundleDocuments {
    param(
        [string]$BundleDir,
        [string]$PolicyRoot
    )

    $bundle = Get-BundleManifest $BundleDir
    $signaturePath = Join-Path $BundleDir $bundle.signature_file
    $attestationPath = Join-Path $BundleDir $bundle.attestation_file
    $dssePath = Join-Path $BundleDir $bundle.dsse_file
    foreach ($path in @($signaturePath, $attestationPath, $dssePath)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "missing release bundle signature material: $path"
        }
    }
    $signatureDoc = Get-JsonFile $signaturePath
    $attestationDoc = Get-JsonFile $attestationPath
    $dsseDoc = Get-JsonFile $dssePath
    $keyId = [string]$signatureDoc.signing.key_id
    if ([string]::IsNullOrWhiteSpace($keyId)) {
        throw "missing signing.key_id in $signaturePath"
    }
    $trustedKey = Release-TrustedKeyPath $PolicyRoot $keyId
    if (Test-Path -LiteralPath $trustedKey) {
        $trustedRaw = Get-Content -LiteralPath $trustedKey -Raw
        if (-not (Test-OpenSshPublicKeyLine $trustedRaw)) {
            $pubCandidate = Release-PubPath $PolicyRoot $keyId
            if (Test-Path -LiteralPath $pubCandidate) {
                Copy-Item -LiteralPath $pubCandidate -Destination $trustedKey -Force
            }
        }
    }
    if (-not (Test-Path -LiteralPath $trustedKey)) {
        throw "trusted release key is missing: $trustedKey"
    }

    $checksumsPath = Join-Path $BundleDir $bundle.checksum_file
    $manifestSha = Get-Sha256Hex $bundle.path
    $checksumsSha = Get-Sha256Hex $checksumsPath
    if ([string]$signatureDoc.files.manifest_sha256 -ne $manifestSha) {
        throw "release manifest checksum mismatch"
    }
    if ([string]$signatureDoc.files.checksums_sha256 -ne $checksumsSha) {
        throw "release checksum file mismatch"
    }
    Invoke-SshVerifyBytes -PayloadBytes (New-ReleaseSignaturePayload $bundle.package_name $bundle.version $manifestSha $bundle.checksum_file $checksumsSha) -SignatureText ([string]$signatureDoc.signing.signature) -SignerIdentity $keyId -TrustedPublicKeyPath $trustedKey

    $predicateJson = ($attestationDoc.predicate | ConvertTo-Json -Depth 18 -Compress)
    $predicateSha = Get-StringSha256Hex $predicateJson
    if ([string]$attestationDoc.files.predicate_sha256 -ne $predicateSha) {
        throw "release attestation predicate checksum mismatch"
    }
    Invoke-SshVerifyBytes -PayloadBytes (New-ReleaseAttestationPayload $bundle.package_name $bundle.version $manifestSha $checksumsSha $predicateSha) -SignatureText ([string]$attestationDoc.signing.signature) -SignerIdentity $keyId -TrustedPublicKeyPath $trustedKey

    $payloadType = [string]$dsseDoc.payloadType
    $payloadBytes = [Convert]::FromBase64String([string]$dsseDoc.payload)
    $sigText = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$dsseDoc.signatures[0].sig))
    Invoke-SshVerifyBytes -PayloadBytes (New-DssePaeBytes $payloadType $payloadBytes) -SignatureText $sigText -SignerIdentity $keyId -TrustedPublicKeyPath $trustedKey

    return [pscustomobject]@{
        bundle_dir = $BundleDir
        package_name = $bundle.package_name
        version = $bundle.version
        key_id = $keyId
        signature_file = $bundle.signature_file
        attestation_file = $bundle.attestation_file
        dsse_attestation_file = $bundle.dsse_file
        signed = $true
        policy_root = $PolicyRoot
    }
}

function Package-MetadataPath([string]$PackageDir) {
    return (Join-Path $PackageDir "Nucleor.publish.json")
}

function Package-SignaturePath([string]$PackageDir) {
    return (Join-Path $PackageDir "Nucleor.publish.signature.json")
}

function Package-ChecksumPath([string]$PackageDir) {
    return (Join-Path $PackageDir "Nucleor.package.sha256")
}

function New-PackageSignaturePayload {
    param(
        $MetadataDoc,
        [string]$MetadataSha,
        [string]$ChecksumSha,
        [string]$ExportsSha
    )

    $exportsManifest = $null
    if ($MetadataDoc.exports -and $MetadataDoc.exports.present -and -not [string]::IsNullOrWhiteSpace([string]$MetadataDoc.exports.manifest)) {
        $exportsManifest = [string]$MetadataDoc.exports.manifest
    }

    $payload = [ordered]@{
        type = "nucleor.package-signature.v1"
        package = [ordered]@{
            name = [string]$MetadataDoc.package.name
            version = [string]$MetadataDoc.package.version
        }
        files = [ordered]@{
            metadata_file = "Nucleor.publish.json"
            metadata_sha256 = $MetadataSha
            checksum_file = "Nucleor.package.sha256"
            checksum_sha256 = $ChecksumSha
            exports_manifest = $exportsManifest
            exports_sha256 = $(if ([string]::IsNullOrWhiteSpace($ExportsSha)) { $null } else { $ExportsSha })
        }
    }

    return [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-DeterministicJson $payload))
}

function Write-PackageSignatureDocument {
    param(
        [string]$PackageDir,
        [string]$PolicyRoot,
        [string]$RequestedKeyId
    )

    $metadataPath = Package-MetadataPath $PackageDir
    $signaturePath = Package-SignaturePath $PackageDir
    $checksumPath = Package-ChecksumPath $PackageDir
    foreach ($path in @($metadataPath, $checksumPath)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "missing package signing input: $path"
        }
    }

    $metadataDoc = Get-JsonFile $metadataPath
    $keyId = $RequestedKeyId
    if ([string]::IsNullOrWhiteSpace($keyId) -and $metadataDoc.signing) {
        $keyId = [string]$metadataDoc.signing.key_id
    }
    $key = if ([string]::IsNullOrWhiteSpace($keyId)) {
        Resolve-DefaultKey $PolicyRoot
    } else {
        Ensure-ReleaseKey -PolicyRoot $PolicyRoot -KeyId $keyId -AutoCreate $true
    }

    $metadataSha = Get-Sha256Hex $metadataPath
    $checksumSha = Get-Sha256Hex $checksumPath
    $exportsSha = $null
    if ($metadataDoc.exports -and $metadataDoc.exports.present -and -not [string]::IsNullOrWhiteSpace([string]$metadataDoc.exports.manifest)) {
        $exportsPath = Join-Path $PackageDir ([string]$metadataDoc.exports.manifest)
        if (-not (Test-Path -LiteralPath $exportsPath)) {
            throw "missing package export manifest: $exportsPath"
        }
        $exportsSha = Get-Sha256Hex $exportsPath
    }

    $payloadBytes = New-PackageSignaturePayload -MetadataDoc $metadataDoc -MetadataSha $metadataSha -ChecksumSha $checksumSha -ExportsSha $exportsSha
    $signatureText = Invoke-SshSignBytes -PayloadBytes $payloadBytes -PrivateKeyPath $key.private_key
    $signedAt = [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

    $signatureDoc = [ordered]@{
        schema_version = 1
        type = "package_signature"
        package = [ordered]@{
            name = [string]$metadataDoc.package.name
            version = [string]$metadataDoc.package.version
        }
        files = [ordered]@{
            metadata_file = "Nucleor.publish.json"
            metadata_sha256 = $metadataSha
            checksum_file = "Nucleor.package.sha256"
            checksum_sha256 = $checksumSha
            exports_manifest = $(if ($metadataDoc.exports -and $metadataDoc.exports.present) { [string]$metadataDoc.exports.manifest } else { $null })
            exports_sha256 = $(if ([string]::IsNullOrWhiteSpace($exportsSha)) { $null } else { $exportsSha })
        }
        signing = [ordered]@{
            algorithm = "ssh-ed25519"
            mode = "openssh-y-sign"
            key_id = $key.key_id
            signed_at_unix_s = $signedAt
            signature = $signatureText
        }
    }

    Write-JsonFile $signaturePath $signatureDoc
    return [pscustomobject]@{
        package_dir = $PackageDir
        package = [string]$metadataDoc.package.name
        version = [string]$metadataDoc.package.version
        key_id = $key.key_id
        signature_file = [System.IO.Path]::GetFileName($signaturePath)
        signature_path = $signaturePath
        signed = $true
    }
}

function Get-PackageSignaturePreflight {
    param(
        [string]$PackageDir,
        [string]$PolicyRoot,
        [string]$RequestedKeyId
    )

    $metadataPath = Package-MetadataPath $PackageDir
    $signaturePath = Package-SignaturePath $PackageDir
    $checksumPath = Package-ChecksumPath $PackageDir
    foreach ($path in @($metadataPath, $checksumPath)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "missing package signing input: $path"
        }
    }

    $metadataDoc = Get-JsonFile $metadataPath
    $keyId = $RequestedKeyId
    $keySource = "requested"
    if ([string]::IsNullOrWhiteSpace($keyId) -and $metadataDoc.signing) {
        $keyId = [string]$metadataDoc.signing.key_id
        $keySource = "metadata"
    }
    if ([string]::IsNullOrWhiteSpace($keyId)) {
        $keyId = "default-local"
        $keySource = "default"
    }

    $exportsManifest = $null
    $exportsPath = $null
    $exportsPresent = $false
    if ($metadataDoc.exports -and $metadataDoc.exports.present -and -not [string]::IsNullOrWhiteSpace([string]$metadataDoc.exports.manifest)) {
        $exportsManifest = [string]$metadataDoc.exports.manifest
        $exportsPath = Join-Path $PackageDir $exportsManifest
        $exportsPresent = Test-Path -LiteralPath $exportsPath
        if (-not $exportsPresent) {
            throw "missing package export manifest: $exportsPath"
        }
    }

    $privateKeyPath = Release-KeyPath $PolicyRoot $keyId
    $publicKeyPath = Release-PubPath $PolicyRoot $keyId
    $keyPresent = (Test-Path -LiteralPath $privateKeyPath) -and (Test-Path -LiteralPath $publicKeyPath)
    $signatureExists = Test-Path -LiteralPath $signaturePath
    $failureReason = $null
    if (-not $keyPresent) {
        $failureReason = "release signing key '$keyId' is missing at $privateKeyPath"
    }

    return [pscustomobject]@{
        package_dir = $PackageDir
        package = [string]$metadataDoc.package.name
        version = [string]$metadataDoc.package.version
        metadata_path = $metadataPath
        checksum_path = $checksumPath
        exports_manifest = $exportsManifest
        exports_manifest_path = $exportsPath
        exports_manifest_present = $exportsPresent
        key_id = $keyId
        key_id_source = $keySource
        private_key_path = $privateKeyPath
        public_key_path = $publicKeyPath
        key_present = $keyPresent
        signature_path = $signaturePath
        signature_exists = $signatureExists
        would_overwrite_signature = $signatureExists
        would_write_signature = $false
        status = $(if ($keyPresent) { "ready" } else { "blocked" })
        failure_reason = $failureReason
    }
}

function Write-PackageSignaturePreflightText($Result) {
    Write-Host ("package_dir: {0}" -f $Result.package_dir)
    Write-Host ("package: {0}" -f $Result.package)
    Write-Host ("version: {0}" -f $Result.version)
    Write-Host ("metadata_path: {0}" -f $Result.metadata_path)
    Write-Host ("checksum_path: {0}" -f $Result.checksum_path)
    Write-Host ("exports_manifest_path: {0}" -f $Result.exports_manifest_path)
    Write-Host ("key_id: {0}" -f $Result.key_id)
    Write-Host ("key_id_source: {0}" -f $Result.key_id_source)
    Write-Host ("key_present: {0}" -f $(if ($Result.key_present) { "yes" } else { "no" }))
    Write-Host ("signature_path: {0}" -f $Result.signature_path)
    Write-Host ("signature_exists: {0}" -f $(if ($Result.signature_exists) { "yes" } else { "no" }))
    Write-Host ("would_overwrite_signature: {0}" -f $(if ($Result.would_overwrite_signature) { "yes" } else { "no" }))
    Write-Host ("would_write_signature: {0}" -f $(if ($Result.would_write_signature) { "yes" } else { "no" }))
    Write-Host ("status: {0}" -f $Result.status)
    if ($Result.failure_reason) {
        Write-Host ("failure_reason: {0}" -f $Result.failure_reason)
    }
}

function Verify-PackageSignatureDocument {
    param(
        [string]$PackageDir,
        [string]$PolicyRoot
    )

    $metadataPath = Package-MetadataPath $PackageDir
    $signaturePath = Package-SignaturePath $PackageDir
    $checksumPath = Package-ChecksumPath $PackageDir
    foreach ($path in @($metadataPath, $signaturePath, $checksumPath)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "missing package verification input: $path"
        }
    }

    $metadataDoc = Get-JsonFile $metadataPath
    $signatureDoc = Get-JsonFile $signaturePath
    $keyId = [string]$signatureDoc.signing.key_id
    if ([string]::IsNullOrWhiteSpace($keyId)) {
        throw "missing signing.key_id in $signaturePath"
    }

    $trustedKey = Release-TrustedKeyPath $PolicyRoot $keyId
    if (Test-Path -LiteralPath $trustedKey) {
        $trustedRaw = Get-Content -LiteralPath $trustedKey -Raw
        if (-not (Test-OpenSshPublicKeyLine $trustedRaw)) {
            $pubCandidate = Release-PubPath $PolicyRoot $keyId
            if (Test-Path -LiteralPath $pubCandidate) {
                Copy-Item -LiteralPath $pubCandidate -Destination $trustedKey -Force
            }
        }
    }
    if (-not (Test-Path -LiteralPath $trustedKey)) {
        throw "trusted release key is missing: $trustedKey"
    }

    if ([string]$signatureDoc.package.name -ne [string]$metadataDoc.package.name -or [string]$signatureDoc.package.version -ne [string]$metadataDoc.package.version) {
        throw "package signature identity does not match package metadata"
    }

    $metadataSha = Get-Sha256Hex $metadataPath
    $checksumSha = Get-Sha256Hex $checksumPath
    if ([string]$signatureDoc.files.metadata_sha256 -ne $metadataSha) {
        throw "package metadata checksum mismatch"
    }
    if ([string]$signatureDoc.files.checksum_sha256 -ne $checksumSha) {
        throw "package checksum file mismatch"
    }

    $exportsSha = $null
    if ($metadataDoc.exports -and $metadataDoc.exports.present -and -not [string]::IsNullOrWhiteSpace([string]$metadataDoc.exports.manifest)) {
        $exportsPath = Join-Path $PackageDir ([string]$metadataDoc.exports.manifest)
        if (-not (Test-Path -LiteralPath $exportsPath)) {
            throw "missing package export manifest: $exportsPath"
        }
        $exportsSha = Get-Sha256Hex $exportsPath
        if ([string]$signatureDoc.files.exports_sha256 -ne $exportsSha) {
            throw "package export manifest checksum mismatch"
        }
    }

    $payloadBytes = New-PackageSignaturePayload -MetadataDoc $metadataDoc -MetadataSha $metadataSha -ChecksumSha $checksumSha -ExportsSha $exportsSha
    Invoke-SshVerifyBytes -PayloadBytes $payloadBytes -SignatureText ([string]$signatureDoc.signing.signature) -SignerIdentity $keyId -TrustedPublicKeyPath $trustedKey

    return [pscustomobject]@{
        package_dir = $PackageDir
        package = [string]$metadataDoc.package.name
        version = [string]$metadataDoc.package.version
        key_id = $keyId
        signature_file = [System.IO.Path]::GetFileName($signaturePath)
        signed = $true
        algorithm = [string]$signatureDoc.signing.algorithm
    }
}

if ($Help) {
    Show-ReleaseUsage
    return
}
if ([string]::IsNullOrWhiteSpace($Root)) {
    throw (Release-UsageText)
}
$Root = [System.IO.Path]::GetFullPath($Root)

$parsed = Parse-ReleaseArgs $ForwardArgs
$jsonOutput = $parsed.json
$positionals = $parsed.positionals
$policyRoot = Get-PolicyRoot

try {
    switch ($positionals.Count) {
        0 {
            throw (Release-UsageText)
        }
        1 {
            if ($positionals[0] -eq "keygen") {
                $key = Resolve-DefaultKey $policyRoot
                $result = [ordered]@{
                    policy_root = $policyRoot
                    key_id = $key.key_id
                    signing_key = $key.private_key
                    trusted_key = $key.trusted_key
                    public_key = $key.public_key_line
                }
                if ($jsonOutput) {
                    $result | ConvertTo-Json -Depth 8
                } else {
                    foreach ($entry in $result.GetEnumerator()) {
                        Write-Host ("{0}: {1}" -f $entry.Key, $entry.Value)
                    }
                }
                return
            }
            throw (Release-UsageText)
        }
        2 {
            switch ($positionals[0]) {
                "keygen" {
                    $keyId = $positionals[1]
                    $existing = Release-KeyPath $policyRoot $keyId
                    if (Test-Path -LiteralPath $existing) {
                        throw "release signing key '$keyId' already exists at $existing"
                    }
                    $key = Ensure-ReleaseKey -PolicyRoot $policyRoot -KeyId $keyId -AutoCreate $true
                    $result = [ordered]@{
                        policy_root = $policyRoot
                        key_id = $key.key_id
                        signing_key = $key.private_key
                        trusted_key = $key.trusted_key
                        public_key = $key.public_key_line
                    }
                    if ($jsonOutput) { $result | ConvertTo-Json -Depth 8 } else { foreach ($entry in $result.GetEnumerator()) { Write-Host ("{0}: {1}" -f $entry.Key, $entry.Value) } }
                    return
                }
                "sign-bundle" {
                    $bundleDir = Resolve-PathMaybeRelative (Get-Location).Path $positionals[1]
                    $result = Write-ReleaseBundleDocuments -BundleDir $bundleDir -PolicyRoot $policyRoot
                    if ($jsonOutput) {
                        [ordered]@{
                            bundle_dir = $result.bundle_dir
                            package = $result.package_name
                            version = $result.version
                            key_id = $result.key_id
                            signature_file = $result.signature_file
                            attestation_file = $result.attestation_file
                            dsse_attestation_file = $result.dsse_attestation_file
                            signature_path = $result.signature_path
                        } | ConvertTo-Json -Depth 8
                    } else {
                        Write-Host ("bundle: {0}" -f $result.bundle_dir)
                        Write-Host ("package: {0}" -f $result.package_name)
                        Write-Host ("version: {0}" -f $result.version)
                        Write-Host ("key_id: {0}" -f $result.key_id)
                        Write-Host ("signature: {0}" -f $result.signature_path)
                        Write-Host ("attestation_file: {0}" -f $result.attestation_file)
                        Write-Host ("dsse_attestation_file: {0}" -f $result.dsse_attestation_file)
                    }
                    return
                }
                "verify-bundle" {
                    $bundleDir = Resolve-PathMaybeRelative (Get-Location).Path $positionals[1]
                    $result = Verify-ReleaseBundleDocuments -BundleDir $bundleDir -PolicyRoot $policyRoot
                    if ($jsonOutput) {
                        $result | ConvertTo-Json -Depth 8
                    } else {
                        Write-Host ("bundle: {0}" -f $result.bundle_dir)
                        Write-Host ("package: {0}" -f $result.package_name)
                        Write-Host ("version: {0}" -f $result.version)
                        Write-Host ("key_id: {0}" -f $result.key_id)
                        Write-Host ("signature_file: {0}" -f $result.signature_file)
                        Write-Host ("attestation_file: {0}" -f $result.attestation_file)
                        Write-Host ("dsse_attestation_file: {0}" -f $result.dsse_attestation_file)
                        Write-Host "signed: yes"
                    }
                    return
                }
                "package-sign" {
                    $packageDir = Resolve-PathMaybeRelative (Get-Location).Path $positionals[1]
                    $result = Write-PackageSignatureDocument -PackageDir $packageDir -PolicyRoot $policyRoot -RequestedKeyId ""
                    if ($jsonOutput) {
                        $result | ConvertTo-Json -Depth 8
                    } else {
                        Write-Host ("package: {0}" -f $result.package)
                        Write-Host ("version: {0}" -f $result.version)
                        Write-Host ("key_id: {0}" -f $result.key_id)
                        Write-Host ("signature: {0}" -f $result.signature_path)
                    }
                    return
                }
                "package-sign-preflight" {
                    $packageDir = Resolve-PathMaybeRelative (Get-Location).Path $positionals[1]
                    $result = Get-PackageSignaturePreflight -PackageDir $packageDir -PolicyRoot $policyRoot -RequestedKeyId ""
                    if ($jsonOutput) { $result | ConvertTo-Json -Depth 8 } else { Write-PackageSignaturePreflightText $result }
                    return
                }
                "package-verify" {
                    $packageDir = Resolve-PathMaybeRelative (Get-Location).Path $positionals[1]
                    $result = Verify-PackageSignatureDocument -PackageDir $packageDir -PolicyRoot $policyRoot
                    if ($jsonOutput) {
                        $result | ConvertTo-Json -Depth 8
                    } else {
                        Write-Host ("package: {0}" -f $result.package)
                        Write-Host ("version: {0}" -f $result.version)
                        Write-Host ("key_id: {0}" -f $result.key_id)
                        Write-Host ("signature_file: {0}" -f $result.signature_file)
                        Write-Host "signed: yes"
                    }
                    return
                }
                default {
                    throw (Release-UsageText)
                }
            }
        }
        3 {
            switch ($positionals[0]) {
                "package-sign" {
                    $packageDir = Resolve-PathMaybeRelative (Get-Location).Path $positionals[1]
                    $result = Write-PackageSignatureDocument -PackageDir $packageDir -PolicyRoot $policyRoot -RequestedKeyId $positionals[2]
                    if ($jsonOutput) { $result | ConvertTo-Json -Depth 8 } else {
                        Write-Host ("package: {0}" -f $result.package)
                        Write-Host ("version: {0}" -f $result.version)
                        Write-Host ("key_id: {0}" -f $result.key_id)
                        Write-Host ("signature: {0}" -f $result.signature_path)
                    }
                    return
                }
                "package-sign-preflight" {
                    $packageDir = Resolve-PathMaybeRelative (Get-Location).Path $positionals[1]
                    $result = Get-PackageSignaturePreflight -PackageDir $packageDir -PolicyRoot $policyRoot -RequestedKeyId $positionals[2]
                    if ($jsonOutput) { $result | ConvertTo-Json -Depth 8 } else { Write-PackageSignaturePreflightText $result }
                    return
                }
                "export-key" {
                    $keyId = $positionals[1]
                    $dest = Resolve-PathMaybeRelative (Get-Location).Path $positionals[2]
                    Ensure-Dir ([System.IO.Path]::GetDirectoryName($dest))
                    $trusted = Release-TrustedKeyPath $policyRoot $keyId
                    $pub = Release-PubPath $policyRoot $keyId
                    if (Test-Path -LiteralPath $trusted) {
                        Copy-Item -LiteralPath $trusted -Destination $dest -Force
                    } elseif (Test-Path -LiteralPath $pub) {
                        Copy-Item -LiteralPath $pub -Destination $dest -Force
                    } else {
                        throw "release signing key '$keyId' is missing"
                    }
                    $result = [ordered]@{
                        policy_root = $policyRoot
                        key_id = $keyId
                        exported_key = $dest
                    }
                    if ($jsonOutput) { $result | ConvertTo-Json -Depth 8 } else { foreach ($entry in $result.GetEnumerator()) { Write-Host ("{0}: {1}" -f $entry.Key, $entry.Value) } }
                    return
                }
                "trust-key" {
                    $keyId = $positionals[1]
                    $source = Resolve-PathMaybeRelative (Get-Location).Path $positionals[2]
                    if (-not (Test-Path -LiteralPath $source)) {
                        throw "cannot read $source"
                    }
                    Ensure-Dir (Release-TrustedDir $policyRoot)
                    $dest = Release-TrustedKeyPath $policyRoot $keyId
                    Copy-Item -LiteralPath $source -Destination $dest -Force
                    $result = [ordered]@{
                        policy_root = $policyRoot
                        key_id = $keyId
                        source_key = $source
                        trusted_key = $dest
                    }
                    if ($jsonOutput) { $result | ConvertTo-Json -Depth 8 } else { foreach ($entry in $result.GetEnumerator()) { Write-Host ("{0}: {1}" -f $entry.Key, $entry.Value) } }
                    return
                }
                default {
                    throw (Release-UsageText)
                }
            }
        }
        default {
            throw (Release-UsageText)
        }
    }
} catch {
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
        throw ($_.Exception.Message + [Environment]::NewLine + $_.InvocationInfo.PositionMessage)
    } else {
        throw $_.Exception.Message
    }
    return
}
