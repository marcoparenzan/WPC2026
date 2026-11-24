# Steps: what we see at each step of each notebook

One entry per step (a heading of the notebook and the cell under it). "We see" is what the cell prints or shows.
Notebooks in the sequence of the talk. `A` = uses Azure for real, `L` = local only.
Everything goes to Azure: there are no simulations and no `$azure` switch (removed 2026-11-22). The old notebook 06 (a simulated renewal) was removed; the number is now used by `06-device-autonomo`.
The notebooks are in one folder per block of the deck (`notebooks\2-device-registry`, `3-certificati`, `4-device-custom`, `5-job`, `6-fabric`; 99 in the root). Notebooks 03-04 and 07-13 are in the final form (short cells, values from `notebooks/_scenario.psd1`); the others keep their own numbering inside the text.

---

## Block 2 · IoT Hub with ADR and DPS

### 01 · Infrastructure (A)
| Step | We see |
|---|---|
| Checks | Subscription and user; version of the `azure-iot` extension; that the chosen regions are in the preview list. Nothing is created |
| 1 · Resource group and ADR namespace | Resource providers registered; the namespace with provisioning state `Succeeded` and a system identity |
| 2 · DPS and link to ADR | The DPS, its link to the namespace, `linkingState Succeeded` |
| 3 · The Hubs | Two S1 Hubs in the same region as the namespace, each linked to ADR (and a note: a link across regions is refused) |
| 4 · The PKI | Root CA, Issuing CA (type ICA, managed by Microsoft) and the certificate policy, listed |

### 02a · The bootstrap CA on DPS (A)
| Step | We see |
|---|---|
| 1 · One bootstrap CA per fleet | Two CAs created locally (robots, trucks), with the reason: a certificate can sit in only one enrollment group of a DPS. The private keys stay in `artifacts` |
| 2 · Access to DPS data | The data role assigned to the signed-in user on this DPS only, and the wait for it to propagate |
| 3 · The CA on DPS: upload and verify | The proof of possession: DPS gives a code, a certificate containing it is signed, the CA becomes `verified` |

### 02b · The enrollment groups (A)
| Step | We see |
|---|---|
| The groups | Two groups, each with its verified CA, the Issuing CA and the policy of ADR, static allocation |
| The list | The groups as DPS reports them: attestation, allocation, Hubs |

### 02c · The devices (A)
| Step | We see |
|---|---|
| What goes where | A table: which files are secret, where they are kept in production, what goes on the device |
| The devices | For each of the six devices: key and CSR born on the device, the bootstrap certificate, the registration, the issued chain of three certificates and the Hub assigned |
| Who the device is | Manufacturer, model and software revision written in ADR and listed |
| Verification | The devices as resources of the namespace (one view for both Hubs); the devices of each Hub; the expiry of the issued certificates |

## Block 3 · Certificates, with ADR and without

### 03 · The files of the device (A)
| Step | We see |
|---|---|
| The folder | The folder `robot-01` got from notebook 02c: its files, with sizes |
| Who produced what | A table: each file, its phase (present to DPS, ask for the certificate, receive it), whether it is secret |
| The bootstrap credential | Subject, issuer and expiry of the bootstrap certificate |
| The certificate ADR issued | The three certificates: the device, the Issuing CA, the Root CA |

### 04 · Check: does the Hub accept the certificate? (A)
| Step | We see |
|---|---|
| The device | `robot-01` and the Hub DPS assigned to it, read from `dps-registration.json` |
| ADR knows the device | State `Enabled` in the namespace |
| The Hub accepts it | A test message with the device certificate: HTTP 204 |
| Who issued it | Subject, issuer and expiry of the chain |

