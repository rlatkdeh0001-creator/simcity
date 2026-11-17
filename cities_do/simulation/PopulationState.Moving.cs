using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    internal readonly record struct HousingCondition(int Level,double Actual,double Target,double Infrastructure);
    private readonly Dictionary<long,int> _lowHousingDays=new();
    private Dictionary<long,HousingCondition> _housingConditions=new();
    private long _movingDay;
    private long _householdMoves,_departedHouseholds,_departedPeople;
    // Provisional normalized weights: jobs, commerce, power, water, road,
    // education, health, police, fire, park. No coordinate/centre heuristic.
    private double[] _fringeInfrastructureWeights={20,10,10,10,10,8,8,8,8,8};
    private double _fringeAccessMetres=1000,_workplaceMoveFraction=.2;
    private int _workplaceLowDays=3;
    internal double FringeInfrastructure(long home,double health,double police,double fire,double education,bool park,bool power,bool water,bool road)
    {
        double jobs=0,commerce=0;
        if(_laborEnabled&&_laborWorldPrepared&&_homes.ContainsKey(home))
        {
            int total=0,free=0;
            foreach(var candidate in LaborOrder(home))
            {
                if(candidate.Metres>_fringeAccessMetres)break;if(!_works.TryGetValue(candidate.Work,out var w))continue;
                total+=w.Slots.Sum();free+=Enumerable.Range(0,5).Sum(s=>Math.Max(0,w.Slots[s]-w.Filled[s]-InboundReserved(w.Id,s)));
                if(w.Zone=="commercial")commerce=1;
            }
            jobs=total>0?(double)free/total:0;
        }
        double[] values={jobs,commerce,power?1:0,water?1:0,road?1:0,education/10,health/10,police/10,fire/10,park?1:0};
        double result=0;for(int i=0;i<10;i++)result+=Math.Clamp(values[i],0,1)*_fringeInfrastructureWeights[i];
        return 100*result/_fringeInfrastructureWeights.Sum();
    }
    // HAPPINESS_KO: stage 1 <=20, higher stages strictly below 30/40/50/60.
    private static double Retention(int level)=>level==1?20:10+level*10;
    private bool AcceptsHouseholds(long home)=>!_taxEnabled||HomeCount(home)>0||!_housingConditions.TryGetValue(home,out var c)||c.Target>=Retention(c.Level);
    private bool AcceptsWorkers(long id)=>!_taxEnabled||!_housingConditions.TryGetValue(id,out var c)||c.Target>=Retention(c.Level)||(_works.TryGetValue(id,out var w)&&w.Filled.Sum()>0)||(_laborInbound.TryGetValue(id,out var inbound)&&inbound.Sum()>0);
    internal void ApplyHousingHappiness(long day,Dictionary<long,HousingCondition> conditions)
    {
        if(!_taxEnabled||day<=_movingDay)return;
        _movingDay=day;_housingConditions=conditions;
        var quotas=new Dictionary<long,int>();
        foreach(var pair in conditions)
        {
            var c=pair.Value;bool low=c.Level==1?c.Actual<=20:c.Actual<Retention(c.Level);
            _lowHousingDays[pair.Key]=low?_lowHousingDays.GetValueOrDefault(pair.Key)+1:0;
            if(_lowHousingDays[pair.Key]>=3)quotas[pair.Key]=(int)Math.Ceiling(HomeCount(pair.Key)*.2);
        }
        foreach(long id in _lowHousingDays.Keys.ToArray())if(!conditions.ContainsKey(id))_lowHousingDays.Remove(id);
        var ranked=conditions.OrderByDescending(p=>p.Value.Target).ThenBy(p=>p.Key).ToArray();
        bool changed=false;
        foreach(var h in _households.OrderBy(h=>h.Id).ToArray())
        {
            if(!conditions.TryGetValue(h.Home,out var current))continue;
            var f=Finance(h.Id);if(!f.Settled)continue;
            if(f.Income<=0)
            {
                if(!_poverty.TryGetValue(h.Id,out var poor))_poverty[h.Id]=poor=new();
                if(poor.Fringe)poor.Happiness+=Math.Clamp(current.Target-poor.Happiness,-5,5);else poor.Happiness=current.Actual;
                poor.Days=poor.Happiness<=20?poor.Days+1:0;
                if(poor.Days<3)continue;
                long fringe=-1;
                if(!poor.Fringe)foreach(var candidate in conditions.OrderBy(p=>p.Value.Infrastructure).ThenBy(p=>p.Key))
                    if(candidate.Key!=h.Home&&candidate.Value.Infrastructure<current.Infrastructure&&_homes.ContainsKey(candidate.Key)&&Vacant(candidate.Key)>0){fringe=candidate.Key;break;}
                if(fringe<0)Depart(h);
                else {Move(h,fringe);poor.Fringe=true;poor.Days=0;poor.Happiness=40;_householdMoves++;}
                changed=true;continue;
            }
            _poverty.Remove(h.Id);
            if(!quotas.TryGetValue(h.Home,out int quota)||quota<=0)continue;
            long target=-1;
            foreach(var candidate in ranked)
                if(candidate.Key!=h.Home&&candidate.Value.Target>current.Target&&_homes.ContainsKey(candidate.Key)&&Vacant(candidate.Key)>0&&AcceptsHouseholds(candidate.Key)){target=candidate.Key;break;}
            if(target<0)continue;
            quotas[h.Home]--;Move(h,target);_householdMoves++;changed=true;
        }
        changed|=MoveUnhappyWorkers(conditions);
        if(changed){MatchJobs();RebuildFinanceFactors();InvalidateManagedSnapshots();}
    }
    private bool MoveUnhappyWorkers(Dictionary<long,HousingCondition> conditions)
    {
        bool changed=false;
        var staff=_people.Where(p=>p.Work>=0).GroupBy(p=>p.Work).OrderBy(g=>g.Key).ToArray();
        foreach(var group in staff)
        {
            if(_lowHousingDays.GetValueOrDefault(group.Key)<_workplaceLowDays||!conditions.TryGetValue(group.Key,out var current))continue;
            int remaining=(int)Math.Ceiling(group.Count()*_workplaceMoveFraction);
            foreach(var p in group.OrderBy(p=>p.Id))
            {
                if(remaining==0)break;
                long home=_laborHouseholdHomes.GetValueOrDefault(p.Household,-1);
                long target=-1;int stage=-1;double best=double.PositiveInfinity;
                foreach(var candidate in _workOrder)
                {
                    if(candidate==p.Work||!conditions.TryGetValue(candidate,out var c)||c.Target<=current.Target||!AcceptsWorkers(candidate))continue;
                    var w=_works[candidate];double distance=_laborEnabled?GetLaborRoadDistance(home,candidate):_workRanks.GetValueOrDefault(candidate);
                    if(distance<0||distance>=best)continue;
                    for(int s=Math.Max(0,p.Education-1);s<=Math.Min(4,p.Education+1);s++)
                        if(w.Filled[s]+InboundReserved(candidate,s)<w.Slots[s]){target=candidate;stage=s;best=distance;break;}
                }
                if(target<0)continue;
                if(_works.TryGetValue(p.Work,out var old)&&p.Stage>=0)old.Filled[p.Stage]--;
                p.Work=target;p.Stage=stage;_works[target].Filled[stage]++;UpdateHappiness(p);remaining--;changed=true;
            }
        }
        return changed;
    }
    private sealed class PovertyState {internal int Days;internal bool Fringe;internal double Happiness=40;}
    private readonly Dictionary<long,PovertyState> _poverty=new();
    private void Depart(Household h)
    {
        Move(h,-1);
        if(_families.Remove(h.Id,out var family))
        {
            var ids=family.Select(p=>p.Id).ToHashSet();
            foreach(var p in family){if(_happinessGroups!=null)ApplyHappiness(p.Happiness,-1);_laborOutbound.Remove(p.Id);}
            _people.RemoveAll(p=>ids.Contains(p.Id));_departedPeople+=family.Count;
        }
        _households.Remove(h);_finances.Remove(h.Id);_poverty.Remove(h.Id);_happinessHomes.Remove(h.Id);_laborHouseholdHomes.Remove(h.Id);_departedHouseholds++;
        _cohortEnd=-1;
    }
    private D ExportMoving()
    {
        var lows=new D();foreach(var pair in _lowHousingDays.OrderBy(p=>p.Key))lows[pair.Key]=pair.Value;
        var conditions=new D();foreach(var pair in _housingConditions.OrderBy(p=>p.Key))conditions[pair.Key]=new D{["level"]=pair.Value.Level,["actual"]=pair.Value.Actual,["target"]=pair.Value.Target,["infrastructure"]=pair.Value.Infrastructure};
        var poverty=new D();foreach(var pair in _poverty.OrderBy(p=>p.Key))poverty[pair.Key]=new D{["days"]=pair.Value.Days,["fringe"]=pair.Value.Fringe,["happiness"]=pair.Value.Happiness};
        return new D{["day"]=_movingDay,["moves"]=_householdMoves,["departed_households"]=_departedHouseholds,["departed_people"]=_departedPeople,["lows"]=lows,["conditions"]=conditions,["poverty"]=poverty};
    }
    private sealed record MovingCheckpoint(long Day,long Moves,long Households,long People,Dictionary<long,int> Lows,Dictionary<long,HousingCondition> Conditions,Dictionary<long,PovertyState> Poverty);
    private static MovingCheckpoint ParseMoving(D d)
    {
        long Nonnegative(string key){long value=TaxInteger(d[key]);if(value<0)throw new ArgumentException("Negative moving counter");return value;}
        var lows=new Dictionary<long,int>();foreach(var key in d["lows"].AsGodotDictionary().Keys){long value=TaxInteger(d["lows"].AsGodotDictionary()[key]);if(value<0||value>int.MaxValue)throw new ArgumentException("Invalid moving streak");lows.Add(TaxInteger(key),(int)value);}
        var conditions=new Dictionary<long,HousingCondition>();var source=d["conditions"].AsGodotDictionary();foreach(var key in source.Keys)
        {var c=source[key].AsGodotDictionary();int level=checked((int)TaxInteger(c["level"]));TaxBand(level);double a=(double)TaxNumber(c["actual"]),t=(double)TaxNumber(c["target"]),i=(double)TaxNumber(c["infrastructure"]);if(a>100||t>100||i>100)throw new ArgumentException("Invalid housing condition");conditions.Add(TaxInteger(key),new(level,a,t,i));}
        var poverty=new Dictionary<long,PovertyState>();source=d["poverty"].AsGodotDictionary();foreach(var key in source.Keys)
        {var c=source[key].AsGodotDictionary();int days=checked((int)TaxInteger(c["days"]));double happiness=(double)TaxNumber(c["happiness"]);if(days<0||happiness>100||c["fringe"].VariantType!=Variant.Type.Bool)throw new ArgumentException("Invalid poverty state");poverty.Add(TaxInteger(key),new(){Days=days,Fringe=c["fringe"].AsBool(),Happiness=happiness});}
        return new(Nonnegative("day"),Nonnegative("moves"),Nonnegative("departed_households"),Nonnegative("departed_people"),lows,conditions,poverty);
    }
    private void RestoreMoving(MovingCheckpoint? state)
    {
        _movingDay=state?.Day??0;_householdMoves=state?.Moves??0;_departedHouseholds=state?.Households??0;_departedPeople=state?.People??0;
        _housingConditions=state?.Conditions??new();_lowHousingDays.Clear();_poverty.Clear();
        if(state==null)return;foreach(var pair in state.Lows)_lowHousingDays.Add(pair.Key,pair.Value);foreach(var pair in state.Poverty)_poverty.Add(pair.Key,pair.Value);
    }
    private D MovingSummary()
    {var d=new D{["last_day"]=_movingDay,["household_moves"]=_householdMoves,["departed_households"]=_departedHouseholds,["departed_people"]=_departedPeople};d.MakeReadOnly();return d;}
}
