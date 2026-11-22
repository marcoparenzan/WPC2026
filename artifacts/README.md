# artifacts

Written by the notebooks and by the devices. It holds **private keys and certificates**: it is never committed or published (see `.gitignore`).
It can be deleted at any time: the notebooks create it again. Before recreating the Azure environment move the device folders away (a device that finds a valid certificate does not register again).

Folders are named after the notebook that creates them (for example `21-device-registrazione/<device>`), so a state folder can be traced back to the step that made it.
