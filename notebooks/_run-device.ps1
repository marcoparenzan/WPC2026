# Starts ONE device: registers (or renews) its certificate, then sends telemetry every few seconds until stopped.
# Meant to be launched in its own window, one per device, from a notebook (Start-DemoDevice) or by hand:
#   pwsh -File .\notebooks\_run-device.ps1 -DeviceId robot-03 -StateDir D:\...\robot-03 -BootstrapCaDir D:\...\bootstrap-ca-robots `
#        -DpsName provs-iot26-dev-uks-001 -ResourceGroup rg-iot26-dev-uks-001
param(
    [Parameter(Mandatory)][string]$DeviceId,
    [Parameter(Mandatory)][string]$StateDir,
    [Parameter(Mandatory)][string]$BootstrapCaDir,
    [Parameter(Mandatory)][string]$DpsName,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [int]$IntervalSeconds = 10,
    [int]$Count = 0,                 # 0 = until Ctrl+C
    [double]$Setpoint = 21,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
# the files are loaded as text, like in the notebooks: the machine's execution policy may refuse to run .ps1 files
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $here '..\AzureADRIoTHubLib\AzureADRIoTHubLib.ps1'))))   # the consolidated library already includes Device.ps1
Initialize-Sim
$dps = @{ Name = $DpsName; Rg = $ResourceGroup }
$dev = New-SimDevice -Id $DeviceId -Dir $StateDir -BootstrapCaDir $BootstrapCaDir -Dps $dps -Reuse
$rng = [Random]::new()
$sent = 0
Write-Host "[$DeviceId] started. Mode: DPS + IoT Hub$(if ($DryRun) { ' (dry run)' }). Ctrl+C to stop." -ForegroundColor Cyan
while ($Count -eq 0 -or $sent -lt $Count) {
    Invoke-DeviceTick $dev                                           # first registration, renewal or recovery
    $status = Get-DeviceCertStatus $dev
    if ($status.State -in 'none', 'expired') { Write-Host "[$DeviceId] no valid certificate ($($status.State)); retry in $IntervalSeconds s" -ForegroundColor Yellow }
    else {
        $msg = New-DeviceTelemetry $dev -Setpoint $Setpoint -Rng $rng
        try {
            $r = Send-DeviceTelemetry $dev $msg -DryRun:$DryRun
            $sent++
            Write-Host ("[{0}] {1} #{2} temperature={3} hub={4} certificate={5} ({6} days left)" -f $DeviceId, $r, $sent, $msg.temperature, $(if ($dev.AssignedHub) { $dev.AssignedHub } else { '-' }), $status.State, $status.DaysLeft)
        }
        catch { Write-Host "[$DeviceId] send failed: $($_.Exception.Message)" -ForegroundColor Red }
    }
    if ($Count -eq 0 -or $sent -lt $Count) { Start-Sleep -Seconds $IntervalSeconds }
}
Write-Host "[$DeviceId] done: $sent messages." -ForegroundColor Cyan
