function Get-CertSummary {
    <#
    .SYNOPSIS
    Subject, issuer and expiry of the first certificate in a PEM file (a private key in the file is not read).
    .PARAMETER Path
    PEM file.
    .OUTPUTS
    Object with Subject, Issuer, NotAfter and Days (whole days left).
    #>
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $text = [IO.File]::ReadAllText($Path)

    # Cut out only the first CERTIFICATE block. A file with key + certificate would make CreateFromPem fail
    # (or load the key), and a chain would load only the first one anyway. Singleline lets '.' span the line breaks.
    $m = [regex]::Match($text, '-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', 'Singleline')
    $c = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($m.Value)

    try {
        return [pscustomobject]@{
            Subject  = $c.Subject
            Issuer   = $c.Issuer
            NotAfter = $c.NotAfter
            # Floor of the days left, computed in UTC so the local time zone does not move the result.
            # It becomes negative once the certificate has expired.
            Days     = [int][math]::Floor(($c.NotAfter.ToUniversalTime() - [DateTime]::UtcNow).TotalDays)
        }
    }
    finally {
        # X509Certificate2 holds native handles: always release them.
        $c.Dispose()
    }
}
