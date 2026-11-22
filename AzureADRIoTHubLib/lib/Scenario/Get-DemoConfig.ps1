function Get-DemoConfig {
    <#
    .SYNOPSIS
    Reads _scenario.psd1 and returns the scenario: resource names, devices and Fabric values.
    .DESCRIPTION
    _scenario.psd1 holds the values (workload, stage, instance, regions, groups, devices, Fabric ids); this function builds from them the
    resource names with the Microsoft naming convention <abbreviation>-<workload>-<environment>-<region>-<instance>, so a name is never
    written twice. The ADR namespace name accepts letters and hyphens only: the digits of the workload are dropped.
    It also silences the az CLI warnings, because the kernel would show anything written on stderr as an error.
    .PARAMETER Base
    The 'notebooks' folder, where _scenario.psd1 lives.
    .OUTPUTS
    An object with:
      Workload, Stage, Instance   the three values the names are built from
      Rg, RgRegion          resource group (one for the whole demo)
      AdrName, Adr          ADR namespace (Adr = Name, Region)
      Dps                   Name, Region, Link (the link name to ADR)
      EventGridName         the Event Grid namespace (MQTT broker) of the notebooks 20 and 21
      UpdateService         Name (Update Instance), Link (its name on the ADR namespace), Storage, Container: the Azure Update Service of the notebooks 14a-16
      Hubs                  array of IoT Hubs: Name, Region, Sku, Link, Group
      HubOf                 hashtable group name -> Hub name
      HubNames              the Hub names, in the order of the groups
      Fabric                WorkspaceId, EventstreamId, SourceId, EndpointUri, EntityPath
      Devices               array: Id, Group, Manufacturer, Model, SoftwareRevision
      CustomDevices         same fields: the devices of the notebooks 20-22 (Event Grid and the REST API), named after their purpose
      Groups, Allocation, Pki (Root, Issuing, Policy, ValidityDays)
      Out                   folder for keys, certificates and device state (private, never to be published)
    .EXAMPLE
    $cfg = Get-DemoConfig -Base 'D:\Dev\2026\IoTHub\WPC2026\notebooks'
    az iot hub show --name $cfg.HubOf.robots --resource-group $cfg.Rg
    #>
    param(
        [Parameter(Mandatory)][string]$Base
    )

    $file = Join-Path $Base '_scenario.psd1'
    if (-not (Test-Path $file)) {
        throw "Non trovo $file."
    }

    # A .psd1 is a PowerShell data file: loaded as data, nothing in it is executed.
    $s = Import-PowerShellDataFile $file

    # Only errors from az, no warnings: the kernel would show a warning on stderr as a failure.
    $env:AZURE_CORE_ONLY_SHOW_ERRORS = 'true'

    # The same for the Python warnings of the az extensions: the eventgrid extension prints SyntaxWarning lines on stderr the
    # first time it is compiled, and the kernel marks the cell as failed even though the command worked (seen on 2026-11-22).
    $env:PYTHONWARNINGS = 'ignore'

    # When a newer az is available, az tries to upgrade itself and asks "Do you want to continue? (Y/n)". A notebook cannot answer, so
    # az prints a traceback on stderr and the cell is marked as failed, whatever command it ran (seen on 2026-11-22 in notebook 20).
    # The variable name has a hyphen: it is the az config section 'auto-upgrade', key 'enable'. Upgrade az by hand, outside the notebooks.
    ${env:AZURE_AUTO-UPGRADE_ENABLE} = 'no'

    # Short names for the pieces of the naming convention: workload, stage (environment), instance, region code.
    $w = $s.Workload
    $st = $s.Stage
    $i = $s.Instance
    $rc = $s.RegionCode

    # One IoT Hub per group (fleet), numbered by the group's HubInstance. Link = the DPS-to-Hub link name used by ADR.
    $hubs = @($s.Groups | ForEach-Object {
        $n = "iot-$w-$st-$rc-$($_.HubInstance)"
        @{
            Name   = $n
            Region = $s.Region
            Sku    = $s.HubSku
            Link   = "adrlink-iot-$w-$st-$rc-$($_.HubInstance)"
            Group  = $_.Name
        }
    })

    # Group name -> Hub name, so a notebook can write $cfg.HubOf.robots.
    $hubOf = @{}
    foreach ($h in $hubs) {
        $hubOf[$h.Group] = $h.Name
    }

    [pscustomobject]@{
        Workload   = $w
        Stage      = $st
        Instance   = $i
        Rg         = "rg-$w-$st-$rc-$i"
        RgRegion   = $s.Region
        # The ADR namespace name accepts letters and hyphens only: digits are removed from the workload.
        AdrName    = "adrns-$($w -replace '[0-9]', '')-$st-$rc"
        Adr        = @{ Name = "adrns-$($w -replace '[0-9]', '')-$st-$rc"; Region = $s.Region }
        Dps        = @{ Name = "provs-$w-$st-$rc-$i"; Region = $s.Region; Link = "adrlink-provs-$w-$st-$rc-$i" }
        DpsName    = "provs-$w-$st-$rc-$i"
        # Event Grid namespace: the abbreviation of the Cloud Adoption Framework list is evgns.
        EventGridName = "evgns-$w-$st-$rc-$i"
        # Azure Update Service (Device Update, preview) of the notebooks 14a-16: the Update Instance, its link name on the ADR namespace,
        # and the storage account (lowercase letters and digits only, 3-24 characters) with the container that holds the update files.
        UpdateService = @{
            Name      = "adu-$w-$st-$rc-$i"
            Link      = 'primary-su'
            Storage   = "st$w$st$rc$i"
            Container = 'updates'
        }
        Hubs       = $hubs
        HubOf      = $hubOf
        HubNames   = @($hubs | ForEach-Object { $_.Name })
        Fabric     = $s.Fabric
        Devices    = @($s.Devices)
        CustomDevices = @($s.CustomDevices)
        Groups     = @($s.Groups)
        Allocation = $s.Allocation
        Pki        = @{
            Root         = "root-$w-$st"
            Issuing      = "ica-$w-$st"
            Policy       = "cp-$w-$st"
            ValidityDays = $s.PkiValidityDays
        }
        # Inside the project, next to the notebooks: it holds private keys and is ignored by git; it can be deleted at any time.
        Out        = [IO.Path]::GetFullPath((Join-Path $Base '..\artifacts'))
    }
}
