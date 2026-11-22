function Wait-AdrNamespace {
    <#
    .SYNOPSIS
    Waits until the ADR namespace reports provisioningState = Succeeded.
    .DESCRIPTION
    A namespace is created asynchronously. Polls every 10 seconds, at most 30 times; throws on 'Failed' or on timeout.
    .PARAMETER Url
    ARM URL of the namespace, with the api-version.
    #>
    param(
        [Parameter(Mandatory)][string]$Url
    )

    # Up to 30 x 10 s = 5 minutes. The ADR namespace is a preview resource without an 'az ... wait' command,
    # so the state is read directly from ARM with 'az rest'.
    for ($i = 1; $i -le 30; $i++) {
        # 2>$null: a transient error while the resource is being created is not fatal; try again.
        $state = az rest --method get --url $Url --query properties.provisioningState -o tsv --only-show-errors 2>$null

        if ($state -eq 'Succeeded') { return }
        if ($state -eq 'Failed')    { throw 'Provisioning del namespace fallito.' }

        Write-Host "  provisioning namespace: $state ($i/30)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 10
    }

    throw 'Timeout nel provisioning del namespace.'
}
