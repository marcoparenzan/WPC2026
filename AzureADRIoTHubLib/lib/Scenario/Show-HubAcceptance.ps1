function Show-HubAcceptance {
    <#
    .SYNOPSIS
    Sends one test message to the device's Hub with the device certificate and prints what the Hub answers.
    .DESCRIPTION
    204 means the Hub accepts the certificate, 401 means it refuses it (revoked, device disabled, unknown CA).
    .PARAMETER Label
    What is being tested: it starts the printed line.
    .PARAMETER Hub
    Hub host name (xxx.azure-devices.net), or the Hub name.
    .PARAMETER DeviceId
    Device id the certificate belongs to.
    .PARAMETER StateDir
    Folder with the certificate (issued-chain.pem) and the key (device-key.pem).
    .OUTPUTS
    One line of text: the label, the HTTP status code and its meaning. For the bare code use Test-HubAcceptsCertificate.
    #>
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Hub,
        [Parameter(Mandatory)][string]$DeviceId,
        [Parameter(Mandatory)][string]$StateDir
    )

    # A bare Hub name (no dot) gets the standard host suffix.
    if ($Hub -notmatch '\.') {
        $Hub = "$Hub.azure-devices.net"
    }

    $code = Test-HubAcceptsCertificate -Hub $Hub -DeviceId $DeviceId -StateDir $StateDir

    # The two answers the demo is about get a word; anything else is flagged, not hidden.
    $meaning = switch ($code) {
        204     { 'accettato' }
        401     { 'rifiutato' }
        default { 'risposta inattesa' }
    }

    # {0,-52} pads the label to 52 characters, so a list of lines lines up.
    '{0,-52} HTTP {1}  ({2})' -f $Label, $code, $meaning
}
