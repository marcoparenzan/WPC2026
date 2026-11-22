function Test-HubAcceptsCertificate {
    <#
    .SYNOPSIS
    Sends one test message to the IoT Hub with the device's certificate and returns the HTTP status code.
    .DESCRIPTION
    204 (or 200) means the Hub accepted the certificate; 401 means it refused it (for example after a revocation).
    The leaf certificate and the private key are read from the device folder (issued-chain.pem, device-key.pem), as written by Register-DemoDevice.
    .PARAMETER Hub
    Host name of the Hub, for example iot-iot26-dev-uks-002.azure-devices.net.
    .PARAMETER DeviceId
    Registration ID of the device.
    .PARAMETER StateDir
    Folder of the device with issued-chain.pem and device-key.pem.
    .OUTPUTS
    The HTTP status code (int).
    #>
    param(
        [Parameter(Mandatory)][string]$Hub,
        [Parameter(Mandatory)][string]$DeviceId,
        [Parameter(Mandatory)][string]$StateDir
    )

    # issued-chain.pem holds leaf + CAs; TLS client authentication needs the leaf (the first block) with its key.
    $chain = [IO.File]::ReadAllText((Join-Path $StateDir 'issued-chain.pem'))
    $leaf  = [regex]::Match($chain, '-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', 'Singleline').Value
    $key   = [IO.File]::ReadAllText((Join-Path $StateDir 'device-key.pem'))
    $c     = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($leaf, $key)

    # Exported and imported as PFX: Windows cannot use an ephemeral key for TLS client authentication.
    $pfxBytes = $c.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx)
    $pfx      = [Security.Cryptography.X509Certificates.X509Certificate2]::new($pfxBytes)

    try {
        $body = @{ test = 'connection check'; ts = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json -Compress

        # The device-to-cloud REST endpoint. The device is identified by the certificate (no SAS token).
        # -SkipHttpErrorCheck: a 401 must come back as a status code, not as an exception.
        $r = Invoke-WebRequest -Method Post `
            -Uri "https://$Hub/devices/$DeviceId/messages/events?api-version=2021-04-12" `
            -Certificate $pfx `
            -ContentType 'application/json' `
            -Body $body `
            -SkipHttpErrorCheck `
            -TimeoutSec 30
        [int]$r.StatusCode
    }
    finally {
        $pfx.Dispose()
        $c.Dispose()
    }
}
