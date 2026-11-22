function Open-ScenarioDevice {
    <#
    .SYNOPSIS
    Opens a PowerShell device (device\Device.ps1) that talks to the real DPS, with its state in the folder of a notebook.
    .DESCRIPTION
    Needs device\Device.ps1 loaded (_start.ps1 does it). With -Fresh the notebook's folder for this device is moved away first
    (to <Out>\trash, never deleted), so the device starts with no certificate and registers as the first time; without it the
    device continues from its folder: key, certificate and the Hub it was assigned are read back.
    The bootstrap CA is the one of the device's enrollment group, created by the onboarding notebook.
    .PARAMETER Config
    The object returned by Get-DemoConfig.
    .PARAMETER DeviceId
    Device id; its group is read from the scenario.
    .PARAMETER Notebook
    The notebook whose folder holds the state of this device (see Get-ScenarioDir).
    .PARAMETER Fresh
    Start from an empty folder.
    .OUTPUTS
    The device object of Device.ps1 (use Invoke-DeviceTick, Invoke-DeviceRegistration, Get-DeviceCertStatus on it).
    #>
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$DeviceId,
        [Parameter(Mandatory)][string]$Notebook,
        [switch]$Fresh
    )

    # The device's group (fleet) comes from the scenario: it decides which bootstrap CA it uses.
    $group = ($Config.Devices | Where-Object { $_.Id -eq $DeviceId }).Group
    if (-not $group) {
        throw "Il device $DeviceId non e' nello scenario (_scenario.psd1)."
    }

    $dir  = Get-ScenarioDir -Config $Config -Notebook $Notebook -DeviceId $DeviceId
    $boot = Join-Path $Config.Out "bootstrap-ca-$group"
    if (-not (Test-Path (Join-Path $boot 'ca-key.pem'))) {
        throw "Manca la CA di bootstrap in ${boot}: esegui prima il notebook di onboarding."
    }

    # -Fresh: move the old state to <Out>\trash\ instead of deleting it (nothing is ever lost, as the rules of the project say).
    if ($Fresh -and (Test-Path $dir)) {
        $trash = Join-Path $Config.Out ('trash\' + $Notebook + '-' + $DeviceId + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-Item -ItemType Directory -Force (Split-Path $trash) | Out-Null
        Move-Item $dir $trash
    }

    $dps = @{ Name = $Config.DpsName; Rg = $Config.Rg }

    # A device.log in the folder means the device already lived here: -Reuse makes it read back its credentials and its Hub.
    if (Test-Path (Join-Path $dir 'device.log')) {
        New-SimDevice -Id $DeviceId -Dir $dir -BootstrapCaDir $boot -Dps $dps -Reuse
    }
    else {
        New-SimDevice -Id $DeviceId -Dir $dir -BootstrapCaDir $boot -Dps $dps
    }
}
