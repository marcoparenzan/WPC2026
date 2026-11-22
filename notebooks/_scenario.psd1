# _scenario.psd1 - the scenario in one file: what the demo builds, the devices in it, and what to connect to Fabric.
# Every notebook reads this file (through Get-DemoConfig) and nothing else defines a name or an id. Change a value here, nowhere else.
# It is data, not code: no variables and no expressions, only values. The resource names are built from Workload, Stage and Instance
# with the Microsoft naming convention <abbreviation>-<workload>-<environment>-<region>-<instance> (see Get-DemoConfig).
@{
    # ---------------------------------------------------------------------------------------------------------------
    # 1. The names
    # ---------------------------------------------------------------------------------------------------------------
    Workload = 'iot26'      # workload / project
    Stage    = 'dev'        # environment
    Instance = '001'        # change it when a global name (Hub, DPS) is already taken

    # ---------------------------------------------------------------------------------------------------------------
    # 2. Where things live
    # ---------------------------------------------------------------------------------------------------------------
    # ADR, DPS and both Hubs must be in the same region: ADR refuses a link across regions.
    Region          = 'uksouth'
    RegionCode      = 'uks'
    HubSku          = 'S1'

    # ---------------------------------------------------------------------------------------------------------------
    # 3. Enrollment groups. The group decides the Hub: static allocation sends every device of a group to one Hub.
    # ---------------------------------------------------------------------------------------------------------------
    Allocation = 'static'                  # static = a group goes to one Hub; hashed = DPS spreads the devices
    Groups = @(
        @{ Name = 'robots'; HubInstance = '001' }
        @{ Name = 'trucks'; HubInstance = '002' }
    )

    # ---------------------------------------------------------------------------------------------------------------
    # 4. The PKI that ADR runs for the namespace
    # ---------------------------------------------------------------------------------------------------------------
    PkiValidityDays = 30

    # ---------------------------------------------------------------------------------------------------------------
    # 5. The devices: the four of the fleet and one for each scenario that changes or destroys a device
    # ---------------------------------------------------------------------------------------------------------------
    Devices = @(
        @{ Id = 'robot-01';             Group = 'robots'; Manufacturer = 'Contoso'; Model = 'RobotV1'; SoftwareRevision = '1.0.0' }
        @{ Id = 'robot-02';             Group = 'robots'; Manufacturer = 'Contoso'; Model = 'RobotV1'; SoftwareRevision = '1.0.0' }
        @{ Id = 'truck-01';             Group = 'trucks'; Manufacturer = 'Contoso'; Model = 'TruckV1'; SoftwareRevision = '1.0.0' }
        @{ Id = 'truck-02';             Group = 'trucks'; Manufacturer = 'Contoso'; Model = 'TruckV1'; SoftwareRevision = '1.0.0' }
        @{ Id = 'device-da-aggiornare'; Group = 'robots'; Manufacturer = 'Contoso'; Model = 'RobotV1'; SoftwareRevision = '1.0.0' }   # the update scenario
        @{ Id = 'device-da-revocare';   Group = 'trucks'; Manufacturer = 'Contoso'; Model = 'TruckV1'; SoftwareRevision = '1.0.0' }   # revocation and disabling
    )

    # ---------------------------------------------------------------------------------------------------------------
    # 5b. Devices with a name that says what they are for, used only by the notebooks that open ADR to other services.
    #     They are real devices (DPS registration, certificate issued by ADR) but not part of the fleet: they are in no
    #     notebook of the fleet, and the group queries (model RobotV1, TruckV1) do not match them.
    # ---------------------------------------------------------------------------------------------------------------
    CustomDevices = @(
        @{ Id = 'eventgrid-sensore-01';      Group = 'robots'; Manufacturer = 'Contoso'; Model = 'CustomSensorV1'; SoftwareRevision = '1.0.0' }   # notebooks 20-21: registered as a client of Event Grid, it gets in
        @{ Id = 'eventgrid-non-censito-01';  Group = 'robots'; Manufacturer = 'Contoso'; Model = 'CustomSensorV1'; SoftwareRevision = '1.0.0' }   # notebook 21: has an ADR certificate but is NOT a client of Event Grid, it is refused
        @{ Id = 'api-client-01';             Group = 'robots'; Manufacturer = 'Contoso'; Model = 'CustomClientV1'; SoftwareRevision = '1.0.0' }   # notebook 22: the client of the REST API
    )

    # ---------------------------------------------------------------------------------------------------------------
    # 6. Fabric: THE VALUES TO FILL IN to connect the Hubs straight to a Fabric Eventstream
    # ---------------------------------------------------------------------------------------------------------------
    # Create in Fabric an Eventstream with a "Custom endpoint" source, open the source details and read them from the Entra ID Authentication tab.
    # Before the route works, add the system identity of BOTH IoT Hubs to the Fabric workspace as Contributor.
    Fabric = @{
        WorkspaceId   = '1bb5538f-ea39-4a44-8499-bcdb7fe0b2ef'      # the guid after /groups/ in the Eventstream address
        EventstreamId = '417bd75b-4747-4eff-9d6e-d00ca5964001'      # es-iot-demo, created by notebook 17a (2026-11-17)
        SourceId      = 'd288f1f4-12b8-4e81-a02c-d58fad3f6f73'      # id of the Custom endpoint source (Fabric REST: .../eventstreams/<id>/topology)
        EndpointUri   = 'sb://esehitnawdagz8pzmsyud4b.servicebus.windows.net'   # "Event hub namespace" of the source, with sb:// in front
        EntityPath    = 'esehitnawdagz8pzmsyud4b_eh'                # "Event hub name" of the source
    }
}
