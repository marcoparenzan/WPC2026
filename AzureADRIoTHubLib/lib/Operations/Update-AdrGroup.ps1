function Update-AdrGroup {
    <#
    .SYNOPSIS
    Asks ADR to recompute the membership of a group.
    .DESCRIPTION
    Allowed once per hour per group, even right after creation: a second call answers GroupRefreshRateLimited.
    .PARAMETER Name
    Group name.
    .PARAMETER Namespace
    ADR namespace name.
    .PARAMETER ResourceGroup
    Resource group of the namespace.
    .OUTPUTS
    $null when accepted; the error text when refused (for example the rate limit).
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$ResourceGroup
    )

    # 2>&1 keeps the error text, so a refusal (rate limit) can be shown by the notebook instead of stopping it.
    $r = az iot adr ns group refresh `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        -o none `
        --only-show-errors 2>&1

    if ($LASTEXITCODE -ne 0) {
        return ($r | Out-String).Trim()
    }

    # $null = accepted.
    $null
}