### 05 · Credentials (L for sections 1-5, A for 6-7)
| Step | We see |
|---|---|
| 1 · Shared secret | Two keys generated; what the cloud stores (the secret itself) and what happens if the registry leaks |
| 2 · Self-signed + thumbprint | A certificate the device signed for itself; the Hub keeps only the thumbprint; the key never leaves the device |
| 3 · A CA of your own | Your CA signs the device certificates; the chain; renewal is yours to run |
| 4 · A certificate issued by ADR | The chain read back from a device registered in notebook 02c: nothing to protect on disk but the device's own key |
| 5 · The comparison | A table: what the cloud keeps, who issues, what leaks, renewal, revocation |
| 6 · The same cases on the Hub | Two test identities on an Hub (shared secret, thumbprint) and then removed |
| 7 · The operator's view | One inventory in ADR against one inventory per Hub |

### 06 · A device created directly in ADR (A, not run yet)
| Step | We see |
|---|---|
| 1 · Create | Two devices written in the namespace with one command each: external ID, manufacturer, model, software and hardware revision, tag |
| 2 · What is in the namespace | The list and the full record of a device: they are Azure resources like the others |
| 3 · No credentials | The authentication profiles of the device: none. ADR gives the identity, provisioning gives the trust |
| 4 · Change it | New software revision; one device disabled |
| 5 · A group sees them? | A group query on the model; the answer of the service is printed, whatever it is (not known) |
| Cleanup | The group and the two devices deleted |

### 07 · The device renews (A)
| Step | We see |
|---|---|
| The device, made again from scratch | `robot-02` starts from an empty folder and registers as at notebook 03; thumbprint and expiry of its first certificate |
| The renewal | A new registration with a new key; the old certificate goes to `history` |
| The certificate changed | Old and new thumbprint side by side |

### 08 · Check the renewal (A)
| Step | We see |
|---|---|
| The new certificate | HTTP 204 |
| The replaced certificate | HTTP 204 as well: renewing does not invalidate the previous one |

### 09 · The device is revoked (A)
| Step | We see |
|---|---|
| A valid certificate | `device-da-revocare` registers; Hub and thumbprint |
| Before the revocation | HTTP 204 |
| The revocation | The authentication profile of the device and the revoke command (about half a minute) |

### 10 · Check the revocation (A)
| Step | We see |
|---|---|
| The revoked certificate | HTTP 401 |
| Another device on the same Hub | HTTP 204: nothing changed |
| The device in ADR | Still `Enabled` |

### 11 · The revoked device registers again (A)
| Step | We see |
|---|---|
| A new life of the device | DPS issues a new certificate; Hub assigned and events |
| What the Hub thinks | New certificate HTTP 204, the revoked one HTTP 401 |

### 12 · Stop the device: disable it (A)
| Step | We see |
|---|---|
| Disable | State `Disabled` in ADR |
| The device tries to register | DPS refuses (409000): no certificate, event `DPS registration failed` |

### 13 · Check the disabling (A)
| Step | We see |
|---|---|
| State | `Disabled` |
| A valid certificate | HTTP 401 |
| Restore | The device is enabled again, so notebooks 09-13 can be run again |
| After the re-enabling | The valid certificate and the revoked one are both refused (401): the Hub does not trust the old certificates at once, for minutes (more than 18 minutes once, about 90 seconds another time) |
| A new registration | The device registers again: the new certificate **and the earlier valid one** are accepted (204); the revoked one stays refused (401). Run 2026-11-24 in the notebook kernel |

---

## Block 4 · Jobs for the fleet

### 14 · Groups, updates and jobs: what exists (A, read-only)
| Step | We see |
|---|---|
| Status of the preview | A table: what is available and what is not (no canary, waves, threshold, rollback, retry) |
| The real commands | The text of the CLI commands for an update, a group, a job and a run |
| The help of the commands | `az iot adr ns job create -h`, `job run -h`, `group create -h`, `su -h`: read-only. The job that is really run is in 14c |

### 14a · Azure Update Service: create and link (A, run 2026-11-22)
| Step | We see |
|---|---|
| 1 · Names and identity | The names from `_scenario.psd1`; the namespace has a system identity |
| 2 · The Update Instance | `az iot adr ns su instance create`: a resource of the resource group, **it took more than 15 minutes** to leave *Creating* |
| 3 · The link | `az iot adr ns link su add`: one per namespace; it gives `serviceAddress`, no `deviceAddress` was returned |
| 4 · The role | Device Update Content Administrator on the Update Instance, to import |
| 5 · The storage | Account, container `updates`, roles for you (contributor) and for the Update Instance (reader) |

