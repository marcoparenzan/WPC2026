function Get-AdrDeviceState {
    <#
    .SYNOPSIS
    Enablement state (Enabled or Disabled) of a device in the ADR namespace.
    .PARAMETER Name
    Device name.
    .PARAMETER Namespace
    ADR namespace name.
    .PARAMETER ResourceGroup
    Resource group of the namespace.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$ResourceGroup
    )

    # --query + -o tsv returns just the value as plain text, with no JSON to parse.
    $s = az iot adr ns device show `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        --query 'properties.enablementState' `
        -o tsv `
        --only-show-errors
    Assert-Az "Lettura dello stato di $Name"

    # The value is the output of the function.
    $s
}
