function Grant-HubDataAccess {
    <#
    .SYNOPSIS
    Gives the signed-in user the data-plane role on an IoT Hub (once) and waits until the Hub answers.
    .DESCRIPTION
    Being Owner of the subscription is not enough to read the devices of an Hub with `--auth-type login`: the Hub needs the role
    "IoT Hub Data Contributor", assigned on that Hub. Without it the Hub answers IotHubUnauthorized ("no assigned permissions").
    The role is assigned only if it is missing, then the function asks the Hub for its devices until the answer is no longer
    an authorization error: a new role takes a few minutes to propagate.
    Call it once per Hub before any `az iot hub device-identity ... --auth-type login`.
    .PARAMETER HubName
    IoT Hub name.
    .PARAMETER ResourceGroup
    Resource group of the Hub.
    .PARAMETER TimeoutSeconds
    How long to wait for the role to propagate (default 300).
    #>
    param(
        [Parameter(Mandatory)][string]$HubName,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [int]$TimeoutSeconds = 300
    )

    $role = 'IoT Hub Data Contributor'

    # Who am I (object id of the signed-in user) and what is the Hub's id (the scope of the role)?
    $me = az ad signed-in-user show --query id -o tsv --only-show-errors
    Assert-Az "Lettura dell'utente connesso"
    $hubId = az iot hub show --name $HubName --resource-group $ResourceGroup --query id -o tsv --only-show-errors
    Assert-Az "Lettura dell'Hub $HubName"

    # Is the role already assigned on this Hub? Empty answer = no. 2>$null: "not found" is not an error here.
    $has = az role assignment list `
        --assignee $me `
        --scope $hubId `
        --role $role `
        --query '[0].id' `
        -o tsv `
        --only-show-errors 2>$null

    if (-not $has) {
        # --assignee-object-id + principal type User: no lookup in Entra needed, so it is faster and avoids replication errors.
        az role assignment create `
            --assignee-object-id $me `
            --assignee-principal-type User `
            --role $role `
            --scope $hubId `
            -o none `
            --only-show-errors
        Assert-Az "Assegnazione del ruolo $role su $HubName"
        "${HubName}: ruolo $role assegnato."
    }

    # A new role takes minutes to propagate: ask the Hub something that needs the role until it answers.
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ($true) {
        az iot hub device-identity list `
            --hub-name $HubName `
            --resource-group $ResourceGroup `
            --auth-type login `
            --query '[0].deviceId' `
            -o none `
            --only-show-errors 2>$null

        if ($LASTEXITCODE -eq 0) {
            "${HubName}: accesso ai dati pronto."
            return
        }
        if ((Get-Date) -gt $deadline) {
            throw "L'Hub $HubName non risponde dopo $TimeoutSeconds secondi: il ruolo $role non si e' ancora propagato."
        }

        "${HubName}: attendo la propagazione del ruolo..."
        Start-Sleep -Seconds 15
    }
}
