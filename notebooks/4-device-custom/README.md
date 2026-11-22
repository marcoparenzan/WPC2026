# Block 4: beyond the Hub, custom devices

Needs `2-device-registry` already run.

06: devices created directly in ADR (not run yet). 20 then 21: Event Grid (the namespace first, then the connections). 22: a REST API of your own that trusts the ADR certificate (needs .NET 11).

20 creates the named devices (`eventgrid-sensore-01`, ...) that 21 uses; Event Grid needs half a minute to use a new client.

Every notebook starts with the same cell: it finds `_start.ps1` (in `notebooks`) and reads `_scenario.psd1`. The working folder can be this folder.
