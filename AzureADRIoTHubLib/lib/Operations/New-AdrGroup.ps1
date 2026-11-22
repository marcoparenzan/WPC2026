function New-AdrGroup {
    <#
    .SYNOPSIS
    Creates an ADR group defined by a query on device properties.
    .DESCRIPTION
    The service accepts '*' or a single WHERE clause, for example
    "WHERE model = 'RobotV1' AND softwareRevision = '1.0.0'". The query cannot be changed after creation.
    A refused query is returned as the error text instead of throwing, so a notebook can try several syntaxes.
    .PARAMETER Name
    Group name (also used as display name).
    .PARAMETER Query
    The query string.
    .PARAMETER Namespace
    ADR namespace name.
    .PARAMETER ResourceGroup
    Resource group of the namespace.
    .OUTPUTS
    $null when the group was created; the error text when the service refused it.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$ResourceGroup
    )

    # 2>&1 captures the error text in $r instead of letting it reach the notebook as an error.
    $r = az iot adr ns group create `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        --query-string $Query `
        --display-name $Name `
        -o json `
        --only-show-errors 2>&1

    # Refused (syntax, name, limits): hand the message back so the caller can show it or try another query.
    if ($LASTEXITCODE -ne 0) {
        return ($r | Out-String).Trim()
    }

    # Wait until the group is ready, so the next call (members, refresh) does not meet a half-created group.
    az iot adr ns group wait `
        --name $Name `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        --only-show-errors 2>&1 | Out-Null

    # $null = success.
    $null
}
