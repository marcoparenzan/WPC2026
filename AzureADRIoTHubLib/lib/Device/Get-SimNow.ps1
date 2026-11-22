function Get-SimNow {
    # WHAT: the current time of the simulation.
    # WHY:  certificates last weeks; the demo lasts minutes. Everything that asks "what time is it?" asks here, so time can be moved forward.
    # HOW:  the real time at Initialize-Sim plus the simulated days elapsed (Step-Sim moves $global:Sim.Day).
    $global:Sim.Base.AddDays($global:Sim.Day)
}
