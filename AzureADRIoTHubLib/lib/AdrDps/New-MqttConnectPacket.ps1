function New-MqttConnectPacket {
    <#
    .SYNOPSIS
    Builds the bytes of an MQTT 3.1.1 CONNECT packet.
    .DESCRIPTION
    CONNECT is the first packet a client sends to an MQTT broker. The broker answers with CONNACK: a return code of 0 means
    "accepted". This is all that is needed to prove that a broker accepts a certificate, so there is no MQTT library:
    the packet is small and fixed.
    Layout: fixed header (type 1, remaining length) + protocol name "MQTT" + level 4 + flags + keep alive + client id + user name.
    .PARAMETER ClientId
    The client id (text).
    .PARAMETER Username
    The user name. Event Grid reads the client authentication name from here.
    .OUTPUTS
    The packet as byte[].
    #>
    param(
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$Username
    )

    $utf8 = [Text.UTF8Encoding]::new($false)
    $body = [System.Collections.Generic.List[byte]]::new()

    $body.AddRange([byte[]](0x00, 0x04, 0x4D, 0x51, 0x54, 0x54))   # protocol name: length 4, "MQTT"
    $body.Add(0x04)                                                 # protocol level 4 = MQTT 3.1.1
    $body.Add(0x82)                                                 # flags: user name present (0x80) + clean session (0x02)
    $body.AddRange([byte[]](0x00, 0x3C))                            # keep alive: 60 seconds

    # Client id and user name: each is a text with a 2-byte length in front.
    foreach ($text in $ClientId, $Username) {
        $bytes = $utf8.GetBytes($text)
        $body.Add([byte]($bytes.Length -shr 8))
        $body.Add([byte]($bytes.Length -band 0xFF))
        $body.AddRange($bytes)
    }

    # The length is written in one byte here: enough for short names, and the function says so when it is not.
    if ($body.Count -gt 127) {
        throw 'ClientId and Username are too long for this simple encoder (the packet must stay under 128 bytes after the header).'
    }

    $packet = [System.Collections.Generic.List[byte]]::new()
    $packet.Add(0x10)                 # packet type 1 (CONNECT), no flags
    $packet.Add([byte]$body.Count)    # remaining length
    $packet.AddRange($body)

    # The comma keeps the array as one object: without it PowerShell would unroll the bytes into the output.
    return , $packet.ToArray()
}
