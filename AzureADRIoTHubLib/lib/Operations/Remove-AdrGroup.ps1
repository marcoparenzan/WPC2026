function Remove-AdrGroup {
    <#
    .SYNOPSIS
    Deletes an ADR group (the devices stay).
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

    # --yes: no confirmation prompt (a notebook cannot answer it).
    # Output and errors are discarded on purpose: deleting a group that is already gone is not a problem
    # for the notebooks, which call this to start from a clean state.
    az iot adr ns group delete `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        --yes `
        --only-show-errors 2>&1 | Out-Null
}
