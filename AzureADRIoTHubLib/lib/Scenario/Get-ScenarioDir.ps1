function Get-ScenarioDir {
    <#
    .SYNOPSIS
    The state folder of a device: its key, certificate, log and history. The folder is named after the notebook that creates it.
    .DESCRIPTION
    Notebooks of the same story share the folder, so a later notebook continues from what the earlier one left. The path is
    <Out>\<notebook>\<device>, so a state folder can be traced back to the step that made it.
    The folder holds private keys: never publish it.
    .PARAMETER Config
    The object returned by Get-DemoConfig.
    .PARAMETER Notebook
    Name of the notebook that creates the device state, without extension (for example '21-device-registrazione').
    .PARAMETER DeviceId
    Device id (the registration id).
    .OUTPUTS
    The folder path (the folder is not created here).
    #>
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Notebook,
        [Parameter(Mandatory)][string]$DeviceId
    )

    # Only builds the path (one place for the convention); the folder is created by whoever uses it (New-SimDevice).
    Join-Path $Config.Out "$Notebook\$DeviceId"
}
