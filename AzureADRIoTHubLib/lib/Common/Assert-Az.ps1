function Assert-Az {
    <#
    .SYNOPSIS
    Stops the notebook when the last native command (normally an az call) failed.
    .DESCRIPTION
    The Azure CLI reports a failure through the exit code, not through an exception, so a notebook cell would
    go on after a failed az command. Call this right after the command.
    .PARAMETER What
    What was being done; it becomes the start of the error message.
    .EXAMPLE
    az group create --name $rg --location uksouth -o none
    Assert-Az 'Creazione del resource group'
    #>
    param(
        [Parameter(Mandatory)][string]$What
    )

    # $LASTEXITCODE is set by every native command (az included); non-zero means the command failed.
    # Throwing turns that silent failure into a PowerShell error, which stops the cell.
    if ($LASTEXITCODE -ne 0) {
        throw "$What non riuscito (az exit code $LASTEXITCODE)."
    }
}
