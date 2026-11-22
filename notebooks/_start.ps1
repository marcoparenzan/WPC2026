# _start.ps1 - the first thing every notebook runs: loads the library (devices and payloads included) and reads the scenario.
# It is loaded as text by one line at the top of each notebook (the kernel cannot run .ps1 files under the machine's execution policy):
#   . ([scriptblock]::Create([IO.File]::ReadAllText((Get-ChildItem . , .\notebooks , .. -Filter _start.ps1 -ErrorAction SilentlyContinue | Select-Object -First 1).FullName)))

$base = @((Get-Location).Path, (Join-Path (Get-Location).Path 'notebooks'), (Join-Path (Get-Location).Path '..')) | Where-Object { Test-Path (Join-Path $_ '_start.ps1') } | Select-Object -First 1
if ($base) { $base = (Resolve-Path $base).Path }      # the notebooks are in subfolders (one per block of the deck): the base is always the notebooks folder
if (-not $base) { throw "Non trovo _start.ps1: apri la cartella 'notebooks' come cartella di lavoro." }
$lib = Join-Path $base '..\AzureADRIoTHubLib\AzureADRIoTHubLib.ps1'
if (-not (Test-Path $lib)) { throw "Manca ${lib}: esegui il notebook 00." }
. ([scriptblock]::Create([IO.File]::ReadAllText($lib)))
Initialize-Sim
$cfg = Get-DemoConfig -Base $base
# Short names for the values of the scenario, so a cell reads like the story ($rg, $hubs, $out...). The values live in _scenario.psd1 only.
$workload = $cfg.Workload; $stage = $cfg.Stage; $instance = $cfg.Instance
$rg = $cfg.Rg; $rgRegion = $cfg.RgRegion; $adr = $cfg.Adr; $adrName = $cfg.AdrName; $dps = $cfg.Dps; $dpsName = $cfg.DpsName
$customDevices = $cfg.CustomDevices; $hubs = $cfg.Hubs; $hubNames = $cfg.HubNames; $fabric = $cfg.Fabric; $devices = $cfg.Devices
$update = $cfg.UpdateService; $pki = $cfg.Pki; $allocation = $cfg.Allocation; $out = $cfg.Out
# The Eventstream made by notebook 17a hands its values over in a file: when it exists it wins over section 6 of _scenario.psd1.
$fabricFile = Join-Path $cfg.Out '17a-fabric-crea-eventstream\fabric.json'
if (Test-Path $fabricFile) {
    $fromFile = Get-Content $fabricFile -Raw | ConvertFrom-Json
    foreach ($k in 'WorkspaceId', 'EventstreamId', 'SourceId', 'EndpointUri', 'EntityPath') { if ($fromFile.$k) { $fabric[$k] = $fromFile.$k } }
    "Fabric: valori dalla Eventstream creata dal 17a ($($fromFile.EventstreamId))"
}
$runScript = Join-Path $base '_run-device.ps1'      # starts one device in its own process: the notebooks that launch devices use it
"Scenario: $($cfg.Rg) | namespace ADR $($cfg.AdrName) | output in $($cfg.Out)"
