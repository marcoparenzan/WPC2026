function Invoke-DeviceRegistration {
    # WHAT: the step that issues a certificate: NEW key, NEW CSR, authenticate with the bootstrap credential, receive the chain.
    # WHY:  first registration and renewal are the same call: the device just asks again. A renewal is a new key, not an extension.
    # HOW:  calls the real DPS through the az CLI (the device needs $Dev.Dps). Returns $true when a new certificate is now on the
    #       device, $false when it could not get one (the reason goes in the device log).
    param(
        $Dev,
        [string]$Reason
    )

    # Registration always goes to the real service: without a DPS there is nothing to register to.
    if (-not $Dev.Dps) {
        throw "Device $($Dev.Id) has no DPS: give New-SimDevice a -Dps @{ Name; Rg }."
    }

    # An offline device cannot reach DPS: log it and let the next daily tick retry.
    if (-not $Dev.Online) {
        Add-DeviceEvent $Dev 'cannot reach DPS (offline): will retry every day'
        return $false
    }

    # The bootstrap credential has its own life. Once expired DPS refuses it, and only a new bootstrap certificate fixes that.
    if ((Get-SimNow) -gt $Dev.BootstrapNotAfter) {
        Add-DeviceEvent $Dev "bootstrap credential EXPIRED on $($Dev.BootstrapNotAfter.ToString('yyyy-MM-dd')): DPS would refuse the registration (needs a new bootstrap certificate)"
        return $false
    }

    # New key and CSR go in a 'pending' folder: the files in use stay untouched until the new ones are really issued.
    $work = Join-Path $Dev.Dir 'pending'
    # The private key never leaves the device.
    $csr = New-DemoCsr -Cn $Dev.Id -Dir $work

    # The bootstrap chain + key authenticate, the CSR asks for the operational certificate.
    $json = az iot device registration create `
        --dps-name $Dev.Dps.Name `
        --resource-group $Dev.Dps.Rg `
        --registration-id $Dev.Id `
        --certificate-file-path (Join-Path $Dev.Dir 'bootstrap-chain.pem') `
        --key-file-path (Join-Path $Dev.Dir 'bootstrap-key.pem') `
        --auth-type login `
        --csr $csr.Csr `
        --timeout 120 `
        -o json `
        --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        Add-DeviceEvent $Dev 'DPS registration failed'
        return $false
    }

    # Write issued-NN.pem and issued-chain.pem into the pending folder.
    [void](Export-IssuedChain -Json ($json -join "`n") -OutDir $work)

    # Remember which Hub DPS assigned (the JSON shape can be wrapped or flat).
    $reg = ($json -join "`n") | ConvertFrom-Json
    $Dev.AssignedHub = if ($null -ne $reg.registrationState) { $reg.registrationState.assignedHub } else { $reg.assignedHub }

    # Remembered on disk: a relaunch (-Reuse) with a valid certificate does not register again, and must still know its Hub.
    if ($Dev.AssignedHub) {
        [IO.File]::WriteAllText((Join-Path $Dev.Dir 'assigned-hub.txt'), $Dev.AssignedHub, [Text.UTF8Encoding]::new($false))
    }

    $pem = [IO.File]::ReadAllText((Join-Path $work 'issued-chain.pem'))

    # Keep the old material (history\), then switch to the new one.
    # The name carries the day counter of the clock, so the history shows how certificates followed one another.
    $hist = Join-Path $Dev.Dir 'history'
    New-Item -ItemType Directory -Force $hist | Out-Null
    foreach ($f in 'issued-chain.pem', 'device-key.pem') {
        $old = Join-Path $Dev.Dir $f
        if (Test-Path $old) {
            Move-Item $old (Join-Path $hist ("{0}-{1:000.0}-{2}" -f $Dev.Id, $global:Sim.Day, $f)) -Force
        }
    }

    # Switch: new chain and new key take the place of the old ones; the pending folder is no longer needed.
    [IO.File]::WriteAllText((Join-Path $Dev.Dir 'issued-chain.pem'), $pem, [Text.UTF8Encoding]::new($false))
    Move-Item $csr.Key (Join-Path $Dev.Dir 'device-key.pem') -Force
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

    $s = Get-DeviceCertStatus $Dev
    Add-DeviceEvent $Dev "new certificate ($Reason): thumbprint $($s.Thumbprint)..., valid until $($s.NotAfter)"
    return $true
}
