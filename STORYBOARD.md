# Storyboard: order of the talk, slide by slide

Deck: `slides/IoT-Hub-ADR-Lezione.nuova.pptx` (77 slides, speaker notes on every slide).
Rewritten on 2026-11-22 for the deck with the chapter "Oltre l'Hub: device custom". The slide -> notebook mapping is a **proposal** made from the content of the slides: change it where the talk differs.
Slide numbers are those of the current deck; if slides move, regenerate this table.

Legend: **A** = acts on Azure, **L** = runs locally, **O** = output already in the notebook, do not re-run.

## Before the session

1. Azure: `az login`, subscription selected. The resource group is built by notebooks 01 and 02a-c, run beforehand (**O**).
2. Fabric: the system identity of both IoT Hubs is a Contributor of the Fabric workspace, and the Eventstream has a Custom endpoint source. Open the Eventstream data preview in the browser.
3. Open the notebooks in VS Code with the `jupytersharp` kernel. They are in one folder per block of the deck (`notebooks\2-device-registry` ... `6-fabric`); the first line of each notebook finds `_start.ps1` from its own folder.
4. The library single file is up to date: `pwsh -File AzureADRIoTHubLib\Build-AzureADRIoTHubLib.ps1 -Check`.
5. Do not run 01 and 02 live. Notebooks 09-13 change `device-da-revocare` only; 13 restores it.
6. For notebook 22 (the REST API): .NET 11 (`dotnet`) installed, and the certificates of 02c and 09 on disk.

## Run of show

### Opening
| Slides | Content | Notebook |
|---|---|---|
| 1-2 | Title; the industrial stack and the architecture | |

### Block 1: Azure Local small form factor
| Slides | Content | Notebook |
|---|---|---|
| 3-5 | Divider; what it is; Azure IoT Operations as an Arc extension | none (read from the documentation) |
| 6-10 | **Azure IoT Operations, one year (Nov 2025 - Nov 2026)**: the 11 releases with the key ones starred; the six most important features; minimum requirements and ARM64; links | none (release notes and Learn, read 2026-11-23; nothing run) |
| 11-12 | The Azure resources; security | none (read from the documentation) |

### Block 2: Azure Device Registry, a new service
| Slides | Content | Notebook |
|---|---|---|
| 13 | Divider: "Azure Device Registry: un servizio nuovo" (an autonomous device registry; Hub and IoT Operations adapted to it) | |
| 14 | ADR: an autonomous device registry (own identity, a CA with support, other services lean on it) | slide 47 shows the proof: a device written only in ADR |
| 15 | Why it was born: certificates (with IoT Hub they were always yours) | |
| 16 | Before: the identity of a device lives in the Hub | |
| 17-18 | Hub and IoT Operations connect to ADR; what it means for operations | **01** (O): checks, namespace, DPS and link, Hubs, PKI |
| 19 | Why DPS | **02a, 02b, 02c** (O): bootstrap CA, enrollment groups, six devices |

### Block 3: Certificates, the cornerstone
| Slides | Content | Notebook |
|---|---|---|
| 20 | Divider: "Certificati: il cardine di tutto" | |
| 21-23 | Shared secret; without ADR (thumbprint, own CA); with ADR (PKI in the namespace) | **05** (sections 1-5: four credentials, comparison) |
| 24-27 | Why a bootstrap CA per fleet; onboarding and operational credential; all certificates on one page; two CAs | **02a** (O), **02b** (O) |
| 28 | The issuing flow | **02c** (O) |
| 29 | **One diagram: the two CAs and where the keys and certificates are** (new) | **02c** (O) |
| 30 | The registration step by step | **02c** (O) |
| 31-34 | The files of a device; what goes where; what ADR solves; from the maker to the cloud | **03** (the files), **04** (the Hub accepts the certificate: 204) |
| 35-36 | **3.1 Renewal**: the device starts it | **07** (the device renews), **08** (and the old certificate?) |
| 37 | Trap: the bootstrap has a life of its own | none (hypothesis, say so) |
| 38-42 | **3.2 Revocation**: how long it takes; revocation does not stop the device; revoke or disable; compromised device: disable, then revoke | **09** (revoke), **10** (does it apply at once?), **11** (the device registers again), **12** (disable), **13** (is it stopped?) |
| 43-44 | Four ways to manage credentials; trap: enrollment group and CA | **05** sections 6-7 (the same cases on the Hub; one inventory) |