### 14b · Import an update (A, run 2026-11-22)
| Step | We see |
|---|---|
| 1 · The files | Two thermostat scripts: 2.0.0 (works) and 3.0.0 (defective) |
| 2 · The manifests | `az iot adr ns su software-update init v5`: size and SHA-256 computed, compatibility manufacturer=Contoso, model=RobotV1 |
| 3 · Stage and import | `stage --then-import`; a second import of the same identity answers `UpdateAlreadyExists` (the cell skips it) |
| 4 · What is in the service | The list of the updates and the blobs in the storage |

### 14c · A real job: group, run, the device asks (L, run 2026-11-22)
| Step | We see |
|---|---|
| 1 · Clean start | Jobs, runs and groups of an earlier try deleted; the device back to revision 1.0.0, state forgotten |
| 2 · Group | `WHERE manufacturer = 'Contoso' AND model = 'RobotV1' AND softwareRevision = '1.0.0'`: robot-01, robot-02, device-da-aggiornare |
| 3 · Job | SoftwareUpdate, group + update `Contoso/termostato/2.0.0`, schedulingType `Continuous` |
| 4 · Run | `job schedule`: **Active**. Seen once with a device that had never asked: the run ends at once as `Failed`, `UpdateNotCompatibleWithGroup` (that branch of the cell was not run again) |
| 5 · The service before the device | summary: 3 not applied, no results |
| 6 · The device process | `device\su-agent\su-agent.cs` asks over DPS, verifies the signature (root key ADU.200702.R), downloads over HTTPS, checks the SHA-256, installs, tests, reports |
| 7 · The service after | 1 succeeded (code 700), 2 not applied; the run stays Active; **the summary lags** the per-device result by tens of seconds |
| 8 · Software revision | ADR does not change it by itself: the cell sets 2.0.0 |
| 9 · Close the run | `job run cancel --yes`: Canceled |

### 14d · A defective update: the device goes back (L, run 2026-11-22)
| Step | We see |
|---|---|
| 1 · Start | The device at 2.0.0; a group for revision 2.0.0: only device-da-aggiornare |
| 2 · Job and run | Update `termostato 3.0.0` |
| 3 · The device | Signature and SHA-256 are good; the test fails (`sensore non inizializzato`); the 2.0.0 is restored; `FAILED` reported |
| 4 · The service | Failed, origin DEVICE, code -5, extended code 50000000; the device stays at 2.0.0 |
| Cleanup | Jobs, runs, groups deleted; revision 1.0.0; state forgotten |

### 15 · Update and groups on the real service (A)
| Step | We see |
|---|---|
| 1 · The device as it is | Manufacturer, model and software revision of `device-da-aggiornare` |
| 2 · A group with a query | Two syntaxes tried: `*` or a `WHERE` clause is accepted, the other is refused; the members |
| 3 · The software revision changes | The new revision in ADR; the group still lists the same members (a snapshot) |
| 4 · Refresh and cleanup | The refresh (once per hour); the groups created here are deleted and the revision restored |

### 16 · A signed file (L)
| Step | We see |
|---|---|
| 1 · The keys | Signing key on the server, only the public key on the device |
| 2 · Sign and verify | The code of publish, verify and install |
| 3 · File 1.0.0 | Applied, tried, kept as the good version |
| 4 · File 2.0.0 | New setpoint and an alarm; same agent, different script |
| 5 · The defences | A tampered file is refused; a file signed with another key is refused; a signed but broken file is rolled back |

---

## Block 5 · Data in Fabric

### 17a · Fabric: create the Eventstream, Custom endpoint to Eventhouse (A, not run yet)
| Step | We see |
|---|---|
| The Eventhouse | Created by REST with its KQL database (the cluster names the database with the item id) |
| The table | `Events` with the CloudEvents columns (`time` is a reserved KQL word: written `['time']`) |
| The Eventstream | Custom endpoint source, Eventhouse destination, **no operators** |
| The topology | Source and destination state, number of operators |
| The values | Workspace, Eventstream, source, endpoint URI and entity path, written to `artifactsa-fabric-crea-eventstreamabric.json`; `_start.ps1` reads it and overrides section 6 of `_scenario.psd1` |

