function New-DpsBootstrapCa {
    <#
    .SYNOPSIS
    Creates the DPS bootstrap CA of a fleet: the CA whose certificates let a device introduce itself to DPS.
    .DESCRIPTION
    It is not the ADR CA. The ADR Issuing CA (a resource of the namespace, key in a managed HSM) issues the operational certificate the device
    uses with the IoT Hub. The bootstrap CA lives on this machine, signs only the bootstrap credential, and DPS trusts it after it has been
    uploaded and verified (proof of possession, Register-DemoDpsCa). There is one per fleet because DPS finds the enrollment group, and so the
    Hub, from the CA that signed the device credential: with a single CA for two fleets it could not choose.
    An existing CA is never regenerated (it may already be verified on DPS, and a new key would no longer match).
    .PARAMETER Group
    The fleet / enrollment group, for example robots or trucks.
    .PARAMETER OutDir
    The output folder of the scenario (Get-DemoConfig .Out); the CA goes in bootstrap-ca-<group> inside it.
    .PARAMETER Days
    Validity in days (default 1825).
    .OUTPUTS
    Object with Cert, Key (paths) and Created ($false when the CA already existed).
    .EXAMPLE
    $ca = New-DpsBootstrapCa -Group robots -OutDir $cfg.Out
    #>
    param(
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$OutDir,
        [int]$Days = 1825
    )

    # A thin wrapper: only the naming convention lives here (CN "DPS Bootstrap CA <group>", folder bootstrap-ca-<group>).
    # The folder name is what Register-DemoDevice and Open-ScenarioDevice look for.
    New-LocalCa -Name "DPS Bootstrap CA $Group" -Dir (Join-Path $OutDir "bootstrap-ca-$Group") -Days $Days
}
