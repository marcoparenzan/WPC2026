function Test-MqttBrokerAcceptsCertificate {
    <#
    .SYNOPSIS
    Connects to an MQTT broker over TLS with a client certificate and says whether the broker accepted it.
    .DESCRIPTION
    It does what an MQTT client does in its first moment: opens a TLS connection presenting the certificate, sends a CONNECT
    packet and reads the answer (CONNACK). Nothing is published or subscribed.
    Three outcomes tell different stories:
      accepted                       the certificate was trusted and the client is known to the broker
      refused: ... CONNACK code N    the TLS handshake passed (the certificate chain is trusted) but the broker refused the client
      refused: <TLS error>           the broker did not even accept the TLS handshake
    Event Grid never ends in the third case for a certificate it does not trust: it lets the handshake pass and answers CONNACK 5 to
    the CONNECT, whatever the reason (unknown CA, client not registered, certificate it does not accept). Observed on 2026-11-22.
    By default it uses the certificate ADR issued to the device (issued-chain.pem and device-key.pem); a second certificate
    can be tried with -CertFile and -KeyFile (the notebooks use the bootstrap certificate as a control).
    .PARAMETER Hostname
    Host name of the broker, for example the MQTT host name of an Event Grid namespace.
    .PARAMETER DeviceId
    The name the client presents: client id and user name. For Event Grid it is the client authentication name.
    .PARAMETER StateDir
    Folder of the device (it holds the certificate and the key files).
    .PARAMETER CertFile
    Certificate file in StateDir (default issued-chain.pem: the first certificate of the file is the one used).
    .PARAMETER KeyFile
    Private key file in StateDir (default device-key.pem).
    .PARAMETER Port
    TCP port (default 8883, MQTT over TLS).
    .PARAMETER SkipServerCertificateCheck
    Do not check the certificate of the broker. Only for a test broker on this computer: never for a real service.
    .OUTPUTS
    One line of text: 'accepted' or 'refused: <reason>'.
    #>
    param(
        [Parameter(Mandatory)][string]$Hostname,
        [Parameter(Mandatory)][string]$DeviceId,
        [Parameter(Mandatory)][string]$StateDir,
        [string]$CertFile = 'issued-chain.pem',
        [string]$KeyFile = 'device-key.pem',
        [int]$Port = 8883,
        [switch]$SkipServerCertificateCheck
    )

    # The client certificate with its private key. Exported and imported as PFX: Windows cannot use an ephemeral key for TLS.
    $pem  = [IO.File]::ReadAllText((Join-Path $StateDir $CertFile))
    $leaf = [regex]::Match($pem, '-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----', 'Singleline').Value
    $key  = [IO.File]::ReadAllText((Join-Path $StateDir $KeyFile))
    $c    = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($leaf, $key)
    $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new($c.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx))
    $c.Dispose()

    $tcp = $null
    $ssl = $null
    try {
        $tcp = [Net.Sockets.TcpClient]::new()
        $tcp.ReceiveTimeout = 15000
        $tcp.SendTimeout    = 15000
        $tcp.Connect($Hostname, $Port)

        # The TLS handshake: here the broker decides whether it trusts the certificate chain.
        $ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false)
        $options = [Net.Security.SslClientAuthenticationOptions]::new()
        $options.TargetHost = $Hostname
        if ($SkipServerCertificateCheck) { $options.RemoteCertificateValidationCallback = { $true } }
        $options.ClientCertificates = [Security.Cryptography.X509Certificates.X509CertificateCollection]::new()
        [void]$options.ClientCertificates.Add($cert)
        $ssl.AuthenticateAsClient($options)

        # CONNECT, then CONNACK: 4 bytes (type 0x20, length 2, session flags, return code).
        $packet = New-MqttConnectPacket -ClientId $DeviceId -Username $DeviceId
        $ssl.Write($packet, 0, $packet.Length)
        $ssl.Flush()

        $reply = [byte[]]::new(4)
        $read  = 0
        while ($read -lt 4) {
            $n = $ssl.Read($reply, $read, 4 - $read)
            if ($n -le 0) { break }
            $read += $n
        }

        if ($read -lt 4)       { return 'refused: the broker closed the connection after the TLS handshake' }
        if ($reply[0] -ne 0x20) { return "refused: unexpected answer (first byte $($reply[0]))" }
        if ($reply[3] -eq 0)   { return 'accepted' }
        return "refused: CONNACK code $($reply[3])"
    }
    catch {
        return "refused: $($_.Exception.Message)"
    }
    finally {
        if ($ssl) { $ssl.Dispose() }
        if ($tcp) { $tcp.Dispose() }
        $cert.Dispose()
    }
}
