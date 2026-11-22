function Add-DeviceEvent {
    # WHAT: records something that happened to a device, in memory ($Dev.Events) and in its device.log file.
    # WHY:  the notebooks show the story of each device (registered, renewed, refused...) as a table, and the log
    #       stays on the device's "disk" like a real device log would.
    # HOW:  the time stamp is the SIMULATED time (Get-SimNow), so the log reads like the days of the demo, not like the minutes it took to run.
    param(
        $Dev,
        [string]$What
    )

    # Same news as the last event: say it once. Without this an offline device would add one identical line every simulated day.
    if ($Dev.Events.Count -gt 0 -and $Dev.Events[$Dev.Events.Count - 1].Event -eq $What) {
        return
    }

    $Dev.Events.Add([pscustomobject]@{
        Day    = [math]::Round($global:Sim.Day, 1)
        Device = $Dev.Id
        Event  = $What
    })

    $line = "{0:yyyy-MM-dd HH:mm} (day {1:n1}) {2}" -f (Get-SimNow), $global:Sim.Day, $What
    Add-Content -Path (Join-Path $Dev.Dir 'device.log') -Value $line -Encoding utf8
}
