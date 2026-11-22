# WPC 2026: IoT Hub + Azure Device Registry (ADR), a session you can reproduce

A self-contained demo for a talk on **Azure IoT Hub with Azure Device Registry (ADR)**. The core is **certificates**: who issues them, how a device gets one, how it is renewed, how it is revoked, and how a fleet of devices is managed around them.

It has three parts:

- **notebooks** that show, one cell at a time, what the slides explain. Every action goes to Azure: there are no simulations;
- a small **device written in PowerShell** that really registers, renews its certificate and sends telemetry;
- the **slide deck**, with speaker notes written to be read aloud.

> **Language.** This README is in English. The notebooks, the slides and the speaker notes are in Italian (the talk is in Italian).

> **Where to read more.**
> [CONCEPTS.md](CONCEPTS.md): the reasoning (two PKIs, who does what, where the secrets live, revoking against disabling).
> [STEPS.md](STEPS.md): what each step of each notebook shows.
> [STORYBOARD.md](STORYBOARD.md): the order of the talk, slide by slide.
> [OPENPOINTS.md](OPENPOINTS.md): findings from the real runs, what is open, what is not proven.

## Contents

```text
WPC2026/
  README.md                         this file
  slides/IoT-Hub-ADR-Lezione.nuova.pptx   the deck (63 slides, speaker notes on every slide)
  notebooks/                        one folder per block of the deck; the numbers stay (slides and notes quote them)
    2-device-registry/              block 2: Azure Device Registry
      01-infrastruttura             ADR namespace, DPS, two IoT Hubs, links, PKI
      02a-ca-bootstrap              one bootstrap CA per fleet, verified on DPS
      02b-enrollment-group          the enrollment groups
      02c-device                    the six devices, their properties, verification
    3-certificati/                  block 3: certificates, renewal, revocation
      03-device-file                the files a device holds
      04-verifica-registrazione     does the Hub accept the certificate?
      05-credenziali                four ways to authenticate, compared
      07-device-rinnovo, 08-verifica-rinnovo
      09-device-revoca, 10-verifica-revoca, 11-device-nuova-registrazione
      12-device-disabilita, 13-verifica-disabilita
    4-device-custom/                block 4: beyond the Hub
      06-device-autonomo            devices created directly in ADR, without Hub or IoT Operations
      20-eventgrid-crea, 21-eventgrid-device   the ADR certificate used at an Event Grid MQTT broker
      22-api-certificato            the ADR certificate used at a REST API of your own
    5-job/                          block 5: jobs for the fleet
      14a-update-service-crea       Azure Update Service: Update Instance, link, storage (run it first: 15+ minutes)
      14b-update-importa            two updates imported
      14c-job-run-device            a real job: group, run, the device process asks
      14d-job-aggiornamento-difettoso   a defective update, the device goes back
      14-aggiornamenti              groups, updates and jobs: what exists, the real commands
      15-device-aggiornamento       groups and software revision on the real service
      16-file-firmato               a device receives a signed file, verifies it, applies it
    6-fabric/                       block 6: data in Fabric
      17a-fabric-crea-eventstream, 17b-fabric-eventstream
      18-device-telemetria, 19-verifica-fabric
    99-elimina-tutto                end of the session
    _scenario.psd1                  every name and value of the scenario, in one place
    _start.ps1                      the first thing every notebook runs (library + scenario)
    _run-device.ps1                 starts ONE device in its own window
  device/su-agent/su-agent.cs       the device process of the update jobs (notebooks 14c, 14d), one file, `dotnet run`
  api/cert-api.cs                   a REST API that authenticates with the ADR certificate (notebook 22), one file, `dotnet run`
  AzureADRIoTHubLib/                the helper functions, one file per function (see its README)
  artifacts/                        generated files, with private keys: never published (git ignores it)
```

The old notebook 06 (a simulated renewal) was removed on 2026-11-22; the number now belongs to `06-device-autonomo`.

## The story

