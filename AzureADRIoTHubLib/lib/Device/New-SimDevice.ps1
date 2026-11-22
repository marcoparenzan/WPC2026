function New-SimDevice {
    # WHAT: creates the object that represents a device: a folder (its "disk") plus a few settings.
    # WHY:  nothing here is shared with the cloud except the CSR; everything else is local state, so a device can be thrown away
    #       (delete the folder) or relaunched (-Reuse) like a real one.
    # HOW:  a hashtable with the settings; the bootstrap credential is either created (new device) or read back from disk (-Reuse).
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$BootstrapCaDir,
        # @{ Name; Rg } of the real DPS the device registers to.
        [Parameter(Mandatory)][hashtable]$Dps,
        [int]$ValidityDays = 30,
        [int]$BootstrapDays = 365,
        [switch]$Reuse
    )

    New-Item -ItemType Directory -Force $Dir | Out-Null

    $dev = @{
        Id                = $Id
        Dir               = $Dir
        BootstrapCaDir    = $BootstrapCaDir
        ValidityDays      = $ValidityDays
        Dps               = $Dps
        AssignedHub       = $null
        Online            = $true
        BootstrapNotAfter = $null
        Events            = [System.Collections.Generic.List[object]]::new()
    }

    if ($Reuse -and (Test-Path (Join-Path $Dir 'bootstrap-cert.pem'))) {
        # Relaunch: keep the bootstrap credential and the operational certificate already on the "disk".
        # The expiry date is read from the certificate itself, so it is not stored twice.
        $b = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem(
            [IO.File]::ReadAllText((Join-Path $Dir 'bootstrap-cert.pem')))
        $dev.BootstrapNotAfter = [DateTimeOffset]$b.NotAfter
        $b.Dispose()

        # The Hub was written by Invoke-DeviceRegistration: without it the device would have to register again.
        $hubFile = Join-Path $Dir 'assigned-hub.txt'
        if (Test-Path $hubFile) {
            $dev.AssignedHub = ([IO.File]::ReadAllText($hubFile)).Trim()
        }
    }
    else {
        # New device: issue its bootstrap credential. DPS checks the dates against the real clock, hence -RealTime.
        $dev.BootstrapNotAfter = New-SimBootstrap `
            -CaDir $BootstrapCaDir `
            -Cn $Id `
            -Dir $Dir `
            -Days $BootstrapDays `
            -RealTime
    }

    return $dev
}
