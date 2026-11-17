using System;

public partial class HappinessCore
{
    // Full-city-worker path only: call after changing the bound population's tax
    // policy, before any pending upgrade is consumed. Legacy standalone background
    // happiness would need its own immutable policy command; it is not enabled here.
    public void NotifyTaxPolicyChanged()
    {
        RequireBackgroundOwner();
        if(_backgroundEnabled)throw new InvalidOperationException("Tax edits require the full city worker");
        foreach(var b in _buildings.Values)
        {
            var s=_states[b.Id];Observe(b,s);if(!Qualifies(b,s))s.Pending=false;
        }
    }
}