1. **Where the device lives.** Azure Local *small form factor* (preview): compact Linux edge hardware, zero-touch provisioning, the Azure resources it creates, its security. Read from Microsoft Learn; nothing of it was run, there is no such device here.
2. **Azure Device Registry is a new service (block 2 of the deck).** ADR is a device registry of its own, with its own identity: it does not depend on IoT Hub or IoT Operations, and a device can be written directly in it (`az iot adr ns device create`, proved). It was born for the **certificates**: with IoT Hub they were always the customer's job and a Certification Authority with support was missing. Hub and IoT Operations were adapted to use it; the shared naming and space are a consequence, not the reason.
3. **Certificates, the core.** Most projects use a shared secret, at best a thumbprint. The talk pushes for full certificates and shows what changes: what the cloud stores, who issues, what leaks if the registry leaks. Then the two CAs (the bootstrap CA that is yours, the ADR CA that is Microsoft's), the issuing flow, renewal, revocation, and disabling a device.
4. **Jobs for the fleet.** Azure Update Service (an Update Instance linked to the namespace, notebook 14a), an imported update (14b), and a **real job**: group, run, and a device process that asks over DPS, verifies the signed manifest, installs, tests and reports (14c); a defective update the device rolls back (14d). The device is our own C# program (`device/su-agent`), written from the C SDK sources, not Microsoft's client. What ADR jobs do not offer in preview (canary, waves, threshold, rollback, retry) is listed below.
5. **Data to Fabric.** IoT Hub routes telemetry straight to a Fabric Eventstream; what ADR adds as context.
6. **The same certificate elsewhere (block 4 of the deck).** The certificate ADR issues is a normal X.509 certificate: it can authenticate to a REST API of your own (notebook 22) and to an Event Grid MQTT broker (notebooks 20-21), with no shared secret and no token. At Event Grid it works when the client is registered by **thumbprint** and is **refused** when the client is registered by CA; the likely cause is the critical Microsoft extension in the certificate. The block also shows how ADR is managed (portal, az CLI, REST API) and a device written directly in ADR (notebook 06). Certificates are the cornerstone of the whole talk and the first slide of their block says so.

## The notebooks

| Notebook | Shows | Azure |
|---|---|---|
| 01 | checks, ADR namespace, DPS, two Hubs (both uksouth: ADR links do not work across regions), links, Root CA, Issuing CA, policy | yes |
| 02a, 02b, 02c | bootstrap CAs verified on DPS; enrollment groups; six devices (four of the fleet, `device-da-aggiornare`, `device-da-revocare`) with manufacturer, model and software revision | yes |
| 03, 04 | the files of a device; a message sent with the certificate is accepted (204) | yes |
| 05 | the four credentials generated for real (shared secret, thumbprint, own CA, ADR) and compared; the same cases on the Hub; one inventory in ADR against one per Hub | sections 1-5 local, 6-7 yes |
| 06 | devices created directly in ADR (`az iot adr ns device create`): properties, tags, enablement, no credentials; a group query; cleanup. Not run yet | yes |
| 07, 08 | the device renews its certificate; old and new are both accepted | yes |
| 09, 10, 11 | revocation of a device's certificates: 204, then 401; the device registers again and is accepted | yes |
| 12, 13 | disabling the device: its certificate is refused, DPS answers `409000` | yes |
| 14a | creates **Azure Update Service** (an Update Instance), links it to the ADR namespace, adds the storage for the update files. Run 2026-11-22: the Update Instance took more than 15 minutes to leave *Creating* | yes |
| 14b | imports two updates (2.0.0 works, 3.0.0 is defective): files + import manifest, staged in the storage | yes |
| 14c | **a real job**: group, job, run Active, the device process asks over DPS, verifies, installs, reports; result per device | yes (run 2026-11-22) |
| 14d | a defective update: the device tests it, goes back to the good version, reports `Failed` | yes (run 2026-11-22) |
| 14 | status of ADR groups, updates and jobs in preview; the real CLI commands (help only; the job really run is in 14c) | read-only |
| 15 | group queries, snapshot and refresh, software revision change | yes |
| 16 | an ECDSA P-384 signed file: accepted, tampered, wrong key, signed-but-broken (rollback) | no, local |
| 17a, 17b | the Eventstream in Fabric; the Hubs route straight to it (Entra ID) | yes |
| 18, 19 | real devices send telemetry with their certificate; did it arrive? | yes |
| 20, 21 | an Event Grid namespace (MQTT), two devices made for the purpose; the device connects with its ADR certificate registered by thumbprint (accepted) and by CA (refused), with two controls (bootstrap certificate, unregistered client). **Run 2026-11-22** | yes |
| 22 | a REST API (`api/cert-api.cs`, local) that only lets in ADR certificates, checks the revocation list that ADR publishes, and refuses the others. **Run**, locally | no, local (reads the public CRL) |
| 99 | deletes everything | yes |

No key or connection string is ever written in a notebook. The first cell of each notebook loads the library and the scenario; there is no `$azure` switch any more.

## Names and regions

Resource names follow the Microsoft Cloud Adoption Framework convention `<abbreviation>-<workload>-<environment>-<region>-<instance>`. Region codes: `uks` = uksouth. All names are computed from `notebooks/_scenario.psd1` by `Get-DemoConfig`; change the instance there if a global name is taken.

| Resource | Name | Region |
|---|---|---|
| Resource group | `rg-iot26-dev-uks-001` | uksouth |
| ADR namespace | `adrns-iot-dev-uks` (letters and hyphens only: the digits of the workload are dropped) | uksouth |
| DPS | `provs-iot26-dev-uks-001` | uksouth |
| IoT Hubs | `iot-iot26-dev-uks-001` (robots), `iot-iot26-dev-uks-002` (trucks) | uksouth |
| Devices | `robot-01`, `robot-02`, `truck-01`, `truck-02`; `device-da-aggiornare` (updates), `device-da-revocare` (revocation) | |
| DPS CA certificates | `pcert-iot26-dev-robots`, `pcert-iot26-dev-trucks` | |
| Enrollment groups | `eg-iot26-dev-robots`, `eg-iot26-dev-trucks` | |
| ADR CAs and policy | `root-iot26-dev`, `ica-iot26-dev`, `cp-iot26-dev` | |

`adrns`, `adrlink`, `eg`, `root`/`ica`, `cp` are this demo's own choices: the CAF list has no abbreviation for them.

**Cross-region does not work** (found 2026-11-16): `az iot adr ns link hub add` for a Hub in centralus, with the namespace in uksouth, answers `Cross-region linking is not supported`. So the namespace, the DPS and both Hubs are in uksouth, although centralus is on Microsoft's list of preview regions (Australia East, Japan East, Central US, UK South).

## Groups, software updates and jobs: what exists

From Microsoft Learn (pages updated 2026-09 to 2026-11-12). **Everything is preview.**

| Available in preview | Not available in preview |
|---|---|
| Groups defined by a **query** on device properties; membership is **cached**, refreshed at most once an hour; up to 100 groups per namespace | **Waves, canary, failure threshold, automatic rollback** |
| Software update = files + **import manifest** (same format as Device Update for IoT Hub); the manifest cannot be created in the portal | **Retry of the failed devices only**: create a new job |
| Jobs `SoftwareUpdate` (one group) and `OnboardingUpdate` (the namespace); one software update job per group; the job definition is immutable | **Azure IoT Operations** devices (only IoT Hub-connected devices) |
| Runs: schedule now or later, cancel; a run stays `Active` and serves late devices and new members until ended; 50 concurrent runs | A Hub that already has **Device Update for IoT Hub** |
| CLI `az iot adr ns job ...`, `az iot adr ns su ...`; portal | A **PowerShell** or **.NET** device client (only the C SDK has it) |
| Device side: the software updates client of the *unified Azure IoT SDKs (preview)*, mainly Linux with more than 32 MB of memory | Production use: Microsoft points to **Device Update for IoT Hub** (GA) |

**Device properties.** `az iot adr ns device update --manufacturer --model --software-revision` was run on a real device (2026-11-16): the three values are stored. Notebook 02c sets them.

**Revocation.** The docs disagree in preview (one page says unsupported, others describe it). Proved on 2026-11-16 on `device-da-revocare`: before `az iot adr ns device auth revoke-certs ... --yes` a message sent with the device's certificate is accepted (204); the command takes about 30 seconds; right after, the same certificate is refused (401) and stays refused, while the other devices on the Hub are still accepted. The device stays `Enabled`. Notebooks 09-13 also show that a revoked device with a valid bootstrap credential registers again and is accepted, and that disabling it stops it.

## Data to Fabric

- The **direct route**: the Hub has an endpoint of type *Fabric Eventstream* (`az iot hub message-endpoint create fabric-eventstream`) pointing to an Eventstream **Custom endpoint** source. **Microsoft Entra ID only** (the Hub's managed identity, no keys). Messages should arrive as **CloudEvents**. **The Hub identity must be added to the Fabric workspace by hand** (Contributor).
- Real devices' messages did arrive in the Eventstream's table, but only after two corrections: the table columns must have the same names as the payload fields, and a `ManageFields` operator is needed or the destination writes empty rows. The preview shows the payload fields, not a CloudEvents envelope.
- ADR does not change the telemetry path; it adds **context** (fleet, model, Hub) that can be exported to a table and joined.
- The message body carries `deviceId`: routed system properties travel as metadata and may not reach the table.
- A second path (Hub → Event Hub → Eventstream source *Azure Event Hubs*) is documented. Messages reach the Event Hub; the Fabric side was never seen. It is not in the notebooks any more.

## How to run

**Requirements:** PowerShell 7 (the kernel embeds it), JupyterSharp with its VS Code extension (kernel `jupytersharp`), the Azure CLI with the `azure-iot` extension **1.0.0b2**, the Owner role on the subscription, and a region in the ADR + IoT Hub public preview. Fabric: a workspace you can write to.

1. In VS Code open a notebook with *Open With... -> JupyterSharp Notebook*, (the working folder is the folder of the notebook, or `notebooks`, or the project root: the first line of every notebook finds `_start.ps1`).
2. Run the cells in order. There are no keyboard pauses: the pause is the move to the next cell.
3. Notebooks 01 and 02a-c take real minutes of Azure provisioning: run them beforehand, so their outputs are in the notebook.

Every notebook starts with one line that loads `_start.ps1` as text (the kernel cannot run `.ps1` files under the machine's execution policy). It loads the library `AzureADRIoTHubLib\AzureADRIoTHubLib.ps1` and reads `_scenario.psd1`.

After changing a function in `AzureADRIoTHubLib\lib\` run `pwsh -File AzureADRIoTHubLib\Build-AzureADRIoTHubLib.ps1` (add `-Check` to only verify that the single file is up to date). There is no test script: the notebooks are the test, and they run on Azure.

## What is NOT proven

The running list is in [OPENPOINTS.md](OPENPOINTS.md). In short:

- **Nothing has been seen inside Fabric** beyond the Eventstream's data preview; the SQL/KQL queries of a fleet, the join with the ADR catalogue and the exact CloudEvents shape are untested.
- **The update client is ours.** The job of notebooks 14c and 14d is real (Azure Update Service, ADR, DPS), but the device is `device/su-agent/su-agent.cs`, a C# program written from the sources of the C SDK 2.0.0-preview.2, not Microsoft's client. Not tried: the onboarding route, a delta update, a reboot during the update, the SDK client itself.
- **The bootstrap-lifetime trap** (a device whose bootstrap credential expired cannot register again) is a hypothesis on a real DPS.
- **After a revocation**, what a device with a valid bootstrap credential does is shown by notebook 11; what happens after re-enabling a disabled device is shown by notebook 13 and not documented.
- **How long a shared secret takes to stop working** after a key rotation.
- **Not re-run after the 2026-11-22 cleanup:** the notebooks and the library were checked to parse and to call only existing functions, but not executed on Azure.
- **Slides.** The deck was edited with python-pptx and checked structurally; it was not rendered by a tool. Open it in PowerPoint and look at the slides with diagrams (2, 5, 9, 10, 19, 21).
- Earlier risks still stand: `static` allocation on a DPS linked to ADR; a verified CA together with the ADR policy and a CSR; cleanup of irreversible ADR links.

## License

MIT, Copyright (c) 2026 Marco Parenzan.
