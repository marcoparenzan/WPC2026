function New-DeviceClientCertificate {
    # WHAT: the device's leaf certificate and its private key, joined in one object that can be used for TLS client authentication.
    # WHY:  an HTTPS client (Invoke-RestMethod -Certificate) needs a certificate that carries its key; on disk they are two PEM files.
    # HOW:  PEM -> certificate with key -> exported as PFX -> imported again. The round trip is needed because Windows
    #       cannot use an ephemeral (in-memory only) key for client authentication: the PFX import gives it a persistable key.
    param(
        $Dev,
        # The notebooks also try the bootstrap certificate (bootstrap-cert.pem, bootstrap-key.pem) as a control.
        [string]$CertFile = 'issued-chain.pem',
        [string]$KeyFile = 'device-key.pem'
    )

    $chainPem = [IO.File]::ReadAllText((Join-Path $Dev.Dir $CertFile))

    # Only the first block (the leaf): the rest of the chain is not the client's certificate.
    $leafPem = [regex]::Match($chainPem, '-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', 'Singleline').Value
    $keyPem  = [IO.File]::ReadAllText((Join-Path $Dev.Dir $KeyFile))
    $c = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($leafPem, $keyPem)

    try {
        # The caller owns the returned certificate and must Dispose it (Send-DeviceTelemetry does).
        [Security.Cryptography.X509Certificates.X509Certificate2]::new(
            $c.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx))
    }
    finally {
        $c.Dispose()
    }
}
