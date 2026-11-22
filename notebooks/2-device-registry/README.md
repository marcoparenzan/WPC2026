# Block 2: Azure Device Registry

Run in this order, once, before the session (they create the resource group): **01**, **02a**, **02b**, **02c**.

01 creates the ADR namespace, the DPS, two IoT Hubs, the links and the PKI. 02a-02c create the bootstrap CA, the enrollment groups and the devices.

All the other notebooks need these four.

Every notebook starts with the same cell: it finds `_start.ps1` (in `notebooks`) and reads `_scenario.psd1`. The working folder can be this folder.
