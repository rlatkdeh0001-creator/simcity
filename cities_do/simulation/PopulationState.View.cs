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
            if(_cityReadWorks.TryGetValue(pair.Key,out var old)&&old.Zone==w.Zone&&old.HasZone==w.HasZone&&old.Slots.SequenceEqual(w.Slots)&&old.Filled.SequenceEqual(w.Filled))continue;
            builder[pair.Key]=new(w.Zone,w.HasZone,ImmutableArray.CreateRange(w.Slots),ImmutableArray.CreateRange(w.Filled));
        }
        _cityReadWorks=builder.ToImmutable();
        return new PopulationReadView {Works=_cityReadWorks,StatValues=FreezeCityNumbers(_geometryEnabled?StatsManaged():Stats()),
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
        d["rng_seed"]=unchecked((long)_rng.Seed);d["rng_state"]=unchecked((long)_rng.State);return d;
    }
}
