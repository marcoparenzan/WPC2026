function New-DeviceTelemetry {
    # WHAT: builds one telemetry message: time stamp, device id, temperature, setpoint, payload version, alarm state.
    # WHY:  every device sends the same shape. deviceId is in the BODY on purpose: downstream readers must not depend on system properties.
    # HOW:  the temperature is the setpoint plus a random noise of +/- 0.6 degrees; above setpoint + 5 the alarm is 'high'.
    #       A caller can pass its own Random (with a seed) to get repeatable values.
    param(
        $Dev,
        [double]$Setpoint = 21,
        [Random]$Rng = [Random]::new()
    )

    # NextDouble() is in [0,1): minus 0.5 centres it on zero, times 1.2 makes the span 1.2 degrees.
    $t = [math]::Round($Setpoint + ($Rng.NextDouble() - 0.5) * 1.2, 2)

    [ordered]@{
        # ISO 8601 round-trip format ('o'), in UTC, from the simulated clock.
        ts             = (Get-SimNow).UtcDateTime.ToString('o')
        deviceId       = $Dev.Id
        temperature    = $t
        setpoint       = $Setpoint
        payloadVersion = '1.0.0'
        alarmState     = $(if ($t -gt $Setpoint + 5) { 'high' } else { 'ok' })
    }
}
