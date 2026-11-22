# Identity, certificates and revocation with IoT Hub, ADR and DPS

What the demo taught, written down so it does not live only in the notebooks and the slides.
It is the reasoning behind the talk: who does what, where the secrets live, what revoking really does.

**How to read the labels.** Every claim carries one of these:

| Label | Meaning |
|---|---|
| **Observed** | Seen on the real Azure resources while running the notebooks (HTTP codes, resource properties, error messages) |
| **Documented** | Taken from Microsoft Learn; not reproduced here |
| **Practice** | Good practice for production; the demo does not apply it |
| **Not proven** | Stated, reasoned, or reported to us, but not tested in the demo |

---

## 1. Who does what

ADR gives the device an identity in a catalogue and a PKI that issues the operational certificate. It does not give the first credential
a device needs to introduce itself, nor the way keys are stored on the device.

| Topic | Who takes care of it | How |
|---|---|---|
| The device in the catalogue | ADR | A resource of the namespace, with its properties (manufacturer, model, software revision) |
| The operational certificate | ADR | The Issuing CA and the certificate policy issue it; the device asks for renewal |
| Which IoT Hub the device goes to | DPS | The enrollment group, found from the bootstrap CA |
| The bootstrap credential | **You** | A bootstrap CA, a signature at production time, the CA certificate uploaded to DPS |
| The key of the bootstrap CA | **You** | In a Key Vault or an HSM, never on the device (Practice) |
| The keys on the device | **You** | In a TPM or a secure element, not exportable (Practice) |

So the answer to "does ADR solve the bootstrap?" is no: it solves the identity and the operational certificate (**Observed**: the CA and the
device are resources of the namespace). The bootstrap, the production process and the key custody stay with whoever builds and ships the devices.

## 2. Two PKIs, two kinds of CA

There are two different CAs and they are easy to confuse.

| | ADR CA | Bootstrap CA |
|---|---|---|
| What it is | Root CA, Issuing CA and a certificate policy, in the namespace | One CA per fleet, created locally |
| Where the key is | Managed by Microsoft: no key file anywhere (**Documented**; the resource shows none) | On your side: in the demo a folder on disk, in production a Key Vault or an HSM |
| What it is for | Issues the **operational** certificate the device uses with the Hub | Signs the **bootstrap** credential the device uses to introduce itself to DPS |
| Who trusts it | The IoT Hub | DPS, after the CA is uploaded and verified (proof of possession) |
| How many | One for the namespace | One per fleet |

```text
   FOR DPS                                         FOR THE IOT HUB
   Bootstrap CA   (local, one per fleet)           Root CA          (ADR)  signs only the Issuing CA
        | signs                                          |
        v                                                v
   Bootstrap certificate (30 days)                 Issuing CA       (ADR)  issues, with the policy
        |                                                |
        |                                                v
        |                                          Operational certificate of the device
        +-------------------------+----------------------+
                                  v
                               THE DEVICE   holds: bootstrap key + certificate (for DPS)
                                                    its own key, which never leaves, + the chain issued by ADR (for the Hub)
```

**The roles in ADR** (**Observed** as resources, **Documented** as roles):
- the **Root CA** is the root of trust; it does not issue to devices, it only signs the Issuing CA;
- the **Issuing CA** (type ICA, Microsoft-managed) issues the certificates of the devices; its signature is guaranteed by the Root;
- the **certificate policy**, attached to the Issuing CA, sets the rules of the certificates it issues, here the validity (30 days in the demo; 30, 60 or 90 are the documented choices).

The CA is a real resource: `Microsoft.DeviceRegistry/namespaces/certificateAuthorities`, with a state, a key type (ECC), a subject, a validity window
and a reference to its issuer. The policy is a child resource (`.../certificatePolicies`). **Observed**.
That the keys sit in an HSM comes from the documentation that was read at the start; the resource does not show it (**Documented**, not verified).

