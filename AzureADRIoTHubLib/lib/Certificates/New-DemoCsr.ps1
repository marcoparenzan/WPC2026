function New-DemoCsr {
    <#
    .SYNOPSIS
    Creates a device key and a certificate signing request (CSR).
    .DESCRIPTION
    The common name is the registration ID, as ADR requires. The private key never leaves the device folder:
    only the CSR is sent to the service.
    .PARAMETER Cn
    Common name = registration ID of the device.
    .PARAMETER Dir
    Folder that receives device-key.pem and device.csr.pem.
    .OUTPUTS
    Object with Key and Csr (paths).
    #>
    param(
        [Parameter(Mandatory)][string]$Cn,
        [Parameter(Mandatory)][string]$Dir
    )

    New-Item -ItemType Directory -Force $Dir | Out-Null
    $key = Join-Path $Dir 'device-key.pem'
    $csr = Join-Path $Dir 'device.csr.pem'

    # WHAT: a new ECC key pair on curve NIST P-384, the key type ADR requires for the operational certificate.
    # WHY:  the key is generated here, on the "device", so the private part never travels.
    $curve = [Security.Cryptography.ECCurve]::CreateFromFriendlyName('nistP384')
    $ecdsa = [Security.Cryptography.ECDsa]::Create($curve)

    try {
        # HOW: a CertificateRequest bundles subject + public key; the CSR is signed with the matching private key
        # (SHA-384 pairs with P-384). CN = registration ID is how DPS/ADR know whom the certificate is for.
        $req = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=$Cn",
            $ecdsa,
            [Security.Cryptography.HashAlgorithmName]::SHA384)

        # PKCS#8 is the standard "PRIVATE KEY" PEM format that the az CLI and OpenSSL read.
        Write-Pem -Path $key -Label 'PRIVATE KEY' -Bytes $ecdsa.ExportPkcs8PrivateKey()

        # Only this file is sent to the service.
        Write-Pem -Path $csr -Label 'CERTIFICATE REQUEST' -Bytes $req.CreateSigningRequest()
    }
    finally {
        # The key is already on disk: free the in-memory copy.
        $ecdsa.Dispose()
    }

    return [pscustomobject]@{ Key = $key; Csr = $csr }
}
