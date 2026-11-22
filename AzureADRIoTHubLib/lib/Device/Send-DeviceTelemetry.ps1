function Send-DeviceTelemetry {
    # WHAT: sends one telemetry message of a device.
    # WHY:  with an assigned Hub the message really goes to the IoT Hub; otherwise (local simulation or -DryRun) it is only
    #       written to the device folder, so the demo works without Azure. The real send is NOT proven (see README).
    # HOW:  real: POST https://<hub>/devices/<id>/messages/events with the TLS client certificate.
    #       local: one JSON line appended to telemetry-out.jsonl.
    #       Returns 'sent' or 'dry-run'.
    param(
        $Dev,
        [Parameter(Mandatory)]$Message,
        [switch]$DryRun
    )

    $json = $Message | ConvertTo-Json -Compress

    # No Hub assigned means the device never registered with a real DPS: nowhere to send to.
    if ($DryRun -or -not $Dev.AssignedHub) {
        Add-Content -Path (Join-Path $Dev.Dir 'telemetry-out.jsonl') -Value $json -Encoding utf8
        return 'dry-run'
    }

    # The device authenticates with its operational certificate (no SAS token, no shared key).
    $cert = New-DeviceClientCertificate $Dev
    try {
        Invoke-RestMethod -Method Post `
            -Uri "https://$($Dev.AssignedHub)/devices/$($Dev.Id)/messages/events?api-version=2021-04-12" `
            -Certificate $cert `
            -ContentType 'application/json' `
            -Body $json | Out-Null
        return 'sent'
    }
    finally {
        $cert.Dispose()
    }
}
