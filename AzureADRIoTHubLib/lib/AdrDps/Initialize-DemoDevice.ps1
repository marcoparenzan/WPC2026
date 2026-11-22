function Initialize-DemoDevice {
    <#
    .SYNOPSIS
    Makes sure a device has an operational certificate issued by ADR: registers it to DPS the first time, reuses it afterwards.
    .DESCRIPTION
    Some notebooks need a device of their own, with a name that says what it is for (eventgrid-sensore-01, api-client-01),
    so that nobody has to wonder why robot-01 shows up in an Event Grid client list or in an API log.
    These devices are not part of the fleet: they live in the CustomDevices section of _scenario.psd1.

    The function does what notebook 02c does for the fleet, but only when it is needed:
      1. looks in <OutDir>\devices\<Id> for a folder that already holds issued-chain.pem; if there is one, it is returned as it is
         (running a notebook twice must not issue a second certificate);
      2. otherwise it calls Register-DemoDevice: key and CSR, bootstrap certificate from the group's CA, registration to DPS,
         the chain issued by ADR written to disk;
      3. writes manufacturer, model and software revision in ADR, so the device is not an anonymous entry in the inventory.
    The device goes to the Hub of its group, like any other device of the group: a real registration, not a simulation.
    Notebook 99 deletes the whole resource group, so nothing needs a cleanup of its own.
    .PARAMETER Device
    Hashtable or object with Id, Group, Manufacturer, Model, SoftwareRevision (an entry of CustomDevices).
    .PARAMETER OutDir
    Base folder of the generated files ($out in the notebooks). The bootstrap CA of the group must be in <OutDir>\bootstrap-ca-<Group> (notebook 02a).
    .PARAMETER DpsName
    Name of the DPS.
    .PARAMETER ResourceGroup
    Resource group of the DPS and of the ADR namespace.
    .PARAMETER Namespace
    Name of the ADR namespace.
    .OUTPUTS
    The path of the device folder: it holds issued-chain.pem and device-key.pem, which is what the other functions read.
    .EXAMPLE
    $dir = Initialize-DemoDevice -Device $d -OutDir $out -DpsName $dps.Name -ResourceGroup $rg -Namespace $adrName
    #>
    param(
        [Parameter(Mandatory)]$Device,
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)][string]$DpsName,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$Namespace
    )

    # A folder counts only if the chain is in it: a registration that stopped halfway leaves a folder without it.
    $latest = Get-ChildItem (Join-Path $OutDir "devices\$($Device.Id)") -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'issued-chain.pem') } |
        Sort-Object Name |
        Select-Object -Last 1

    if ($latest) {
        Write-Host "[$($Device.Id)] ha gia' un certificato di ADR: lo riuso, non lo registro di nuovo."
        return $latest.FullName
    }

    $registration = Register-DemoDevice `
        -Device $Device `
        -OutDir $OutDir `
        -DpsName $DpsName `
        -ResourceGroup $ResourceGroup

    # The registration created the device in ADR with no properties: describe it, as notebook 02c does for the fleet.
    az iot adr ns device update `
        --name $Device.Id `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        --manufacturer $Device.Manufacturer `
        --model $Device.Model `
        --software-revision $Device.SoftwareRevision `
        -o none `
        --only-show-errors
    Assert-Az "Proprieta' del device $($Device.Id)"

    return $registration.Cartella
}
