using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    // Explicit production opt-in; detached mutable fixtures keep the old policy.
    private bool _laborEnabled;
    private decimal _jobsPerWorker=1.05m, _commercialShare=0.60m;
    private int _neighborInbound, _neighborOutbound, _laborCommercialJobs, _laborIndustrialJobs;
    public void ConfigureLaborPolicy(D options)
    {
        bool enabled=options.TryGetValue("enabled",out var e)?e.AsBool():_laborEnabled;
        double jobs=options.TryGetValue("jobs_per_worker",out var j)?j.AsDouble():(double)_jobsPerWorker;
        double share=options.TryGetValue("commercial_share",out var s)?s.AsDouble():(double)_commercialShare;
        int cacheLimit=options.ContainsKey("max_cached_home_routes")?Int(options,"max_cached_home_routes"):_laborCacheLimit;
        if(!double.IsFinite(jobs)||jobs<0||!double.IsFinite(share)||share<0||share>1)throw new ArgumentException("Invalid labor policy");
        if(cacheLimit<1||cacheLimit>4096)throw new ArgumentException("max_cached_home_routes must be 1..4096");
        decimal jobPolicy=(decimal)jobs,commercialPolicy=(decimal)share;
        if(_laborEnabled!=enabled)InvalidateHappiness();
        _laborEnabled=enabled;_jobsPerWorker=jobPolicy;_commercialShare=commercialPolicy;
        _laborCacheLimit=cacheLimit;TrimLaborRouteCache();
        InvalidateManagedSnapshots();
    }
    // Parent supplies connected-route, daily neighbor allocations, not this engine.
    // Estimates only: no demand or matching effects. Concrete plans are required
    // to avoid double-filling local slots or fabricating external employment.
    public void SetNeighborCommuters(int inbound,int outbound)
    {
        if(inbound<0||outbound<0)throw new ArgumentOutOfRangeException(nameof(inbound));
        _neighborInbound=inbound;_neighborOutbound=outbound;InvalidateManagedSnapshots();
    }
    private void ResetLaborInventory(){_laborCommercialJobs=0;_laborIndustrialJobs=0;}
    private void CountLaborBuilding(Building b)
    {
        if(b.Zone=="residential")return;
        int slots=(b.Zone=="commercial"?_commercial:_industrial).Sum()* (b.Size*b.Size/4)*Math.Max(1,b.Level);
        if(b.Zone=="commercial")_laborCommercialJobs+=slots;else _laborIndustrialJobs+=slots;
    }
    private (int Eligible,int Employed) LaborPopulation()
    {
        int eligible=0,employed=0;foreach(var p in _people)if(p.Age>=_workingAge){eligible++;if(p.Work!=-1)employed++;}
        return (eligible,employed);
    }
    private (int Vacant,int Unemployed,int Inbound,int Outbound,int Surplus) LaborBalance()
    {
        var (eligible,employed)=LaborPopulation();int vacant=Math.Max(0,_laborCommercialJobs+_laborIndustrialJobs-employed),unemployed=Math.Max(0,eligible-employed);
        int inbound=_laborEnabled?Math.Min(_laborInbound.Values.Sum(a=>a.Sum()),vacant):0,outbound=_laborEnabled?Math.Min(_laborOutbound.Count,unemployed):0;
        return (vacant,unemployed,inbound,outbound,Math.Max(0,vacant-inbound-(unemployed-outbound)));
    }
    private static int BuildingEquivalents(decimal deficit,int capacity)=>capacity<=0?0:checked((int)Math.Ceiling(Math.Max(0,deficit)/capacity));
    private D LaborDemandResult()
    {
        int eligible=LaborPopulation().Eligible;var balance=LaborBalance();
        // All R/C/I outputs are counts of new level-1 2x2 buildings. Bootstrap
        // initial_housing_target retains its original household-capacity meaning.
        int residential=eligible==0
            ?BuildingEquivalents(Math.Max(0,_initialHousing-_households.Count-_vacancies),_unitsPerLot)
            :BuildingEquivalents(Math.Max(0,Math.Ceiling((decimal)balance.Surplus/Math.Max(1,_immigrantAdults))-_vacancies),_unitsPerLot);
        decimal needed=eligible*_jobsPerWorker;
        return new D{["residential"]=residential,
            ["commercial"]=BuildingEquivalents(needed*_commercialShare-_laborCommercialJobs,_commercial.Sum()),
            ["industrial"]=BuildingEquivalents(needed*(1-_commercialShare)-_laborIndustrialJobs,_industrial.Sum())};
    }
    public D GetNeighborCommuters()
    {
        var b=LaborBalance();return new D{["requested_inbound"]=_neighborInbound,["requested_outbound"]=_neighborOutbound,["inbound"]=b.Inbound,["outbound"]=b.Outbound};
    }
    public D LaborDemandDiagnostics()
    {
        var b=LaborBalance();var p=LaborPopulation();return new D{["enabled"]=_laborEnabled,["eligible"]=p.Eligible,["employed_local"]=p.Employed,
            ["needed_jobs"]=(double)(p.Eligible*_jobsPerWorker),["jobs_per_worker"]=(double)_jobsPerWorker,["commercial_share"]=(double)_commercialShare,
            ["commercial_jobs"]=_laborCommercialJobs,["industrial_jobs"]=_laborIndustrialJobs,["commercial_new_slots"]=_commercial.Sum(),["industrial_new_slots"]=_industrial.Sum(),
            ["vacant_jobs"]=b.Vacant,["unemployed"]=b.Unemployed,["inbound"]=b.Inbound,["outbound"]=b.Outbound,["surplus_jobs"]=b.Surplus,
            ["vacant_household_units"]=_vacancies,["initial_housing_target_household_units"]=_initialHousing,["bootstrap"]=p.Eligible==0,
            ["residential_units"]="ceil(max(0,ceil(surplus_jobs / immigrant_adults_per_household) - vacant_household_units) / households_per_2x2)",
            ["commercial_capacity_valid"]=_commercial.Sum()>0,["industrial_capacity_valid"]=_industrial.Sum()>0};
    }
}
