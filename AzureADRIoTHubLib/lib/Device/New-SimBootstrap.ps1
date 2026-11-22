function New-SimBootstrap {
    # WHAT: the onboarding credential of a device: a certificate signed by the fleet's bootstrap CA, with its key and chain file.
    # WHY:  it is only used to introduce the device to DPS, and it has its own life (here 30 days, like in notebook 02).
    # HOW:  like New-DemoLeaf, but the dates come from the simulated clock, unless -RealTime is used.
    #       Returns the expiry date of the credential (the device checks it before every registration).
    param(
        [Parameter(Mandatory)][string]$CaDir,
        [Parameter(Mandatory)][string]$Cn,
        [Parameter(Mandatory)][string]$Dir,
        [int]$Days = 30,
        # A real DPS checks the dates against the real clock: a certificate dated with the simulated clock (days ahead) is refused with 401002.
        [switch]$RealTime
    )

    $issuer = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem(
        [IO.File]::ReadAllText((Join-Path $CaDir 'ca.pem')),
        [IO.File]::ReadAllText((Join-Path $CaDir 'ca-key.pem')))

    $curve = [Security.Cryptography.ECCurve]::CreateFromFriendlyName('nistP384')
    $ecdsa = [Security.Cryptography.ECDsa]::Create($curve)

    try {
        $req = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=$Cn",
            $ecdsa,
            [Security.Cryptography.HashAlgorithmName]::SHA384)
        $usage = [Security.Cryptography.X509Certificates.X509KeyUsageFlags]

        # A leaf for client authentication: not a CA, digital signature, clientAuth.
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($false, $false, 0, $true))
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($usage::DigitalSignature, $true))
        $eku = [Security.Cryptography.OidCollection]::new()
        [void]$eku.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.2'))
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($eku, $false))

        # Random positive 128-bit serial number (top bit cleared).
        $serial = [byte[]]::new(16)
        [Security.Cryptography.RandomNumberGenerator]::Fill($serial)
        $serial[0] = $serial[0] -band 0x7F

        # Real clock for a real DPS, simulated clock for the local simulation.
        $now  = if ($RealTime) { [DateTimeOffset]::UtcNow } else { Get-SimNow }
        $leaf = $req.Create($issuer, $now.AddMinutes(-5), $now.AddDays($Days), $serial)

        Write-Pem -Path (Join-Path $Dir 'bootstrap-key.pem')  -Label 'PRIVATE KEY' -Bytes $ecdsa.ExportPkcs8PrivateKey()
        Write-Pem -Path (Join-Path $Dir 'bootstrap-cert.pem') -Label 'CERTIFICATE' -Bytes $leaf.RawData

        # Chain file = leaf + CA, the file the az CLI sends to DPS.
        $chainText = [IO.File]::ReadAllText((Join-Path $Dir 'bootstrap-cert.pem')) +
                     [IO.File]::ReadAllText((Join-Path $CaDir 'ca.pem'))
        [IO.File]::WriteAllText((Join-Path $Dir 'bootstrap-chain.pem'), $chainText, [Text.UTF8Encoding]::new($false))

        $notAfter = [DateTimeOffset]$leaf.NotAfter
        $leaf.Dispose()
        return $notAfter
    }
    finally {
        $ecdsa.Dispose()
        $issuer.Dispose()
    }
}
