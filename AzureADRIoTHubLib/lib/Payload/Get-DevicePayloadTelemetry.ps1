function Get-DevicePayloadTelemetry {
    <#
    .SYNOPSIS
    Runs a payload in a separate scope and returns what its Get-Telemetry function returns.
    .PARAMETER ScriptPath
    The payload file; it must define a function named Get-Telemetry.
    #>
    param(
        [Parameter(Mandatory)][string]$ScriptPath
    )

    # WHY the child scope "& { ... }": dot-sourcing defines Get-Telemetry inside that scope only, so the payload's
    # functions and variables vanish afterwards and one payload version cannot leak into the next.
    # WHY text + Create(): the kernel cannot run .ps1 files (execution policy), but it can run a scriptblock built from text.
    & {
        . ([scriptblock]::Create([IO.File]::ReadAllText($ScriptPath)))
        Get-Telemetry
    }
}
