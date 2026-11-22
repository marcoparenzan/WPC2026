function Install-Payload {
    <#
    .SYNOPSIS
    DEVICE side: staging, signature check, trial run, promotion; otherwise rollback to the last known good version.
    .DESCRIPTION
    Takes thermostat-<Version>.ps1 and its manifest from <Root>\server\outbox. If the signature is wrong the current payload
    does not change. Otherwise the current payload is kept as last-known-good, the new one becomes current and is run once:
    if the trial fails (no exception allowed, a temperature required) the previous version is restored.
    The device folder is <Root>\device (payload\current.ps1, payload\last-known-good.ps1, signing-public.pem).
    .PARAMETER Version
    Version to install.
    .PARAMETER Root
    Base folder of the demo (it contains server\ and device\).
    .OUTPUTS
    One line of text that says what happened.
    .NOTES
    Replaces the function that used to be defined inside notebook 06, which read $root from the notebook.
    #>
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Root
    )

    $pay   = Join-Path $Root 'device\payload'
    $inbox = Join-Path $Root 'server\outbox'
    $new   = Join-Path $inbox "thermostat-$Version.ps1"
    $man   = Join-Path $inbox "thermostat-$Version.json"

    # 1) Verify BEFORE touching anything: the device trusts only what the server signed.
    #    On a bad signature the current payload stays exactly as it was.
    $r = Test-PayloadSignature -ScriptPath $new -ManifestPath $man -PublicKeyPath (Join-Path $Root 'device\signing-public.pem')
    if ($r -ne 'ok') {
        "[$Version] RIFIUTATO: $r. Il payload corrente non cambia."
        return
    }

    # 2) Promote: keep the running version as "last known good" (the way back), then make the new one current.
    $cur = Join-Path $pay 'current.ps1'
    $lkg = Join-Path $pay 'last-known-good.ps1'
    if (Test-Path $cur) { Copy-Item $cur $lkg -Force }
    Copy-Item $new $cur -Force

    # 3) Trial run: a valid signature proves who wrote the code, not that it works.
    #    Run it once; no exception and a temperature in the result are required.
    #    If it fails, restore the last known good version, so the device never ends with a broken payload.
    try {
        $t = Get-DevicePayloadTelemetry $cur
        if ($null -eq $t.temperature) { throw 'telemetria senza temperatura' }
        "[$Version] firma ok, prova superata: ATTIVO."
    }
    catch {
        Copy-Item $lkg $cur -Force
        "[$Version] firma ok ma la PROVA e' fallita ($($_.Exception.Message)): ritorno alla versione precedente."
    }
}