### Block 4: Beyond the Hub, custom devices
| Slides | Content | Notebook |
|---|---|---|
| 45 | Divider: "Oltre l'Hub: device custom" | |
| 46 | Managing ADR: portal, az CLI, REST API (the URL and the api-version) | none: the CLI is used in every notebook; the REST call itself was not made by hand |
| 47 | A device written directly in ADR: identity yes, credentials no | **06** (A, not run); the same thing was proved with `az iot adr ns device create` (no Hub, no DPS, a group sees it) |
| 48 | The same certificate in more places: Hub, Event Grid, your own API | |
| 49 | An API that authenticates with the certificate | **22** (L, **run**): whoami, telemetry, bootstrap and no certificate refused, revoked refused |
| 50 | Event Grid as the MQTT broker of the devices | **20** (A, run), **21** (A, run: by thumbprint accepted, by CA refused) |
| 51 | Who checks the revocation? | **22** section 5 (the CRL that ADR publishes) |

### Block 5: Jobs for the fleet
| Slides | Content | Notebook |
|---|---|---|
| 52 | Divider | |
| 53 | **Dal vivo**: what to show (notebooks 14a-14d, 15, 16) | |
| 54 | Groups, updates and jobs (Azure Update Service in the diagram) | |
| 55 | **Azure Update Service: create and link it** (the namespace does not update by itself) | **14a** (A, run): Update Instance, link, role, storage; more than 15 minutes |
| 56 | An update: file and import manifest | **14b** (A, run): two updates imported |
| 57 | Anatomy of a job | **15** (groups and software revision on the real service) |
| 58 | **How the device talks: DPS, topics and signature** (the server side) | **14c** (L): the log of the device process |
| 59 | **A running run: the device asks** (the service does not push) | **14c** (L, run): group, job, run Active, the device process, the result per device |
| 60 | **A defective update: the device goes back** | **14d** (L, run): 3.0.0 fails its test, the device restores 2.0.0, Failed / DEVICE / -5 |
| 61 | What exists and what does not | **14** (status and real commands) |
| 62 | A device receives a file and applies it | **16** (L): signed file, tampering, rollback |

### Block 6: Data in Fabric
| Slides | Content | Notebook |
|---|---|---|
| 63-65 | Divider; from the device to Fabric; what to watch | **17a** (the Eventstream), **17b** (Hub straight to the Eventstream), **18** (devices send), **19** (did it arrive?) |

### Closing
| Slides | Content | Notebook |
|---|---|---|
| 66 | Five ideas to take home | |
| 67-75 | **Appendix: `az iot adr`**: the tree of the command groups (62) and one row per command (63-70, 112 commands) | reference; ● marks the 46 used in the notebooks |
| 76-77 | Sources: Microsoft Learn; code and tests | **99** (delete everything), after the session |

## What to say if something fails live

- An Azure call fails: show the output saved in the notebook for that cell, say it is the real run, and move on.
- The Lakehouse or the table is empty in Fabric: say so. Messages reach the Hub routes; the Fabric side was only partly observed.
- A device was revoked and the next cell expects it valid: run the last cell of 13 (re-enable), then 07.
- Event Grid answers 5 (not authorized) whatever the reason (notebook 21): it is the result, slide 50 says it. Wait half a minute after notebook 20: a new client is not active at once.

## Not proven (say it if asked)

Messages seen inside Fabric beyond the data preview; a real update job; the SQL/KQL queries on a real table; the exact CloudEvents shape as delivered; the bootstrap-lifetime trap on a real DPS; the time a shared secret takes to stop working after a rotation; Event Grid when the certificate is revoked in ADR; **why** Event Grid refuses the ADR certificate by CA (the extension is the most likely cause, shown by a control chain, not confirmed by Microsoft); a device created directly in ADR (notebook 06) and what a group or DPS does with it; the certificate of ADR with a server that is not .NET.
