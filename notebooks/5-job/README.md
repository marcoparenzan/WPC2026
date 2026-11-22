# Block 5: jobs for the fleet

Run **14a first**: the Update Instance takes more than 15 minutes. Then **14b**, **14c**, **14d** in this order.

14a Azure Update Service; 14b the updates; 14c a real job and the device process (`device\su-agent`); 14d a defective update and the rollback. 14 (status of the preview) and 15 (groups and software revision) can be run any time; 16 is local (a signed file).

14c and 14d clean up after themselves and put `device-da-aggiornare` back to 1.0.0.

Every notebook starts with the same cell: it finds `_start.ps1` (in `notebooks`) and reads `_scenario.psd1`. The working folder can be this folder.