### 17b · Fabric: from the Hub straight to the Eventstream (A)
| Step | We see |
|---|---|
| The values to connect | A table of the five values (from the 17a file, or from `_scenario.psd1` if the file is missing); the cell stops if one is empty |
| A step by hand in Fabric | The name and principal id of each Hub, to add to the workspace as Contributor |
| The endpoint | An endpoint of type Fabric Eventstream on each Hub: created, or updated if it exists (the cell retries while the role propagates) |
| The route | `route-eventstream` on each Hub, listed |

### 18 · The devices send telemetry (A)
| Step | We see |
|---|---|
| The devices start | Two new devices, one per Hub, each its own process; their pids |
| What they say | The last lines of each: Hub assigned, certificate, messages sent |

### 19 · Check: did the messages arrive? (A)
| Step | We see |
|---|---|
| On the Hub | Messages accepted and deliveries to the routes, per Hub |
| Routes and endpoints | The route of each Hub and its endpoint |
| The Eventstream | Source, operators (what they keep) and destination with their state |
| The Eventhouse | The tables of the KQL database, the columns of `Events` and five rows, or a line saying the table is missing |
| The CloudEvents envelope | Where the identity of the device lives in the message |

---

## Block 6 · The ADR certificate elsewhere

### 20 · Event Grid: a broker that trusts ADR (A, run 2026-11-22)
| Step | We see |
|---|---|
| 0 · Two devices made for the purpose | `eventgrid-sensore-01` and `eventgrid-non-censito-01` registered to DPS (real registration, ADR certificate); they are not fleet devices (`CustomDevices` in `_scenario.psd1`) |
| 1 · The namespace with MQTT | An Event Grid namespace with MQTT on; the address of the broker |
| 2 · The CA of ADR | The Issuing CA taken from the chain of `eventgrid-sensore-01` and uploaded (the immediate parent of the device certificate) |
| 3 · The device as a client, by CA | `eventgrid-sensore-01` registered as an Event Grid client; the name must be the CN of the certificate. The device now exists twice: in ADR and in Event Grid |
| 4 · The same device, by thumbprint | `eventgrid-sensore-01-impronta`: the client holds the thumbprint of the ADR certificate; the name is free. Every renewal changes the thumbprint |

### 21 · The device connects to Event Grid (A, run 2026-11-22)
| Step | We see |
|---|---|
| 1 · By thumbprint | MQTT over TLS, CONNECT, answer CONNACK 0: **accepted** |
| 2 · By CA | The same certificate with the client registered by CA: **CONNACK 5, refused** (the CA of ADR is uploaded, the name is right) |
| 3 · Control: bootstrap certificate | CONNACK 5: another CA. Event Grid does not refuse at the TLS handshake |
| 4 · Control: a device not registered | `eventgrid-non-censito-01` has an ADR certificate but is not a client: refused by the broker |

### 22 · A REST API that authenticates with the ADR certificate (L, run)
| Step | We see |
|---|---|
| 0 · The client | `api-client-01`, a device made for this notebook, registered to DPS if it has no certificate yet |
| 1 · The CAs and the API | The Root and Issuing CA of ADR as a trust file; `api/cert-api.cs` started with `dotnet run` |
| 2 · Who am I | `GET /whoami`: the device id (the CN of the certificate), issuer, thumbprint, expiry |
| 3 · A message | `POST /telemetry`: accepted; the body does not say who sends it |
| 4 · Who does not get in | The bootstrap certificate (other CA); no certificate at all |
| 5 · A revoked certificate | The certificate revoked in notebook 09 is refused, reason `Revoked`: the API reads the CRL that ADR publishes |

### 99 · End of the session (A)
| Step | We see |
|---|---|
| The confirmation | Nothing happens until the name of the resource group is typed in the cell |
| The deletion | The resource group is deleted with everything in it (destructive; ADR links cannot be undone) |