**Why one bootstrap CA per fleet.** DPS finds the enrollment group, and so the Hub, from the CA that signed the device credential.
A certificate can be specified in only one enrollment entry of a DPS instance (**Documented**, *X.509 certificate attestation*): two groups need two certificates.
An alternative is one Root with an intermediate CA per fleet, which DPS matches as the first intermediate of the chain (**Documented**). The demo uses two independent CAs
because they are simpler to show. What DPS does with two groups on the same CA is **Not proven**.

**A trap with a name.** Creating the enrollment group with the CA file attached makes DPS treat the CA as an *intermediate* and every device is refused (`401002 Invalid certificate`):
the CA must be uploaded and **verified** first, with the proof of possession. **Observed**, with ECC P-384, P-256 and RSA.

## 3. The registration, step by step

`Register-DemoDevice` runs four steps. In the demo one machine plays three roles (factory, device, operator); in production they are separate.

| Step | Who | What happens |
|---|---|---|
| 1 | The device | Generates an ECC P-384 key and a certificate request (CSR) with CN = registration ID. The key is born on the device and stays there |
| 2 | The factory | Signs a bootstrap certificate with the bootstrap CA key, valid 30 days. In production this does not happen on the device |
| 3 | The device | Registers to DPS with the bootstrap credential and attaches the CSR. DPS finds the group, assigns the Hub, forwards the CSR to ADR |
| 4 | The device | Receives the chain issued by ADR (device, Issuing CA, Root CA) and keeps it with its key |

### The files a device ends up with

| File | What it is | Secret? |
|---|---|---|
| `bootstrap-key.pem` | Private key of the bootstrap credential | **Yes** |
| `bootstrap-cert.pem`, `bootstrap-chain.pem` | The bootstrap certificate, and the chain towards the CA | No |
| `device-key.pem` | Private key of the device: born on the device, never leaves | **Yes**, the most important |
| `device.csr.pem` | The certificate request: public key and device name | No |
| `issued-01.pem`, `-02`, `-03` | The three certificates issued by ADR: device, Issuing CA, Root CA | No |
| `issued-chain.pem` | The three together. With `device-key.pem` it is the client certificate for the Hub | No |
| `dps-registration.json` | DPS' answer: state, assigned Hub, chain | No |

Only two files are needed to talk to the Hub: `issued-chain.pem` and `device-key.pem`. The others are the trail of how it got there.

### Are these files saved by ADR?

No. **Observed**: the device resource in the namespace holds the name, an external id, a uuid, the enablement state and the properties that were set, and no certificate and no key.
The chain comes back from DPS in the registration answer and the notebook saves it to disk only to be able to show it. Private keys exist nowhere else: if they are lost there is nothing to recover them from.

### Where each secret belongs (Practice)

| File | Where it is kept | Secret? |
|---|---|---|
| `ca-key.pem` (bootstrap CA) | In a Key Vault or an HSM on the producer side. **Never on the device** | **Yes** |
| `ca.pem` (bootstrap CA) | Uploaded to DPS and verified. The device does not need it | No |
| `bootstrap-key.pem` | On the device, loaded at production, in protected storage | **Yes** |
| `bootstrap-cert.pem` and chain | On the device, next to its key | No |
| `device-key.pem` | Born and kept on the device (TPM or secure element), never exported | **Yes** |
| `device.csr.pem` | Sent to DPS; no need to keep it | No |
| `issued-chain.pem` | Received from DPS and kept with the key | No |

The TPM holds **private keys**, not certificates: certificates are public and can sit anywhere. A Key Vault is right for the key of the bootstrap CA, and wrong for the key of the device:
a copy in a vault would defeat the point of a key that never leaves the device. In the demo all of it is on one disk, in `artifacts`, which is ignored by git and must never be published.

## 4. The life of a device, from the producer to the cloud (Practice)

| Phase | Who | What happens |
|---|---|---|
| Production | The producer | Prepares the device and signs its bootstrap credential with the CA key, kept in a Key Vault or an HSM |
| Delivery | The producer | The device starts with the bootstrap credential in protected storage: a TPM or a secure element |
| First boot | The device | Generates its own key in the TPM, introduces itself to DPS with the bootstrap, asks for the operational certificate |
| In service | The device | Renews before expiry: new key, new request, the same call as the first time |
| End of life or theft | The operator | Disables the device in ADR and revokes its certificates |

