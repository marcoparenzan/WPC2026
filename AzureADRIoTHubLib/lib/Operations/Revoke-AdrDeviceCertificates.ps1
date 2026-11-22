function Revoke-AdrDeviceCertificates {
    <#
    .SYNOPSIS
    Revokes the certificates already issued to a device (ADR 'Revoke device certificates').
    .DESCRIPTION
    Existing certificates stop being accepted by the Hub at once, even if they have days of life left. The device itself
    stays enabled: with a valid bootstrap credential it registers again and receives a new certificate that the Hub accepts.
    To stop the device, disable it with Set-AdrDeviceEnablement.
    Works only for the authentication profile of type CertificateAuthoritySignedX509Certificate. Destructive for that device.
    .PARAMETER Name
    Device name.
    .PARAMETER Namespace
    ADR namespace name.
    .PARAMETER ResourceGroup
    Resource group of the namespace.
    .PARAMETER Profile
    Authentication profile name; 'default' unless the device has another.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [string]$Profile = 'default'
    )

    # --yes: the command asks for confirmation, because the revocation cannot be undone.
    az iot adr ns device auth revoke-certs `
        --device-name $Name `
        --name $Profile `
        --namespace $Namespace `
        --resource-group $ResourceGroup `
        --yes `
        -o none `
        --only-show-errors
    Assert-Az "Revoca dei certificati di $Name"
}
