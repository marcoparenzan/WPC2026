function New-DemoLeaf {
    <#
    .SYNOPSIS
    Creates the bootstrap certificate of a device (client authentication) signed by a local CA.
    .DESCRIPTION
    The bootstrap certificate only introduces the device to DPS. The file bootstrap-chain.pem holds the leaf and the CA:
    it is the one to pass to the Azure CLI.
    .PARAMETER CaDir
    Folder of the signing CA (ca.pem, ca-key.pem).
    .PARAMETER Cn
    Common name = registration ID of the device.
    .PARAMETER Dir
    Folder that receives bootstrap-key.pem, bootstrap-cert.pem and bootstrap-chain.pem.
    .PARAMETER Days
    Validity in days (default 30).
    .OUTPUTS
    Object with Cert, Key and Chain (paths).
    #>
    param(
        [Parameter(Mandatory)][string]$CaDir,
        [Parameter(Mandatory)][string]$Cn,
        [Parameter(Mandatory)][string]$Dir,
        [int]$Days = 30
    )

    New-Item -ItemType Directory -Force $Dir | Out-Null

    # Load the CA certificate together with its private key: the certificate is signed with that key.
    $caPemPath = Join-Path $CaDir 'ca.pem'
    $issuer = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem(
        [IO.File]::ReadAllText($caPemPath),
        [IO.File]::ReadAllText((Join-Path $CaDir 'ca-key.pem')))

    # The device's own key pair (P-384, like every key in the demo).
    $curve = [Security.Cryptography.ECCurve]::CreateFromFriendlyName('nistP384')
    $ecdsa = [Security.Cryptography.ECDsa]::Create($curve)

    try {
        $req = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=$Cn",
            $ecdsa,
            [Security.Cryptography.HashAlgorithmName]::SHA384)
        $usage = [Security.Cryptography.X509Certificates.X509KeyUsageFlags]

        # Extensions that make this a *leaf* for client authentication:
        #  - BasicConstraints CA=false: it cannot sign other certificates (critical).
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true))
        #  - KeyUsage DigitalSignature: all TLS client authentication needs (critical).
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($usage::DigitalSignature, $true))
        #  - ExtendedKeyUsage 1.3.6.1.5.5.7.3.2 = clientAuth: the certificate may be presented by a TLS client.
        $eku = [Security.Cryptography.OidCollection]::new()
        [void]$eku.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.2'))
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($eku, $false))

        # Random 128-bit serial number. Clearing the top bit keeps it positive (a DER INTEGER is signed).
        $serial = [byte[]]::new(16)
        [Security.Cryptography.RandomNumberGenerator]::Fill($serial)
        $serial[0] = $serial[0] -band 0x7F

        # Valid from 5 minutes ago (tolerates clock skew with the service) until Days from now.
        $leaf = $req.Create(
            $issuer,
            [DateTimeOffset]::UtcNow.AddMinutes(-5),
            [DateTimeOffset]::UtcNow.AddDays($Days),
            $serial)

        $certPath  = Join-Path $Dir 'bootstrap-cert.pem'
        $keyPath   = Join-Path $Dir 'bootstrap-key.pem'
        $chainPath = Join-Path $Dir 'bootstrap-chain.pem'

        Write-Pem -Path $keyPath  -Label 'PRIVATE KEY' -Bytes $ecdsa.ExportPkcs8PrivateKey()
        Write-Pem -Path $certPath -Label 'CERTIFICATE' -Bytes $leaf.RawData

        # The chain file = leaf first, then the CA: this is what the az CLI sends as the client certificate chain,
        # so DPS can find the CA it trusts.
        $chainText = [IO.File]::ReadAllText($certPath) + [IO.File]::ReadAllText($caPemPath)
        [IO.File]::WriteAllText($chainPath, $chainText, [Text.UTF8Encoding]::new($false))

        $leaf.Dispose()
    }
    finally {
        $ecdsa.Dispose()
        $issuer.Dispose()
    }

    return [pscustomobject]@{ Cert = $certPath; Key = $keyPath; Chain = $chainPath }
}
