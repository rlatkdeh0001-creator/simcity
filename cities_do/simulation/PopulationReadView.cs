using System;
using System.Collections.Immutable;
using Godot;
using D=Godot.Collections.Dictionary;
using A=Godot.Collections.Array;

// No mutable population/core references escape into this read facade.
public partial class PopulationReadView : RefCounted
{
    internal sealed record Workplace(string Zone,bool HasZone,ImmutableArray<int> Slots,ImmutableArray<int> Filled);
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
    private static D WorkplaceState(long id,Workplace w){var d=new D{["id"]=id,["slots"]=Thaw(w.Slots),["filled"]=Thaw(w.Filled)};if(w.HasZone)d["zone"]=w.Zone;return d;}
    public long GetNextPerson()=>NextPersonValue;
    public long GetNextHousehold()=>NextHouseholdValue;
    public double GetElapsedDays()=>ElapsedValue;
    public int GetBirthDay()=>BirthValue;
    public long GetRngSeed()=>RngSeedValue;
    public long GetRngState()=>RngStateValue;
}
