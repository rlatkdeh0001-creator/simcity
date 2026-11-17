using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    private long _taxDay;
    private decimal _taxCarry,_taxAssessedTotal,_taxCollectedTotal;
    private decimal[] _taxLastBasis=new decimal[9],_taxLastAssessed=new decimal[9],_taxLastCollected=new decimal[9];
    private long _taxLastDays,_taxLastPosted;
    private decimal ResidentWage(Person p)=>_taxWages[p.Education is >=0 and <5?p.Education:throw new ArgumentException("Resident education must be 0..4")];
    // Explicit basis APIs: municipal household income includes external employment.
    // Business wage proxy is NOT profit/revenue; inbound education is unavailable,
    // so a reserved job-stage's configured wage is provisional until real workers exist.
    public double GetHouseholdTaxBasis(long household)
    {
        var h=_households.FirstOrDefault(h=>h.Id==household);
        if(h==null||h.Home<0||!_homes.ContainsKey(h.Home))return 0;
        return (double)(_families.TryGetValue(household,out var family)?family.Where(p=>p.Age>=_workingAge&&(p.Work>=0||LaborExternal(p))).Sum(ResidentWage):0);
    }
    public double GetBusinessTaxBasis(long workplace)
    {
        if(!_works.ContainsKey(workplace))return 0;
        decimal basis=_people.Where(p=>p.Work==workplace&&p.Age>=_workingAge).Sum(ResidentWage);
        for(int stage=0;stage<5;stage++)basis+=InboundReserved(workplace,stage)*_taxWages[stage];
        return (double)basis;
    }
    private decimal[] TaxBases(List<Building> source)
    {
        var buildings=source.ToDictionary(b=>b.Id);
        foreach(var b in buildings.Values)TaxBand(b.Level);
        var homes=_households.ToDictionary(h=>h.Id,h=>h.Home);var basis=new decimal[9];
        foreach(var p in _people)
        {
            if(p.Age<_workingAge)continue;
            bool local=p.Work>=0&&buildings.TryGetValue(p.Work,out var workplace)&&workplace.Zone!="residential"&&_works.ContainsKey(p.Work);
            if(!local&&!LaborExternal(p))continue;
            decimal wage=ResidentWage(p);
            if(homes.TryGetValue(p.Household,out var home)&&buildings.TryGetValue(home,out var h)&&h.Zone=="residential")basis[TaxBand(h.Level)]+=wage;
            if(local){var w=buildings[p.Work];basis[TaxZone(w.Zone)*3+TaxBand(w.Level)]+=wage;}
        }
        if(_laborEnabled)foreach(var pair in _laborInbound)
        {
            if(!buildings.TryGetValue(pair.Key,out var w)||w.Zone=="residential"||!_works.TryGetValue(pair.Key,out var work))continue;
            for(int stage=0;stage<5;stage++)basis[TaxZone(w.Zone)*3+TaxBand(w.Level)]+=Math.Min(pair.Value[stage],Math.Max(0,work.Slots[stage]-work.Filled[stage]))*_taxWages[stage];
        }
        return basis;
    }
    // Call with floor(game absolute days) at the same worker boundary as upkeep.
    // Multi-day jumps use the supplied boundary population/rates for each missing
    // day; callers needing historical changes must step each actual day boundary.
    // Only this returned posted delta may be credited once to municipal funds.
    public D AssessTaxesManaged(long day){RequireGeometry();return AssessTaxBoundary(day,_geometry);}
    public D AssessTaxesThroughDay(long day,long[] buildings)=>AssessTaxBoundary(day,Buildings(buildings));
    private D AssessTaxBoundary(long day,List<Building> buildings)
    {
        if(day<0)throw new ArgumentOutOfRangeException(nameof(day));
        if(day<=_taxDay)return TaxReport(new decimal[9],new decimal[9],new decimal[9],0,0);
        long days=day-_taxDay;
        var basis=_taxEnabled?TaxBases(buildings):new decimal[9];var assessed=new decimal[9];var collected=new decimal[9];
        for(int i=0;i<9;i++)assessed[i]=basis[i]*_taxRates[i]/100m*days;
        // T1 full collection policy, deliberately separate from assessment. T3
        // replaces this allocation with paid amounts; no household cash or arrears.
        System.Array.Copy(assessed,collected,9);
        decimal collectedSum=collected.Sum(),sum=_taxCarry+collectedSum;
        long posted=checked((long)decimal.Floor(sum));
        decimal assessedTotal=_taxAssessedTotal+assessed.Sum(),collectedTotal=_taxCollectedTotal+collectedSum;
        _taxCarry=sum-posted;_taxDay=day;_taxAssessedTotal=assessedTotal;_taxCollectedTotal=collectedTotal;
        _taxLastBasis=basis;_taxLastAssessed=assessed;_taxLastCollected=collected;_taxLastDays=days;_taxLastPosted=posted;
        return TaxReport(basis,assessed,collected,days,posted);
    }
    private D TaxReport(decimal[] basis,decimal[] assessed,decimal[] collected,long days,long posted)
    {
        var cells=new A();var zones=new D();
        for(int z=0;z<3;z++)
        {
            decimal a=0,c=0;
            for(int band=0;band<3;band++){int i=z*3+band;var cell=new D{["zone"]=Zones[z],["band"]=band,["rate"]=_taxRates[i],["basis"]=(double)basis[i],["assessed"]=(double)assessed[i],["collected"]=(double)collected[i]};cell.MakeReadOnly();cells.Add(cell);a+=assessed[i];c+=collected[i];}
            var zone=new D{["assessed"]=(double)a,["collected"]=(double)c};zone.MakeReadOnly();zones[Zones[z]]=zone;
        }
        cells.MakeReadOnly();zones.MakeReadOnly();
        var result=new D{["enabled"]=_taxEnabled,["last_day"]=_taxDay,["days"]=days,["posted"]=posted,["carry"]=(double)_taxCarry,
            ["assessed"]=(double)assessed.Sum(),["collected"]=(double)collected.Sum(),["assessed_total"]=(double)_taxAssessedTotal,["collected_total"]=(double)_taxCollectedTotal,
            ["cells"]=cells,["zones"]=zones,["policy"]=GetTaxPolicy(),["inbound_basis"]="reserved_job_stage_wage_proxy"};result.MakeReadOnly();return result;
    }
    public D GetTaxStatus()=>TaxReport(_taxLastBasis,_taxLastAssessed,_taxLastCollected,_taxLastDays,_taxLastPosted);
    private static A TaxExact(decimal[] values){var a=new A();foreach(var n in values)a.Add(n.ToString(CultureInfo.InvariantCulture));return a;}
    public D ExportTaxCheckpoint()=>new(){["version"]=1,["policy"]=GetTaxPolicy(),["last_day"]=_taxDay,["carry"]=_taxCarry.ToString(CultureInfo.InvariantCulture),
        ["assessed_total"]=_taxAssessedTotal.ToString(CultureInfo.InvariantCulture),["collected_total"]=_taxCollectedTotal.ToString(CultureInfo.InvariantCulture),
        ["last_basis"]=TaxExact(_taxLastBasis),["last_assessed"]=TaxExact(_taxLastAssessed),["last_collected"]=TaxExact(_taxLastCollected),["last_days"]=_taxLastDays,["last_posted"]=_taxLastPosted};
    private static decimal ParseTaxExact(Variant value)
    {
        if(value.VariantType!=Variant.Type.String||!decimal.TryParse(value.AsString(),NumberStyles.Number,CultureInfo.InvariantCulture,out var n)||n<0)throw new ArgumentException("Invalid exact tax amount");return n;
    }
    private static decimal[] ParseTaxAmounts(Variant value)
    {var a=value.AsGodotArray();if(a.Count!=9)throw new ArgumentException("Nine tax cells required");return a.Select(ParseTaxExact).ToArray();}
    private static long TaxInteger(Variant value)
    {if(value.VariantType!=Variant.Type.Int)throw new ArgumentException("Tax checkpoint integer required");return value.AsInt64();}
    public void ImportTaxCheckpoint(D state)
    {
        if(TaxInteger(state["version"])!=1)throw new ArgumentException("Unsupported tax checkpoint version");
        long day=TaxInteger(state["last_day"]),days=TaxInteger(state["last_days"]),posted=TaxInteger(state["last_posted"]);
        decimal carry=ParseTaxExact(state["carry"]),assessed=ParseTaxExact(state["assessed_total"]),collected=ParseTaxExact(state["collected_total"]);
        var basis=ParseTaxAmounts(state["last_basis"]);var lastAssessed=ParseTaxAmounts(state["last_assessed"]);var lastCollected=ParseTaxAmounts(state["last_collected"]);
        if(day<0||days<0||days>day||posted<0||carry>=1||carry!=collected-decimal.Floor(collected)||collected>assessed||lastAssessed.Sum()>assessed||lastCollected.Sum()>collected)throw new ArgumentException("Invalid tax checkpoint totals");
        // Config validation is atomic and is the last fallible operation.
        ConfigureTaxPolicy(state["policy"].AsGodotDictionary());
        _taxDay=day;_taxCarry=carry;_taxAssessedTotal=assessed;_taxCollectedTotal=collected;_taxLastBasis=basis;_taxLastAssessed=lastAssessed;_taxLastCollected=lastCollected;_taxLastDays=days;_taxLastPosted=posted;
    }
}
