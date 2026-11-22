function Invoke-DeviceUpdateCheck {
    <#
    .SYNOPSIS
    Starts the update agent of a device as its own process: it asks for an update, installs it if there is one, reports, and ends.
    .DESCRIPTION
    The agent is device\su-agent\su-agent.cs (C#, run with `dotnet run`). It is a device: it opens an MQTT session to DPS with the
    bootstrap certificate of the device and PULLS - the service never pushes. Every step it takes prints one line, and this function
    returns those lines. The first start compiles the agent and takes a few seconds.
    .PARAMETER Device
    Registration id of the device.
    .PARAMETER Folder
    Folder of the device with bootstrap-chain.pem and bootstrap-key.pem (the one Register-DemoDevice wrote).
    .PARAMETER State
    Folder where the device keeps what it installed (installed.json, payload\current.ps1). Deleting it makes the device forget.
    .PARAMETER IdScope
    ID scope of the DPS.
    .PARAMETER AgentFile
    Path of su-agent.cs.
    .PARAMETER Manufacturer
    Manufacturer the device declares (compatibility property).
    .PARAMETER Model
    Model the device declares (compatibility property).
    .OUTPUTS
    The lines the agent printed, as strings.
    #>
    param(
        [Parameter(Mandatory)][string]$Device,
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$State,
        [Parameter(Mandatory)][string]$IdScope,
        [Parameter(Mandatory)][string]$AgentFile,
        [string]$Manufacturer = 'Contoso',
        [string]$Model = 'RobotV1'
    )

    # 2>&1 and ToString(): everything the agent or dotnet writes comes back as text, so nothing goes to the error stream
    # (the notebook kernel marks a cell as failed when something is written there).
    $a = @('run', $AgentFile, '--',
        '--folder', $Folder, '--registration-id', $Device, '--id-scope', $IdScope, '--state', $State,
        '--manufacturer', $Manufacturer, '--model', $Model)
    dotnet @a 2>&1 | ForEach-Object { $_.ToString() }
}
