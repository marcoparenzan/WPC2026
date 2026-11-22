function Register-DemoDpsCa {
    <#
    .SYNOPSIS
    Uploads a CA to DPS and VERIFIES it (proof of possession).
    .DESCRIPTION
    An enrollment group accepts devices only if it references a verified CA (--root-ca-name): with --certificate-path DPS
    answers 401002 Invalid certificate. Safe to run again: a CA that is already verified is left alone.
    .PARAMETER DpsName
    Name of the DPS.
    .PARAMETER Rg
    Resource group.
    .PARAMETER Name
    Name of the certificate resource on DPS (for example pcert-iot26-dev-robots).
    .PARAMETER CaDir
    Folder of the local CA (ca.pem, ca-key.pem); verification.pem is written there.
    #>
    param(
        [Parameter(Mandatory)][string]$DpsName,
        [Parameter(Mandatory)][string]$Rg,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$CaDir
    )

    # 1) Is the CA already there, and verified? "show" fails (non-zero exit code) when the resource does not exist.
    #    The -match 'rue' accepts both "True" and "true", whatever the CLI prints.
    $verified = az iot dps certificate show `
        --dps-name $DpsName `
        --resource-group $Rg `
        --certificate-name $Name `
        --query properties.isVerified `
        -o tsv `
        --only-show-errors 2>$null

    if ($LASTEXITCODE -eq 0 -and "$verified" -match 'rue') {
        Write-Host "  CA '$Name' gia' verificata su DPS." -ForegroundColor Green
        return
    }

    # 2) Not there yet: upload the public part (ca.pem). If it exists but is not verified, skip the upload.
    if ($LASTEXITCODE -ne 0) {
        az iot dps certificate create `
            --dps-name $DpsName `
            --resource-group $Rg `
            --certificate-name $Name `
            --path (Join-Path $CaDir 'ca.pem') `
            --only-show-errors `
            -o none
        Assert-Az "Caricamento della CA '$Name'"
    }

    # 3) Ask DPS for the verification code.
    # A CA that has just been uploaded is not always ready: the first request for the code returned nothing (2026-11-16, real DPS).
    # So up to 6 attempts, re-reading the etag each time. The code is a long alphanumeric line; warnings and errors contain spaces,
    # so they can never be taken for the code and end up in the CN of the verification certificate. The last answer is kept for the error message.
    $code   = $null
    $answer = ''
    for ($try = 1; $try -le 6 -and -not $code; $try++) {
        # The etag is the version of the resource: DPS refuses the call if it is not the current one.
        $etag = az iot dps certificate show `
            --dps-name $DpsName `
            --resource-group $Rg `
            --certificate-name $Name `
            --query etag `
            -o tsv `
            --only-show-errors 2>$null

        # 2>&1: warnings and errors come back in the same output, so they can be shown if the code never arrives.
        $raw = az iot dps certificate generate-verification-code `
            --dps-name $DpsName `
            --resource-group $Rg `
            --certificate-name $Name `
            --etag $etag `
            --query properties.verificationCode `
            -o tsv `
            --only-show-errors 2>&1

        # Trim every line and drop the empty ones, then keep the last one that looks like a code.
        $lines = @($raw) | ForEach-Object { "$_".Trim() } | Where-Object { $_ }
        $code  = $lines | Where-Object { $_ -match '^[0-9A-Za-z]{16,}$' } | Select-Object -Last 1

        if (-not $code) {
            $answer = ($lines | Select-Object -First 3) -join ' | '
            Write-Host "  codice di verifica non ancora disponibile ($try/6)..." -ForegroundColor DarkGray
            Start-Sleep -Seconds 5
        }
    }
    if (-not $code) {
        throw "Codice di verifica non ricevuto per '$Name'. Risposta: $answer"
    }
    Write-Host "  codice di verifica DPS: $code" -ForegroundColor DarkGray

    # 4) Proof of possession: a certificate with CN = code, signed with the CA's private key.
    $verification = Join-Path $CaDir 'verification.pem'
    New-DemoVerificationCert -CaDir $CaDir -Code $code -OutPath $verification

    # 5) Send it. The etag is read again: generating the code changed the version of the resource.
    $etag = az iot dps certificate show `
        --dps-name $DpsName `
        --resource-group $Rg `
        --certificate-name $Name `
        --query etag `
        -o tsv `
        --only-show-errors
    az iot dps certificate verify `
        --dps-name $DpsName `
        --resource-group $Rg `
        --certificate-name $Name `
        --path $verification `
        --etag $etag `
        --only-show-errors `
        -o none
    Assert-Az "Verifica (proof of possession) della CA '$Name'"
    Write-Host "  CA '$Name' verificata su DPS." -ForegroundColor Green
}
