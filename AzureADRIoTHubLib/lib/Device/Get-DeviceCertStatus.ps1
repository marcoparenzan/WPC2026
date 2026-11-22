function Get-DeviceCertStatus {
    # WHAT: the state of the device's operational certificate: none, valid, renew-due or expired, with days left and thumbprint.
    # WHY:  it is what the application sees every day: how much life is left in the operational certificate.
    #       Invoke-DeviceTick decides from this state whether to register, renew or do nothing.
    # HOW:  reads issued-chain.pem from the device folder and compares its dates with the SIMULATED now.
    param(
        $Dev
    )

    $path = Join-Path $Dev.Dir 'issued-chain.pem'

    # No file = the device never registered: report it as a state, not as an error.
    if (-not (Test-Path $path)) {
        return [pscustomobject]@{
            Device     = $Dev.Id
            State      = 'none'
            DaysLeft   = $null
            LifeDays   = $null
            NotAfter   = $null
            Thumbprint = $null
        }
    }

    # The chain file holds several certificates; the first block is the device's own (the leaf).
    $m = [regex]::Match([IO.File]::ReadAllText($path), '-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', 'Singleline')
    $c = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($m.Value)

    try {
        $now = Get-SimNow

        # Days left from the simulated now, and the total life of this certificate (NotAfter - NotBefore).
        $left = ([DateTimeOffset]$c.NotAfter - $now).TotalDays
        $life = ([DateTimeOffset]$c.NotAfter - [DateTimeOffset]$c.NotBefore).TotalDays

        # Renewal rule: when 20% or less of the life is left, ask for a new certificate (so a failure has time to be retried).
        $state = if ($left -le 0) { 'expired' }
                 elseif ($left / $life -le 0.2) { 'renew-due' }
                 else { 'valid' }

        [pscustomobject]@{
            Device     = $Dev.Id
            State      = $state
            DaysLeft   = [math]::Round($left, 1)
            LifeDays   = [math]::Round($life, 1)
            NotAfter   = ([DateTimeOffset]$c.NotAfter).ToString('yyyy-MM-dd')
            # 12 characters are enough to tell two certificates apart in a table.
            Thumbprint = $c.Thumbprint.Substring(0, 12)
        }
    }
    finally {
        $c.Dispose()
    }
}
