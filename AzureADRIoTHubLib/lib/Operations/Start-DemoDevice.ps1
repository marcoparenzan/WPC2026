function Start-DemoDevice {
    <#
    .SYNOPSIS
    Starts device\_run-device.ps1 for one device in its own PowerShell window.
    .DESCRIPTION
    The device keeps its state (key, certificate, log) in StateDir: a device that finds a valid certificate there does not
    register again, so move that folder away when the Azure environment is recreated. No secret goes on the command line:
    only paths and names. -ExecutionPolicy Bypass applies to that process only.
    .PARAMETER RunScript
    Full path of _run-device.ps1.
    .PARAMETER DeviceId
    Device id (the registration id).
    .PARAMETER StateDir
    The device's own state folder.
    .PARAMETER BootstrapCaDir
    Folder with the bootstrap CA of the device's enrollment group (created by the onboarding notebook).
    .PARAMETER DpsName
    DPS name.
    .PARAMETER ResourceGroup
    Resource group of the DPS.
    .PARAMETER IntervalSeconds
    Seconds between telemetry messages.
    .PARAMETER Count
    Number of messages before the device ends; 0 keeps it running until the window is closed.
    .PARAMETER Hidden
    No window: the output goes to stdout.log and stderr.log in StateDir.
    .OUTPUTS
    The started process.
    #>
    param(
        [Parameter(Mandatory)][string]$RunScript,
        [Parameter(Mandatory)][string]$DeviceId,
        [Parameter(Mandatory)][string]$StateDir,
        [Parameter(Mandatory)][string]$BootstrapCaDir,
        [Parameter(Mandatory)][string]$DpsName,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [int]$IntervalSeconds = 5,
        [int]$Count = 0,
        [switch]$Hidden
    )

    New-Item -ItemType Directory -Force $StateDir | Out-Null

    # The device needs the bootstrap CA's private key to get its bootstrap certificate: without it, stop here with a clear message.
    if (-not (Test-Path (Join-Path $BootstrapCaDir 'ca-key.pem'))) {
        throw "Manca la CA di bootstrap in ${BootstrapCaDir}: esegui prima il notebook di onboarding."
    }

    # Arguments for the new pwsh process. -NoProfile = fast and predictable start; -ExecutionPolicy Bypass = this process only.
    $a = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $RunScript,
        '-DeviceId', $DeviceId,
        '-StateDir', $StateDir,
        '-BootstrapCaDir', $BootstrapCaDir,
        '-DpsName', $DpsName,
        '-ResourceGroup', $ResourceGroup,
        '-IntervalSeconds', $IntervalSeconds
    )
    if ($Count -gt 0) {
        $a += '-Count', $Count
    }

    # Quote the arguments that contain spaces (see Format-Arg).
    $argList = @($a | ForEach-Object { Format-Arg $_ })

    if ($Hidden) {
        # No window: a window-less process has nowhere to print, so its output goes to files in the device folder.
        Start-Process pwsh `
            -ArgumentList $argList `
            -PassThru `
            -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $StateDir 'stdout.log') `
            -RedirectStandardError (Join-Path $StateDir 'stderr.log')
    }
    else {
        # -PassThru returns the process object, so the caller can wait for it or stop it.
        Start-Process pwsh -ArgumentList $argList -PassThru
    }
}
