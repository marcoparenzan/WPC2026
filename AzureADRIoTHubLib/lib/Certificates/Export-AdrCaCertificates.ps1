function Export-AdrCaCertificates {
    <#
    .SYNOPSIS
    Writes the ADR Issuing CA and Root CA certificates, taken from the chain a device received, as PEM files.
    .DESCRIPTION
    The chain issued by ADR to a device (issued-chain.pem) has three certificates: the device, the Issuing CA, the Root CA.
    The two CAs are public, and other services need them to trust the device certificates:
      adr-ica.pem    the Issuing CA alone: what Event Grid wants (the immediate parent of the device certificate)
      adr-root.pem   the Root CA alone
      adr-trust.pem  Issuing CA + Root CA: what the certificate API (api\cert-api.cs) reads
    No private key is involved: nothing here is secret.
    .PARAMETER ChainPath
    A chain file written by Export-IssuedChain (issued-chain.pem), with the three certificates in order.
    .PARAMETER OutDir
    Folder that receives the three files (created if missing).
    .OUTPUTS
    Object with Ica, Root and Trust (paths) and IcaSubject (the name of the Issuing CA).
    #>
    param(
        [Parameter(Mandatory)][string]$ChainPath,
        [Parameter(Mandatory)][string]$OutDir
    )

    # Cut the PEM blocks out of the chain file, in order.
    $blocks = @([regex]::Matches([IO.File]::ReadAllText($ChainPath), '-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', 'Singleline') |
        ForEach-Object { $_.Value })

    # Device, Issuing CA, Root CA: with fewer than three there is no CA to export.
    if ($blocks.Count -lt 3) {
        throw "The chain $ChainPath has $($blocks.Count) certificate(s): the device, the Issuing CA and the Root CA are expected."
    }

    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $ica   = Join-Path $OutDir 'adr-ica.pem'
    $root  = Join-Path $OutDir 'adr-root.pem'
    $trust = Join-Path $OutDir 'adr-trust.pem'
    $utf8  = [Text.UTF8Encoding]::new($false)
    # No line break after the last -----END CERTIFICATE-----: the Event Grid service answers "must be in valid PEM format" (400) to a
    # PEM that ends with one, and the az command sends the file as it is (seen on 2026-11-22; the same certificate without it is accepted).
    [IO.File]::WriteAllText($ica,   $blocks[1], $utf8)
    [IO.File]::WriteAllText($root,  $blocks[2], $utf8)
    [IO.File]::WriteAllText($trust, $blocks[1] + "`n" + $blocks[2], $utf8)

    # The subject of the Issuing CA, to show in a notebook that it really is the CA of ADR.
    $c = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($blocks[1])
    try { $subject = $c.Subject } finally { $c.Dispose() }

    return [pscustomobject]@{ Ica = $ica; Root = $root; Trust = $trust; IcaSubject = $subject }
}
