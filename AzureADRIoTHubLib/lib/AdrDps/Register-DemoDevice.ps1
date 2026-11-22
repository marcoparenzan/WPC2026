function Register-DemoDevice {
    <#
    .SYNOPSIS
    Registers one device to DPS and collects the operational certificate issued by ADR.
    .DESCRIPTION
    In the demo this one machine plays three roles: the factory that provisions the device, the device itself, and the operator.
    The steps, with the role that does each one in real life:

      1. DEVICE   Generates an ECC P-384 key (device-key.pem) and a certificate request (CSR, device.csr.pem) with CN = registration ID.
                  The private key is born here and never leaves the device.
      2. FACTORY  Signs a bootstrap certificate for the device with the private key of the fleet's bootstrap CA (bootstrap-ca-<group>\ca-key.pem),
                  valid 30 days, and writes bootstrap-key.pem, bootstrap-cert.pem and bootstrap-chain.pem (certificate + CA).
                  In production the CA key stays with whoever provisions the devices (a vault or an HSM) and only the result goes on the device.
      3. DEVICE   Registers to DPS: the bootstrap certificate authenticates it (DPS trusts the bootstrap CA, uploaded and verified before),
                  and the CSR asks for the operational certificate. DPS finds the enrollment group from the CA, assigns the Hub, forwards the CSR to ADR.
                  The answer is saved as dps-registration.json.
      4. DEVICE   Writes the chain ADR issued: issued-01.pem (the device), issued-02.pem (Issuing CA), issued-03.pem (Root CA) and issued-chain.pem (all three).
                  With device-key.pem, issued-chain.pem is the client certificate used with the IoT Hub.

    What is secret: the private key of the bootstrap CA (ca-key.pem), bootstrap-key.pem and device-key.pem. Everything else is public.
    Where it belongs in production (good practice, not something the demo does):
      - ca-key.pem: never on the device; a vault or HSM on the provisioning side.
      - bootstrap-key.pem, bootstrap-cert.pem, bootstrap-chain.pem: loaded on the device when it is produced, in protected storage.
      - device-key.pem: generated and kept on the device (TPM or secure element), never exported.
      - ca.pem (public part of the bootstrap CA): uploaded to DPS and verified; the device does not need it.
      - issued-chain.pem: received by the device from DPS and kept with its key; it is public.
    In the demo all of it is on one disk, in a time-stamped folder of the device. That folder holds private keys: never publish it.
    The fleet CA is expected in <OutDir>\bootstrap-ca-<Group>.
    .PARAMETER Device
    Hashtable or object with Id (registration ID) and Group (fleet, e.g. robots).
    .PARAMETER OutDir
    Base folder of the generated files.
    .PARAMETER DpsName
    Name of the DPS.
    .PARAMETER ResourceGroup
    Resource group of the DPS.
    .OUTPUTS
    Object with Device, Gruppo, Hub (assigned), Stato, Catena (certificates issued) and Cartella.
    .NOTES
    Replaces the function that used to be defined inside notebook 02, which read $out, $dps and $rg from the notebook.
    The call in the notebook must pass them explicitly.
    #>
    param(
        [Parameter(Mandatory)]$Device,
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)][string]$DpsName,
        [Parameter(Mandatory)][string]$ResourceGroup
    )

    # One time-stamped folder per registration: a second run never overwrites the files of the first.
    $dir   = Join-Path $OutDir "devices\$($Device.Id)\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    # The bootstrap CA of the device's fleet (created by New-DpsBootstrapCa).
    $caDir = Join-Path $OutDir "bootstrap-ca-$($Device.Group)"

    # Step 1 (device): key + CSR. Only the CSR will be sent.
    Write-Host "[$($Device.Id)] 1. chiave ECC P-384 e CSR con CN = registration ID"
    $csr = New-DemoCsr -Cn $Device.Id -Dir $dir

    # Step 2 (factory): the bootstrap credential, signed by the fleet CA. 30 days is enough for one demo run.
    Write-Host "[$($Device.Id)] 2. certificato di bootstrap firmato dalla CA della flotta (leaf + CA nel file di catena)"
    $boot = New-DemoLeaf -CaDir $caDir -Cn $Device.Id -Dir $dir -Days 30

    # Step 3 (device): one call does it all. The bootstrap chain + key authenticate the TLS connection to DPS
    # (DPS recognises the fleet from the CA); the CSR asks for the operational certificate.
    # --auth-type login: the control-plane calls use the signed-in az user, not a shared key.
    # --timeout 120: ADR issues the certificate synchronously and it can take a while.
    Write-Host "[$($Device.Id)] 3. registrazione a DPS: il certificato di bootstrap autentica, la CSR chiede il certificato operativo"
    $json = az iot device registration create `
        --dps-name $DpsName `
        --resource-group $ResourceGroup `
        --registration-id $Device.Id `
        --certificate-file-path $boot.Chain `
        --key-file-path $boot.Key `
        --auth-type login `
        --csr $csr.Csr `
        --timeout 120 `
        -o json `
        --only-show-errors
    Assert-Az "Registrazione di $($Device.Id)"

    # az returns the JSON as an array of lines: join it back into one text and keep it as evidence.
    $json = $json -join "`n"
    [IO.File]::WriteAllText((Join-Path $dir 'dps-registration.json'), $json, [Text.UTF8Encoding]::new($false))

    # Step 4 (device): split the issued chain into issued-NN.pem files and issued-chain.pem.
    $state = ($json | ConvertFrom-Json).registrationState
    $count = Export-IssuedChain -Json $json -OutDir $dir
    Write-Host "[$($Device.Id)] 4. Hub assegnato: $($state.assignedHub) | certificati nella catena emessa: $count"

    [pscustomobject]@{
        Device   = $Device.Id
        Gruppo   = $Device.Group
        Hub      = $state.assignedHub
        Stato    = $state.status
        Catena   = $count
        Cartella = $dir
    }
}
