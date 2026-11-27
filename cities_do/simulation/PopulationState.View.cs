using System.Collections.Immutable;
using System.Linq;
using Godot;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    private ImmutableDictionary<long,PopulationReadView.Workplace> _cityReadWorks=ImmutableDictionary<long,PopulationReadView.Workplace>.Empty;
    private static ImmutableDictionary<string,long> FreezeCityNumbers(D d){var b=ImmutableDictionary.CreateBuilder<string,long>();foreach(var key in d.Keys)b[key.AsString()]=d[key].AsInt64();return b.ToImmutable();}
    // Worker-only capture. O(workplaces) comparisons, never O(people) native exports.
    public PopulationReadView CaptureCityReadView()
    {
        var builder=_cityReadWorks.ToBuilder();
        foreach(long id in _cityReadWorks.Keys)if(!_works.ContainsKey(id))builder.Remove(id);
        foreach(var pair in _works)
        {
            var w=pair.Value;
            var reserved=_laborEnabled?Enumerable.Range(0,5).Select(stage=>InboundReserved(pair.Key,stage)).ToArray():System.Array.Empty<int>();
            if(_cityReadWorks.TryGetValue(pair.Key,out var old)&&old.Zone==w.Zone&&old.HasZone==w.HasZone&&old.Slots.SequenceEqual(w.Slots)&&old.Filled.SequenceEqual(w.Filled)&&old.InboundReserved.SequenceEqual(reserved))continue;
            builder[pair.Key]=new(w.Zone,w.HasZone,ImmutableArray.CreateRange(w.Slots),ImmutableArray.CreateRange(w.Filled),ImmutableArray.CreateRange(reserved));
        }
        _cityReadWorks=builder.ToImmutable();
        return new PopulationReadView {TaxValue=GetTaxStatus(),Works=_cityReadWorks,StatValues=FreezeCityNumbers(_geometryEnabled?StatsManaged():Stats()),
            LaborValue=new(_laborEnabled,(double)_jobsPerWorker,(double)_commercialShare,_laborCacheLimit,_neighborInbound,_neighborOutbound,
                _laborEnabled?_laborInbound.Values.Sum(slots=>slots.Sum()):0,_laborEnabled?_laborOutbound.Count:0),
            DemandValues=FreezeCityNumbers(_geometryEnabled?DemandManaged():throw new System.InvalidOperationException("City read capture requires seeded geometry transport")),
            NextPersonValue=_nextPerson,NextHouseholdValue=_nextHousehold,ElapsedValue=_elapsedDays,BirthValue=_birthDay,
            RngSeedValue=unchecked((long)_rng.Seed),RngStateValue=unchecked((long)_rng.State)};
    }
    // Explicit idle/validation export only. Not called by a normal step.
    public D ExportCityCheckpoint()
    {
        if(_tickActive)throw new System.InvalidOperationException("Checkpoint requires an idle tick boundary");
        var d=ExportState();d["next_person"]=_nextPerson;d["next_household"]=_nextHousehold;
        d["elapsed_days"]=_elapsedDays;d["birth_day"]=_birthDay;
        d["rng_seed"]=unchecked((long)_rng.Seed);d["rng_state"]=unchecked((long)_rng.State);d["labor_policy"]=ExportLaborPolicyState();d["tax_policy"]=ExportTaxCheckpoint();return d;
    }
}
