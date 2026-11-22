function Initialize-Sim {
    # WHAT: starts the simulated clock.
    # WHY:  time starts now; Step-Sim moves it forward. Certificates are issued with simulated dates.
    # HOW:  the state lives in the global $Sim because the notebook cells share one session and every function reads it.
    #       Base = real "now" (UTC), Day = simulated days elapsed since then.
    $global:Sim = @{
        Base = [DateTimeOffset]::UtcNow
        Day  = 0.0
    }
}
