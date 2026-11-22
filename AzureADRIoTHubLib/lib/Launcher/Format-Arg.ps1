function Format-Arg {
    <#
    .SYNOPSIS
    Quotes a command-line argument when it contains white space.
    .PARAMETER a
    The argument.
    .EXAMPLE
    @('-File', 'C:\My Folder\_run-device.ps1') | ForEach-Object { Format-Arg $_ }   # -File and "C:\My Folder\_run-device.ps1"
    #>
    param(
        $a
    )

    # WHY: Start-Process joins -ArgumentList into ONE string; an argument with a space (a path such as "C:\My Folder\...")
    # would be split in two by the new process. Quoting the ones that need it keeps them whole; the others stay as they are.
    if ("$a" -match '\s') {
        "`"$a`""
    }
    else {
        "$a"
    }
}
