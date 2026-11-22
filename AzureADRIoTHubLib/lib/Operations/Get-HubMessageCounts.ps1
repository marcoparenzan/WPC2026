function Get-HubMessageCounts {
    <#
    .SYNOPSIS
    Messages accepted by an IoT Hub and messages delivered to its routes, over the last hours.
    .DESCRIPTION
    Reads two Azure Monitor metrics of the Hub: d2c.telemetry.ingress.success (messages that entered) and
    d2c.telemetry.egress.success (deliveries to routing endpoints: one message counts once per route that matches).
    The metrics arrive with a delay of a few minutes, so a zero right after sending is normal.
    .PARAMETER HubName
    IoT Hub name.
    .PARAMETER ResourceGroup
    Resource group of the Hub.
    .PARAMETER Hours
    Time window, ending now.
    .OUTPUTS
    An object with Hub, Ingress and Egress (numbers; 0 when the metric has no data).
    #>
    param(
        [Parameter(Mandatory)][string]$HubName,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [int]$Hours = 1
    )

    # Azure Monitor addresses a resource by its full ARM id.
    $id = az iot hub show --name $HubName --resource-group $ResourceGroup --query id -o tsv --only-show-errors
    Assert-Az "Lettura dell'Hub $HubName"

    # The same query for two metrics: a scriptblock called twice, with the metric name as argument.
    $read = {
        param($metric)

        # 'sum( ... )' needs the spaces: PowerShell passes a bare 'sum(...)' to az.cmd unquoted.
        # The JMESPath expression adds up the hourly totals of the first (only) time series.
        $v = az monitor metrics list `
            --resource $id `
            --metric $metric `
            --aggregation Total `
            --interval PT1H `
            --offset "${Hours}h" `
            --query 'sum( value[0].timeseries[0].data[].total )' `
            -o tsv `
            --only-show-errors

        # No data (empty output) is reported as 0, not as an error.
        if ($v) { [double]$v } else { 0 }
    }

    [pscustomobject]@{
        Hub     = $HubName
        Ingress = (& $read 'd2c.telemetry.ingress.success')
        Egress  = (& $read 'd2c.telemetry.egress.success')
    }
}
