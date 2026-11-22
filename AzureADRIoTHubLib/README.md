# AzureADRIoTHubLib

The helper functions of the notebooks: one file per function, one folder per area, plus one generated file that holds them all.

## Layout

```
AzureADRIoTHubLib\
  AzureADRIoTHubLib.ps1          GENERATED: every function in one file (what the notebooks load)
  Build-AzureADRIoTHubLib.ps1    joins lib\ into the generated file (-Check for tests)
  lib\<Area>\<Function>.ps1      the source: one function per file (+ lib\<Area>\README.md: what the area is for)
```

| Area (folder) | Purpose | Functions |
|---|---|---|
| `Common` | helpers used everywhere | 2 |
| `Certificates` | local CAs, device keys and CSRs, bootstrap and verification certificates, issued chain, the CA certificates of ADR | 8 |
| `AdrDps` | the Azure side: ADR namespace, DPS certificate, device registration; an MQTT connection test for Event Grid | 6 |
| `Payload` | a signed file published by a server and applied by a device (notebook 16) | 4 |
| `Device` | the PowerShell device: registration with the real DPS, renewal, telemetry; its clock | 12 |
| `Launcher` | launching the real device script (notebook 18) and the certificate API (notebook 22) | 2 |
| `Operations` | day-to-day operations on the Azure resources | 11 |
| `Scenario` | the scenario as every notebook sees it | 4 |

The build joins the areas in the order above (a function may use the functions of the areas before it) and the functions of an area by name.
A new area is a new folder **and** an entry in `$areas` at the top of the build script (the build refuses a folder it does not know).

Every function has comment-based help (`Get-Help New-LocalCa`, `New-DpsBootstrapCa -Full` once loaded).

## Rule

**Edit the files in `lib\`, never `AzureADRIoTHubLib.ps1`.** Then run:

```powershell
pwsh -NoProfile -File .\Build-AzureADRIoTHubLib.ps1          # writes AzureADRIoTHubLib.ps1
pwsh -NoProfile -File .\Build-AzureADRIoTHubLib.ps1 -Check   # exit 1 if the generated file is out of date
```

## Loading

The kernel's runspace cannot run `.ps1` files under the machine's execution policy, and a script loaded as text has no `$PSScriptRoot`:
that is why there is one generated file instead of an index that includes the others. It is loaded as text:

```powershell
. ([scriptblock]::Create([IO.File]::ReadAllText($path)))
```

## Status (2026-11-22)

- Split from 9 area files into `lib\<Area>\<Function>.ps1` (66 functions). The generated file was checked against the previous one: same 66 functions, identical bodies. The old area files are in `D:\Dev\BuildArtifacts\trash\AzureADRIoTHubLib-flat.2026-11-22`.
- Lost in the split: the section divider comments inside the old files (`# ---- jobs and runs ---`). The file header comments are now each area's `README.md`.
- The notebooks 01-08, `..\notebooks\_run-device.ps1` and `Test-Demo.ps1` load the generated file. `Test-Demo.ps1` and the notebooks were **not** re-run after the split.
- Four functions take explicit parameters because they used to read variables of the notebook: `Register-DemoDevice -Device $d -OutDir $out -DpsName $dps.Name -ResourceGroup $rg`; `Publish-Payload ... -SigningKey $signKey`; `Test-PayloadSignature -ScriptPath ... -ManifestPath ... -PublicKeyPath ...`; `Install-Payload -Version ... -Root $root`.
- `Register-DemoDevice`, `Register-DemoDpsCa`, `Wait-AdrNamespace` call Azure; they were **not run** from here.
- **2026-11-22: simulations removed (45 functions).** The area `AdrSimulator` and the functions `Invoke-SimIca`, `Revoke-DeviceCertificates`, `Test-DeviceConnection`, `Step-Sim` and `Step-SimDays` are gone (moved to `D:\Dev\BuildArtifacts\trash\no-sim-20261122`): everything now goes to the real services. `Invoke-DeviceRegistration` and `New-SimDevice` require a DPS. The code of every function was also reformatted on several lines and commented (what, why, how). Checked: every notebook cell parses and calls only existing functions; not re-run on Azure.
- **2026-11-22 (later): 49 functions.** Added Export-AdrCaCertificates (the Issuing and Root CA of ADR from a device chain), New-MqttConnectPacket and Test-MqttBrokerAcceptsCertificate (an MQTT CONNECT over TLS with a client certificate, no MQTT library; checked against a fake local broker, not against Event Grid), Start-DemoCertApi (starts `api\cert-api.cs`). New-DeviceClientCertificate can read other files of the device (the bootstrap certificate).