Keys are born where they must stay.

## 5. Renewal

Renewal is **not a feature of the service**: the device asks again, with a new key and a new CSR, exactly as the first time.
The previous certificate is not invalidated: **Observed**, the Hub accepts both the new certificate and the replaced one until it expires or is revoked.
This is why the application needs a daily "check the expiry" and why revocation exists.

## 6. Revoking and disabling are two different things

| | Revocation of the certificates | Disabling of the device |
|---|---|---|
| What it hits | The certificates already issued to the device | The device, as a resource in ADR |
| Effect on the Hub | The old certificate is refused: 401 (**Observed**) | Even a valid certificate is refused: 401 (**Observed**) |
| New registration | The device registers again and gets a new certificate, which the Hub accepts: 204 (**Observed**) | DPS refuses it: `409000` (**Observed**) |
| Can it be undone? | Revoked certificates stay refused while the device is enabled (**Observed**) | Yes: enable the device again (**Observed**) |
| When | Key or certificate compromised | Theft, decommissioning, a device to suspend |

The revoke command (`az iot adr ns device auth revoke-certs`) takes about half a minute to return; the first message sent afterwards was already refused.

**Neither is enough alone.** For a compromised device:

1. **Disable** it: access closes now, and the device cannot get a new certificate.
2. **Revoke** its certificates: the old ones do not become valid again when the device is enabled.
3. Fix the problem and **enable** it again.
4. The device registers again and gets a new certificate, with a new key.

For a plain suspension with no secret at stake, disabling and then enabling is enough.
That a valid certificate is accepted again after re-enabling, and a revoked one stays refused, follows from the above but is **Not proven**: notebook 13 now shows it.
If the bootstrap credential is compromised too, that needs separate handling: it lasts 30 days and is signed by a CA that is in your hands, not in ADR.

### Shared secret against certificate

With a shared secret, rotating the key gives **no guarantee on how long it takes** for an access to stop working. With a certificate, revocation is immediate.
The second half is **Observed** (the first message after the revocation is refused); the first half is a statement made during the work and is **Not proven** here.

## 7. Other findings from the real runs

- **ADR does not support a link across regions.** A Hub in Central US cannot be linked to a namespace in UK South (`Cross-region linking is not supported`). Namespace, DPS and both Hubs are in the same region. **Observed**.
- A repeated `PUT` on the namespace left it in `Failed`; a tags-only update fixed it. A Hub link left `Failed` is recovered with `az iot adr ns link hub update`. **Observed**.
- ADR-linked Hubs have local authentication disabled: no shared-secret device can be created for a quick test (`401002 ... disabling Sas authentication`). **Observed**.
- Reading the devices of an Hub with `--auth-type login` needs the role *IoT Hub Data Contributor* **on that Hub**; Owner is not enough (`IotHubUnauthorized`). A new role takes minutes to propagate. **Observed**.
- A group query takes `*` or one `WHERE` clause (`WHERE model = 'RobotV1' AND softwareRevision = '1.0.0'`); the form in the CLI help (`properties.model = ...`) is refused (`InvalidGroupQueryFilter`). The query cannot be changed. **Observed**.
- A group is a **snapshot**: after the software revision changed, it still counted the same members. A refresh can be asked once per hour, even right after creation (`GroupRefreshRateLimited`). **Observed**.
- A real update job was **Not proven**: it needs an update imported from a storage and a device with the unified SDK client.
- Fabric from the Hub: the endpoint of type *Fabric Eventstream* works with Microsoft Entra ID only, and the system identity of each Hub must be a Contributor of the Fabric workspace first (a 401 otherwise). The messages arrive as CloudEvents. **Documented**; the endpoint and the route were created for real. What arrives inside Fabric was **not seen**: the read-only check found the source running and no table in the Lakehouse schema.
- Resource names follow the Microsoft Cloud Adoption Framework convention; the ADR namespace name accepts letters and hyphens only, so the digits of the workload are dropped.

