# Device

A tiny IoT "device" written in PowerShell: it owns a key, asks the real DPS for an operational certificate, watches its expiry and renews it.
The code is meant to be READ on stage, so it is short and commented.

The device is a folder (its "disk") with its keys, certificates, log and history. The registration is the call used in notebook 02c
(`az iot device registration create ... --csr`): it needs Azure. Everything the device holds is real: ECC P-384 keys, CSR (CN = registration ID),
the chain issued by ADR.

The clock (`Initialize-Sim`, `Get-SimNow`) is the real time. The name is historical: it used to be a clock that could be moved forward.

It is part of AzureADRIoTHubLib and uses the functions of the areas before it in the bundle: Write-Pem, New-LocalCa, New-DemoCsr, Export-IssuedChain.
