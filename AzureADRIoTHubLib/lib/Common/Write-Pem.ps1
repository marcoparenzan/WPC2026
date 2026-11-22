function Write-Pem {
    <#
    .SYNOPSIS
    Writes bytes as a PEM file (LF line ends, UTF-8 without BOM).
    .PARAMETER Path
    Output file.
    .PARAMETER Label
    PEM label: 'CERTIFICATE', 'PRIVATE KEY', 'CERTIFICATE REQUEST'...
    .PARAMETER Bytes
    DER bytes to encode.
    #>
    param(
        [string]$Path,
        [string]$Label,
        [byte[]]$Bytes
    )

    # PEM = Base64 of the DER bytes, wrapped at 76 characters, between BEGIN/END lines that carry the label.
    # InsertLineBreaks does the wrapping, but with CRLF on Windows.
    $b64 = [Convert]::ToBase64String($Bytes, [Base64FormattingOptions]::InsertLineBreaks)

    # Normalise to LF: OpenSSL, the Azure CLI and git all read the file the same way on every platform.
    $body = $b64 -replace "`r`n", "`n"
    $pem  = "-----BEGIN $Label-----`n$body`n-----END $Label-----`n"

    # UTF-8 *without* BOM: a BOM in front of "-----BEGIN" makes some PEM parsers reject the file.
    [IO.File]::WriteAllText($Path, $pem, [Text.UTF8Encoding]::new($false))
}
