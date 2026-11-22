function Start-DemoCertApi {
    <#
    .SYNOPSIS
    Starts the certificate API (api\cert-api.cs) in the background and waits until it answers.
    .DESCRIPTION
    The API only lets in clients whose certificate was issued by ADR (see the header of cert-api.cs). It runs on this
    computer with `dotnet run`: the first start compiles it and takes a few seconds.
    The output goes to a log file in the temp folder, not to the repository.
    Stop it with: & taskkill /PID $process.Id /T /F  (`dotnet run` starts a child process: /T stops both).
    .PARAMETER ApiFile
    Full path of cert-api.cs.
    .PARAMETER TrustFile
    PEM with the ADR Root CA and Issuing CA (adr-trust.pem, from Export-AdrCaCertificates).
    .PARAMETER Port
    Local HTTPS port (default 8443).
    .PARAMETER TimeoutSeconds
    How long to wait for the first start (default 150).
    .OUTPUTS
    The process. The log is in $env:TEMP\cert-api.log (and .err).
    #>
    param(
        [Parameter(Mandatory)][string]$ApiFile,
        [Parameter(Mandatory)][string]$TrustFile,
        [int]$Port = 8443,
        [int]$TimeoutSeconds = 150
    )

    if (-not (Test-Path $ApiFile))   { throw "Missing $ApiFile." }
    if (-not (Test-Path $TrustFile)) { throw "Missing ${TrustFile}: run Export-AdrCaCertificates first." }

    # Output and errors go to files: a hidden process has no window to print in.
    $log = Join-Path ([IO.Path]::GetTempPath()) 'cert-api.log'
    $arguments = @('run', (Format-Arg $ApiFile), '--', (Format-Arg $TrustFile), $Port)
    $process = Start-Process dotnet -ArgumentList $arguments -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"

    # Wait until the port accepts connections; stop early if the process died (a compile error, for instance).
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($process.HasExited) {
            throw "The API stopped at start: $((Get-Content "$log.err" -Raw)) $((Get-Content $log -Raw))"
        }
        try {
            $probe = [Net.Sockets.TcpClient]::new('localhost', $Port)
            $probe.Dispose()
            return $process
        }
        catch {
            Start-Sleep -Milliseconds 700
        }
    }

    & taskkill /PID $process.Id /T /F 2>&1 | Out-Null
    throw "The API did not answer on port $Port within $TimeoutSeconds seconds."
}
