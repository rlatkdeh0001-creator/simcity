using System;
using System.Collections.Immutable;
using Godot;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;

// No mutable population/core references escape into this read facade.
public partial class PopulationReadView : RefCounted
{
    internal sealed record Workplace(string Zone,bool HasZone,ImmutableArray<int> Slots,ImmutableArray<int> Filled,ImmutableArray<int> InboundReserved);
    // Typed scalar publication only: no per-person plans or mutable core references.
    internal sealed record LaborPublication(bool Enabled,double JobsPerWorker,double CommercialShare,int MaxCachedHomeRoutes,int RequestedInbound,int RequestedOutbound,int Inbound,int Outbound);
    internal LaborPublication LaborValue=new(false,1.05,0.60,128,0,0,0,0);
    public D LaborPolicyInfo()=>new(){["enabled"]=LaborValue.Enabled,["jobs_per_worker"]=LaborValue.JobsPerWorker,["commercial_share"]=LaborValue.CommercialShare,["max_cached_home_routes"]=LaborValue.MaxCachedHomeRoutes};
    public D GetNeighborCommuters()=>new(){["requested_inbound"]=LaborValue.RequestedInbound,["requested_outbound"]=LaborValue.RequestedOutbound,["inbound"]=LaborValue.Inbound,["outbound"]=LaborValue.Outbound};
    internal ImmutableDictionary<long,Workplace> Works=ImmutableDictionary<long,Workplace>.Empty;
    internal ImmutableDictionary<string,long> StatValues=ImmutableDictionary<string,long>.Empty;
    internal ImmutableDictionary<string,long> DemandValues=ImmutableDictionary<string,long>.Empty;
    internal long NextPersonValue,NextHouseholdValue,RngSeedValue,RngStateValue;
    internal double ElapsedValue;
    internal int BirthValue;
    private static D Thaw(ImmutableDictionary<string,long> source){var d=new D();foreach(var p in source)d[p.Key]=p.Value;return d;}
    private static A Thaw(ImmutableArray<int> source){var a=new A();foreach(int n in source)a.Add(n);return a;}
    public D Stats()=>Thaw(StatValues);
    public D Demand()=>Thaw(DemandValues);
    public D WorkplaceInfo(long id)=>Works.TryGetValue(id,out var w)?WorkplaceState(id,w):new D();
    private static D WorkplaceState(long id,Workplace w)
    {
        var d=new D{["id"]=id,["slots"]=Thaw(w.Slots),["filled"]=Thaw(w.Filled)};
        // Empty reservations encode disabled policy and preserve legacy dictionary shapes.
        if(w.InboundReserved.Length==5)
        {
            d["inbound_reserved"]=Thaw(w.InboundReserved);var free=new A();
            for(int stage=0;stage<5;stage++)free.Add(Math.Max(0,w.Slots[stage]-w.Filled[stage]-w.InboundReserved[stage]));
            d["free_slots"]=free;
        }
        if(w.HasZone)d["zone"]=w.Zone;return d;
    }
    public long GetNextPerson()=>NextPersonValue;
    public long GetNextHousehold()=>NextHouseholdValue;
    public double GetElapsedDays()=>ElapsedValue;
    public int GetBirthDay()=>BirthValue;
    public long GetRngSeed()=>RngSeedValue;
    public long GetRngState()=>RngStateValue;
}
