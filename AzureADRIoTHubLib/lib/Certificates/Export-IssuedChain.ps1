function Export-IssuedChain {
    <#
    .SYNOPSIS
    Writes the certificate chain issued by ADR, taken from a DPS registration response, as PEM files.
    .DESCRIPTION
    Every element is decoded and rewritten as PEM. The preview API does not guarantee order or encoding, so only the
    elements that really are certificates are exported; the others stay in the original JSON.
    .PARAMETER Json
    JSON returned by 'az iot device registration create'.
    .PARAMETER OutDir
    Folder that receives issued-01.pem, issued-02.pem... and issued-chain.pem (all of them in one file).
    .OUTPUTS
    Number of certificates exported.
    #>
    param(
        [Parameter(Mandatory)][string]$Json,
        [Parameter(Mandatory)][string]$OutDir
    )

    $r = $Json | ConvertFrom-Json

    # The CLI sometimes wraps the answer in 'registrationState', sometimes returns it flat: accept both shapes.
    $state = if ($null -ne $r.registrationState) { $r.registrationState } else { $r }

    # PEM text of each exported certificate, joined at the end into issued-chain.pem.
    $parts = @()
    $i = 0

    # @() makes a single element behave like a list, and a missing property like an empty list.
    foreach ($item in @($state.issuedCertificateChain)) {
        $i++
        try {
            # Each element is Base64 of a DER certificate. Parsing it is the proof that it really is one:
            # anything else throws and is skipped (it stays available in dps-registration.json).
            $bytes = [Convert]::FromBase64String([string]$item)
            $c     = [Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)

            # {0:d2} -> 01, 02, 03: the files sort in the order of the chain.
            $path = Join-Path $OutDir ('issued-{0:d2}.pem' -f $i)

            # RawData is the clean DER encoding, so the PEM is rebuilt from it, not copied from the response.
            Write-Pem -Path $path -Label 'CERTIFICATE' -Bytes $c.RawData
            $parts += [IO.File]::ReadAllText($path)
            $c.Dispose()
        }
        catch {
            Write-Warning "Elemento $i della catena non riconosciuto: resta nel JSON originale."
        }
    }

    # issued-chain.pem = leaf + intermediates + root in one file: with device-key.pem it is the TLS client certificate.
    if ($parts.Count -gt 0) {
        $chainPath = Join-Path $OutDir 'issued-chain.pem'
        [IO.File]::WriteAllText($chainPath, ($parts -join ''), [Text.UTF8Encoding]::new($false))
    }

    return $parts.Count
}
