function Publish-Payload {
    <#
    .SYNOPSIS
    SERVER side: signs a payload and writes the script and its manifest to the outbox.
    .DESCRIPTION
    Writes thermostat-<Version>.ps1 and thermostat-<Version>.json. The manifest holds the version, the SHA-256 of the file
    and the ECDSA P-384 / SHA-384 signature (IEEE P1363, hex).
    .PARAMETER Version
    Version of the payload, for example 1.0.0.
    .PARAMETER Script
    The text of the payload.
    .PARAMETER Dir
    Outbox folder.
    .PARAMETER SigningKey
    Private signing key (System.Security.Cryptography.ECDsa). Only the server has it.
    .NOTES
    Replaces the function that used to be defined inside notebook 06, which read the key from $signKey.
    #>
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][Security.Cryptography.ECDsa]$SigningKey
    )

    # Sign the exact bytes that will be written to disk (UTF-8, no BOM): the device hashes and verifies the file bytes,
    # so signing a differently encoded copy would never match.
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Script)

    # IEEE P1363 = raw r||s, fixed length: the same format on every platform (the default would be DER).
    $sig = $SigningKey.SignData(
        $bytes,
        [Security.Cryptography.HashAlgorithmName]::SHA384,
        [Security.Cryptography.DSASignatureFormat]::IeeeP1363FixedFieldConcatenation)

    [IO.File]::WriteAllBytes((Join-Path $Dir "thermostat-$Version.ps1"), $bytes)

    # The manifest travels with the script: version, signature, and a SHA-256 that gives a first,
    # clearer "file was altered" answer before the signature is checked.
    [ordered]@{
        version = $Version
        sig     = [Convert]::ToHexString($sig).ToLower()
        sha256  = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLower()
    } | ConvertTo-Json | Set-Content (Join-Path $Dir "thermostat-$Version.json") -Encoding utf8
}
