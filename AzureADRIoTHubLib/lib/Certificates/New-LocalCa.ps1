function New-LocalCa {
    <#
    .SYNOPSIS
    Creates a local CA (ECC P-384 / SHA-384) in a folder, unless one is already there.
    .DESCRIPTION
    Any CA that lives on this machine: a CA of your own, a local stand-in for the ADR Issuing CA, or (through New-DpsBootstrapCa) the bootstrap CA of a fleet.
    An existing CA is never regenerated: it may already be registered on DPS, and a new key would no longer match.
    The CA is valid from one day ago: a device certificate issued with the simulated clock (which starts a little
    before the CA is created) must not be dated earlier than its issuer, or .NET refuses it
    ("requested notBefore is earlier than issuerCertificate.NotBefore"). The day also covers clock skew with the services.
    .PARAMETER Name
    Common name of the CA.
    .PARAMETER Dir
    Folder that receives ca.pem and ca-key.pem (created if missing).
    .PARAMETER Days
    Validity in days (default 1825).
    .OUTPUTS
    Object with Cert, Key (paths) and Created ($false when the CA already existed).
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Dir,
        [int]$Days = 1825
    )

    New-Item -ItemType Directory -Force $Dir | Out-Null
    $cert = Join-Path $Dir 'ca.pem'
    $key  = Join-Path $Dir 'ca-key.pem'

    # Idempotent: if both files exist, hand them back untouched (Created = $false).
    # Regenerating would silently break a CA that DPS already verified.
    if ((Test-Path $cert) -and (Test-Path $key)) {
        return [pscustomobject]@{ Cert = $cert; Key = $key; Created = $false }
    }

    $curve = [Security.Cryptography.ECCurve]::CreateFromFriendlyName('nistP384')
    $ecdsa = [Security.Cryptography.ECDsa]::Create($curve)

    try {
        $req = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
            "CN=$Name",
            $ecdsa,
            [Security.Cryptography.HashAlgorithmName]::SHA384)
        $usage = [Security.Cryptography.X509Certificates.X509KeyUsageFlags]

        # Extensions that make this a *CA*:
        #  - BasicConstraints CA=true, no path length limit (critical): it may issue certificates.
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($true, $false, 0, $true))
        #  - KeyUsage KeyCertSign + CrlSign (critical): it may sign certificates and revocation lists.
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($usage::KeyCertSign -bor $usage::CrlSign, $true))
        #  - SubjectKeyIdentifier: lets a verifier match a child certificate to this CA by key id.
        $req.CertificateExtensions.Add(
            [Security.Cryptography.X509Certificates.X509SubjectKeyIdentifierExtension]::new($req.PublicKey, $false))

        # Self-signed, valid from one day ago (see the description for why).
        $ca = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddDays(-1), [DateTimeOffset]::UtcNow.AddDays($Days))

        Write-Pem -Path $key  -Label 'PRIVATE KEY' -Bytes $ecdsa.ExportPkcs8PrivateKey()
        Write-Pem -Path $cert -Label 'CERTIFICATE' -Bytes $ca.RawData
        $ca.Dispose()
    }
    finally {
        $ecdsa.Dispose()
    }

    return [pscustomobject]@{ Cert = $cert; Key = $key; Created = $true }
}
