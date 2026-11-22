function Invoke-DeviceTick {
    # WHAT: the application's daily check on its own certificate.
    # WHY:  the decision is the device's, not the service's:
    #         no certificate -> register; expired -> register again with the bootstrap credential; 20% of life left -> renew.
    # HOW:  reads the state with Get-DeviceCertStatus and calls Invoke-DeviceRegistration when something is due.
    param(
        $Dev,
        [double]$RenewAtFraction = 0.2
    )

    $s = Get-DeviceCertStatus $Dev

    # Relaunched with a certificate but without the Hub on disk: the Hub is only learned from a registration, so register again.
    if ($Dev.Dps -and -not $Dev.AssignedHub -and $s.State -ne 'none') {
        [void](Invoke-DeviceRegistration $Dev 're-registration: assigned Hub unknown after relaunch')
        return
    }

    # 'valid' has no branch on purpose: nothing to do today.
    switch ($s.State) {
        'none'      { [void](Invoke-DeviceRegistration $Dev 'first registration') }
        'expired'   { [void](Invoke-DeviceRegistration $Dev 're-registration after expiry') }
        'renew-due' { [void](Invoke-DeviceRegistration $Dev ("renewal, {0:n1} of {1:n0} days left" -f $s.DaysLeft, $s.LifeDays)) }
    }
}
