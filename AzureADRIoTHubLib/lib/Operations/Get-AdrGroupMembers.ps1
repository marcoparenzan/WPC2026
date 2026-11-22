function Get-AdrGroupMembers {
    <#
    .SYNOPSIS
    Names of the devices that belong to an ADR group now.
    .DESCRIPTION
    Membership is a snapshot taken when the group is created or refreshed: it does not follow later changes of the devices.
    .PARAMETER Name
    Group name.
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

    $json = az iot adr ns group list-members `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        -o json `
        --only-show-errors
    Assert-Az "Lettura dei membri di $Name"

    # Each member comes as an ARM resource id; the device name is its last segment.
    # @() keeps a one-member group a list.
    @($json | ConvertFrom-Json) | ForEach-Object { ($_.id -split '/')[-1] }
}
