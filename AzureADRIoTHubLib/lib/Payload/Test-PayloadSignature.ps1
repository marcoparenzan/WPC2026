function Test-PayloadSignature {
    <#
    .SYNOPSIS
    DEVICE side: checks the hash and the signature of a payload with the public key.
    .PARAMETER ScriptPath
    The payload file.
    .PARAMETER ManifestPath
    Its manifest (JSON).
    .PARAMETER PublicKeyPath
    PEM file with the public signing key (the only key the device holds).
    .OUTPUTS
    'ok', 'hash diverso' (the file was altered) or 'firma non valida' (the signature does not match).
    #>
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$PublicKeyPath
    )

    # The device holds only the PUBLIC key: it can verify signatures but never create one.
    $pub = [Security.Cryptography.ECDsa]::Create()
    $pub.ImportFromPem([IO.File]::ReadAllText($PublicKeyPath))

    $bytes = [IO.File]::ReadAllBytes($ScriptPath)
    $m     = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    # First check: the hash. It tells apart "the file changed" from "the signature is wrong".
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLower()
    if ($hash -ne $m.sha256) {
        return 'hash diverso'
    }

    # Second check: the signature, over the same bytes and with the same format used by Publish-Payload.
    $ok = $pub.VerifyData(
        $bytes,
        [Convert]::FromHexString($m.sig),
        [Security.Cryptography.HashAlgorithmName]::SHA384,
        [Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)

    if ($ok) { 'ok' } else { 'firma non valida' }
}