## 7b. The ADR certificate outside the Hub (observed 2026-11-22)

The certificate ADR issues is a normal X.509 client certificate (clientAuth, ECDSA P-384). Anything that trusts the ADR CA can accept it. Observed with the API of notebook 22:
- **It works**: a .NET server that trusts the **Root CA of ADR** accepts the certificate of `robot-01`, and refuses the bootstrap certificate (another CA) and a client with no certificate.
- **The Root is the anchor, not the Issuing CA.** With only the Issuing CA in the trust store .NET reports `UntrustedRoot`: the Root must be trusted and the Issuing CA given as a helper. (Event Grid is different: its documentation says the CA to upload is the immediate parent of the client certificate, that is the Issuing CA.)
- **A critical extension of Microsoft.** The device certificate carries a critical extension `1.3.6.1.4.1.311.133.1.1.1` (32 bytes, meaning unknown). A strict X.509 validator must refuse a critical extension it does not know: .NET answers `HasNotSupportedCriticalExtension`. A service of your own has to tolerate that one extension **by name** (the API does) and refuse every other unknown critical extension. OpenSSL, nginx and the like were not tried.
- **ADR publishes the revocation list.** The certificates carry the address of the CRL (`http://primary-cdn.pki.azure.net/<region>/crls/...`) and of the CA certificates (AIA); both download without authentication. The CRL of the Issuing CA listed the serial numbers of the certificates revoked with `revoke-certs`, with the revocation time (it was updated at the moment of the revocation; `NextUpdate` is seven days later). So a service **can** refuse a revoked certificate, **if it reads the CRL**. The API does; the Hub does it by itself.
- **Disabling a device in ADR is a different matter**: it is not in the certificate nor in the CRL. A service of your own does not know that a device was disabled unless it asks ADR.

## 8. How the demo is organised

Every notebook reads the scenario from one file, `notebooks/_scenario.psd1` (names, devices, the Fabric values to fill in), through one line that runs `_start.ps1`.
The reusable code is the library `AzureADRIoTHubLib` (certificates, ADR and DPS, payloads, the device, operations, the scenario).
Notebooks tell the story and call the library; they hold no repeated code. Generated files go to `artifacts/` (private keys: never published).

| Block | Notebooks |
|---|---|
| Infrastructure and onboarding | 01 infrastructure · 02a bootstrap CA · 02b enrollment groups · 02c devices |
| First device | 03 the device files · 04 check the registration |
| Credentials | 05 four ways to authenticate · 06 a device created directly in ADR |
| Renewal, revocation | 07 renew · 08 check · 09 revoke · 10 check · 11 register again · 12 disable · 13 check and restore |
| Jobs | 14 groups, updates and jobs · 15 groups on the real service · 16 a signed file |
| Fabric | 17a create the Eventstream · 17b Hub to Eventstream · 18 telemetry · 19 check |
| The certificate elsewhere | 20 Event Grid broker · 21 the device connects · 22 a REST API |
| End | 99 delete everything |

Each step of each notebook, and what it shows, is in `STEPS.md`.

## 9. What is proven and what is not

**Observed on Azure:** the whole infrastructure; registration of real devices through DPS with a certificate from ADR; sending with that certificate (204);
renewal (both certificates accepted); revocation (204 then 401); registration after the revocation (accepted); disabling (401, `409000`); the group queries and the snapshot.

**Not proven:** what arrives inside Fabric; a real update job; the SQL queries on a real Lakehouse; two enrollment groups on the same CA; the behaviour after re-enabling a device (notebook 13 shows it);
how long a shared secret takes to stop working after a key rotation; the bootstrap-lifetime trap on a real DPS (a hypothesis).

**Practice, not applied by the demo:** the CA key in a Key Vault or an HSM; the device keys in a TPM or a secure element; the production process of section 4.
