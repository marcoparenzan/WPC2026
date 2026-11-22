function Set-AdrDeviceEnablement {
    <#
    .SYNOPSIS
    Enables or disables a device in the ADR namespace, and returns the state that ADR reports afterwards.
    .DESCRIPTION
    A disabled device cannot use even a valid certificate, and a new DPS registration fails (error 409000).
    That failure is written by az on stderr: run the registration with 2>$null in a notebook, or the kernel stops the cell.
    .PARAMETER Name
    Device name.
    .PARAMETER Namespace
    ADR namespace name.
    .PARAMETER ResourceGroup
    Resource group of the namespace.
    .PARAMETER State
    Enabled or Disabled.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][ValidateSet('Enabled', 'Disabled')][string]$State
    )

    az iot adr ns device update `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        --enablement-state $State `
        -o none `
        --only-show-errors
    Assert-Az "Cambio di stato di $Name"

    # Read the state back from the service: the answer shows what ADR really holds, not what we asked for.
    Get-AdrDeviceState -Name $Name -Namespace $Namespace -ResourceGroup $ResourceGroup
}
