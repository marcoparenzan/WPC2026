function Set-AdrDeviceProperties {
    <#
    .SYNOPSIS
    Sets manufacturer, model and software revision of a device in the ADR namespace.
    .PARAMETER Name
    Device name (the registration id).
    .PARAMETER Namespace
    ADR namespace name.
    .PARAMETER ResourceGroup
    Resource group of the namespace.
    .PARAMETER Manufacturer
    Manufacturer; leave out to keep the current value.
    .PARAMETER Model
    Model; leave out to keep the current value.
    .PARAMETER SoftwareRevision
    Software revision; leave out to keep the current value. A software update changes this property.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [string]$Manufacturer,
        [string]$Model,
        [string]$SoftwareRevision
    )

    # Build the argument list only with the properties that were given: an option left out is left unchanged by the service.
    $a = @()
    if ($Manufacturer)     { $a += '--manufacturer', $Manufacturer }
    if ($Model)            { $a += '--model', $Model }
    if ($SoftwareRevision) { $a += '--software-revision', $SoftwareRevision }

    # Nothing to set is a mistake of the caller, not a silent no-op.
    if (-not $a) {
        throw 'Set-AdrDeviceProperties: nessuna proprieta da impostare.'
    }

    # @a = splatting: the array becomes separate arguments of the command.
    az iot adr ns device update `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        @a `
        -o none `
        --only-show-errors
    Assert-Az "Aggiornamento delle proprieta di $Name"
}
