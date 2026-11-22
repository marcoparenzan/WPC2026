function Get-FleetCertTable {
    # WHAT: one row per device with certificate state, days left, expiry, thumbprint and bootstrap expiry.
    # WHY:  the fleet at a glance in a notebook cell: who is valid, who must renew, whose bootstrap credential is about to expire.
    # HOW:  asks Get-DeviceCertStatus for each device and adds the fields that belong to the device itself (Online, bootstrap date).
    param(
        [Parameter(Mandatory)]$Devices
    )

    $Devices | ForEach-Object {
        $s = Get-DeviceCertStatus $_
        [pscustomobject]@{
            Device           = $_.Id
            Online           = $_.Online
            Certificate      = $s.State
            DaysLeft         = $s.DaysLeft
            Expires          = $s.NotAfter
            Thumbprint       = $s.Thumbprint
            BootstrapExpires = $_.BootstrapNotAfter.ToString('yyyy-MM-dd')
        }
    }
}
