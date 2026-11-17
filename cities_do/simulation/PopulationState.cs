using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using A = Godot.Collections.Array;
using D = Godot.Collections.Dictionary;

/// <summary>Managed authoritative state; Godot collections are used only at the bridge boundary.</summary>
public partial class PopulationState : RefCounted
{
    private sealed class Person { public long Id, Household, Work=-1; public int Education, Stage=-1; public double Age; public string Origin=""; public HappinessMembership Happiness=new(-1,-1,false,0); }
    private sealed class Household { public long Id, Home; }
    private sealed class Work { public long Id; public string Zone=""; public bool HasZone=true; public int[] Slots=new int[5], Filled=new int[5]; }
    private readonly record struct Building(long Id,string Zone,int Size,int Level);
    private readonly record struct Contribution(string Zone,int Units);
    private readonly RandomNumberGenerator _rng=new();
    private readonly List<Person> _people=new();
    private readonly List<Household> _households=new();
    private readonly Dictionary<long,List<Person>> _families=new();
    private readonly Dictionary<long,Work> _works=new();
    // Explicit order lists: .NET Dictionary free-slot reuse must not change Godot insertion priority.
    private readonly List<long> _workOrder=new(), _homeOrder=new();
    private readonly Dictionary<long,int> _homes=new(), _homeCounts=new(), _workRanks=new();
    private readonly Dictionary<long,Contribution> _buildingStates=new();
    private readonly Dictionary<string,int> _counts=new();
    private readonly List<long>[] _vacancyLists=Enumerable.Range(0,5).Select(_=>new List<long>()).ToArray();
    private readonly int[] _vacancyCursor=new int[5];
    private long _nextPerson=1, _nextHousehold=1;
    private double _elapsedDays;
    private int _birthDay, _fullScans, _vacancies, _jobCount, _cohortEnd=-1;
    private bool _tickActive, _demandValid, _demandPrepared, _deferMatching, _reconciliationValid, _housingNeedsReconcile;
    private int _unitsPerLot, _maxMembers, _immigrantAdults, _initialHousing;
    private double _workingAge, _commercialRatio, _industrialRatio, _birthProbability;
    private int[] _commercial=new int[5], _industrial=new int[5];
    private double[] _weights=new double[5], _educationMinAges=new double[5];
    public string Echo(string value)=>value;
    public void Initialize(long seed){_rng.Seed=unchecked((ulong)(seed^0x71294));InvalidateManagedSnapshots();}
    public RandomNumberGenerator GetRng()=>_rng;
    public double ValidationRandom()=>_rng.Randf();
    public bool IsTickActive()=>_tickActive;
    public bool NeedsDemandBuildings()=>!_tickActive||(!_demandValid&&!_demandPrepared);
    public int GetDemandScans()=>_fullScans;
    public long GetNextPerson()=>_nextPerson;
    public void SetNextPerson(long value){_nextPerson=value;InvalidateManagedSnapshots();}
    public long GetNextHousehold()=>_nextHousehold;
    public void SetNextHousehold(long value){_nextHousehold=value;InvalidateManagedSnapshots();}
    public double GetElapsedDays()=>_elapsedDays;
    public void SetElapsedDays(double value){_elapsedDays=value;InvalidateManagedSnapshots();}
    public int GetBirthDay()=>_birthDay;
    public void SetBirthDay(int value){_birthDay=value;InvalidateManagedSnapshots();}
    private static int Int(D d,string key)=>(int)d[key].AsInt64();
    private static long Id(D d,string key)=>d[key].AsInt64();
    private static double Num(D d,string key)=>d[key].AsDouble();
    private static string Str(D d,string key)=>d[key].AsString();
    private static int[] Ints(Variant value)=>value.AsGodotArray().Select(v=>(int)v.AsInt64()).ToArray();
    private static double[] Numbers(Variant value)=>value.AsGodotArray().Select(v=>v.AsDouble()).ToArray();
    public void Configure(D c)
    {
        // Configuration can change in compatibility fixtures without a building edit.
        _reconciliationValid=false;_demandValid=false;_demandPrepared=false;InvalidateHappiness();InvalidateManagedSnapshots();
        _unitsPerLot=Int(c,"households_per_2x2"); _maxMembers=Int(c,"household_max_members");
        _immigrantAdults=Int(c,"immigrant_adults_per_household"); _initialHousing=Int(c,"initial_housing_target");
        _workingAge=Num(c,"working_age_years"); _commercialRatio=Num(c,"residents_per_commercial"); _industrialRatio=Num(c,"residents_per_industrial");
        _birthProbability=Num(c,"birth_probability_per_household_day"); _commercial=Ints(c["commercial_jobs"]); _industrial=Ints(c["industrial_jobs"]);
        _weights=Numbers(c["immigrant_education_weights"]); _educationMinAges=Numbers(c["education_min_ages"]);
    }
    private static readonly string[] Zones={"residential","commercial","industrial"};
    private static List<Building> Buildings(long[] values)
    {
        if(values.Length%4!=0)throw new ArgumentException("Building records require id, zone, size and level");
        var result=new List<Building>(values.Length/4);
        for(int i=0;i<values.Length;i+=4)
        {
            if(values[i+1]<0||values[i+1]>=Zones.Length)throw new ArgumentException("Unknown building zone");
            result.Add(new(values[i],Zones[(int)values[i+1]],checked((int)values[i+2]),checked((int)values[i+3])));
        }
        return result;
    }
    private int Units(Building b)=>b.Size*b.Size/4*Math.Max(1,b.Level)*_unitsPerLot;
    public int HousingUnits(D b)=>Int(b,"size")*Int(b,"size")/4*Math.Max(1,Int(b,"level"))*_unitsPerLot;
    private int[] Slots(Building b)=>(b.Zone=="commercial"?_commercial:_industrial).Select(n=>n*(b.Size*b.Size/4)*Math.Max(1,b.Level)).ToArray();
    public A BuildingSlots(D b)=>ToArray(Slots(new(0,Str(b,"zone"),Int(b,"size"),Int(b,"level"))));
    public void BeginTick() { _tickActive=true; _demandValid=false; _demandPrepared=false; }
    public void EndTick() { _tickActive=false; _demandValid=false; _demandPrepared=false;RefreshManagedSnapshots(); }
    public int RandomEducation()
    {
        double total=0; foreach(double w in _weights) total+=w;
        double roll=_rng.Randf()*total;
        for(int stage=0;stage<5;stage++) { roll-=_weights[stage]; if(roll<0)return stage; }
        return 4;
    }
    private Person Add(long household,int education,double age,string origin)
    {
        InvalidateManagedSnapshots();
        var p=new Person {Id=_nextPerson++,Household=household,Education=education,Age=age,Origin=origin}; _people.Add(p);
        if(!_families.TryGetValue(household,out var family)) _families[household]=family=new();
        family.Add(p);UpdateHappiness(p);return p;
    }
    public D AddPerson(long household,int education,double age,string origin)=>PersonState(Add(household,education,age,origin));
    private Person? BirthInternal(long household)
    {
        if(!_households.Any(h=>h.Id==household))return null;
        _families.TryGetValue(household,out var family);
        if(family==null||family.Count>=_maxMembers||!family.Any(p=>p.Age>=18))return null;
        return Add(household,0,0,"local");
    }
    public D Birth(long household) {var p=BirthInternal(household);return p==null?new D():PersonState(p);}
    public bool CompleteEducation(long id,int stage)
    {
        if(stage<1||stage>4)return false;
        foreach(var p in _people)if(p.Id==id&&p.Education==stage-1&&p.Age>=_educationMinAges[stage]) {p.Education=stage;InvalidateManagedSnapshots();return true;}
        return false;
    }
    private int HomeCount(long id)=>_homeCounts.GetValueOrDefault(id);
    private int Vacant(long id)=>Math.Max(0,_homes[id]-HomeCount(id));
    private void IndexHouseholds() { _homeCounts.Clear(); foreach(var h in _households)_homeCounts[h.Home]=HomeCount(h.Home)+1; }
    private void Move(Household h,long id)
    {
        long old=h.Home;if(old==id)return;
        ReleaseLaborHomeJobs(h);
        bool counting=_reconciliationValid||_demandValid||_demandPrepared;
        if(counting&&_homes.ContainsKey(old))_vacancies-=Vacant(old);
        if(old!=-1)_homeCounts[old]=Math.Max(0,HomeCount(old)-1);
        if(counting&&_homes.ContainsKey(old))_vacancies+=Vacant(old);
        if(counting&&_homes.ContainsKey(id))_vacancies-=Vacant(id);
        h.Home=id;_laborHouseholdHomes[h.Id]=id;if(id!=-1)_homeCounts[id]=HomeCount(id)+1;
        if(counting&&_homes.ContainsKey(id))_vacancies+=Vacant(id);
        MoveHappiness(h);
    }
    private void Rehouse()
    {
        var available=_homeOrder.Where(id=>Vacant(id)>0).ToArray();int cursor=0;
        foreach(var h in _households) {if(h.Home!=-1)continue;while(cursor<available.Length&&Vacant(available[cursor])==0)cursor++;if(cursor==available.Length)break;Move(h,available[cursor]);}
    }
    private void ResetCounts() {_counts.Clear();_counts["residential"]=0;_counts["commercial"]=0;_counts["industrial"]=0;_vacancies=0;_jobCount=0;_buildingStates.Clear();ResetLaborInventory();}
    // True asks the facade to call its overridable public match_jobs once.
    public bool SyncPacked(long[] values)=>SyncInternal(Buildings(values));
    private bool SyncInternal(List<Building> buildings)
    {
        InvalidateManagedSnapshots();
        bool sameTick=_tickActive&&(_demandValid||_demandPrepared);
        if(_reconciliationValid)
        {
            // BeginTick invalidates demand query lifetime, not building reconciliation.
            // Keep the public full match at the original boundary for cohort priority.
            SyncChanges(buildings,sameTick);if(_tickActive&&!_demandValid)_demandPrepared=true;
            return !sameTick&&!_deferMatching;
        }
        _demandValid=false;_homes.Clear();_homeOrder.Clear();_works.Clear();_workOrder.Clear();_demandPrepared=_tickActive;
        ResetCounts();
        foreach(var b in buildings)
        {
            CountLaborBuilding(b);
            _buildingStates[b.Id]=new(b.Zone,b.Zone=="residential"?Units(b):0);_counts[b.Zone]++;
            if(b.Zone=="residential") {_homes[b.Id]=Units(b);_homeOrder.Add(b.Id);}
            else {var slots=Slots(b);_works[b.Id]=new Work {Id=b.Id,Slots=slots,Zone=b.Zone};_workOrder.Add(b.Id);foreach(int n in slots)_jobCount+=n;}
        }
        foreach(var h in _households)if(!_homes.ContainsKey(h.Home))Move(h,-1);
        IndexHouseholds();_vacancies=0;foreach(long id in _homeOrder)_vacancies+=Vacant(id);_reconciliationValid=true;
        Rehouse();_housingNeedsReconcile=false;return !_deferMatching;
    }
    private void RemoveContribution(long id,Contribution old)
    {
        _counts[old.Zone]--;
        if(old.Zone=="residential") {_vacancies-=Math.Max(0,old.Units-HomeCount(id));_homes.Remove(id);_homeOrder.Remove(id);_housingNeedsReconcile=true;}
    }
    private void ReconcileWork(long id)
    {
        _works.TryGetValue(id,out var work);if(work!=null)work.Filled=new int[5];
        foreach(var p in _people)
        {
            if(p.Work!=id)continue;int stage=p.Stage;
            if(work!=null&&stage>=0&&stage<5&&p.Age>=_workingAge&&Math.Abs(p.Education-stage)<=1&&work.Filled[stage]<work.Slots[stage])work.Filled[stage]++;
            else {p.Work=-1;p.Stage=-1;UpdateHappiness(p);}
        }
    }
    private void SyncChanges(List<Building> buildings,bool matchChanges)
    {
        var seen=new HashSet<long>();bool jobsChanged=false;ResetLaborInventory();
        foreach(var b in buildings)
        {
            CountLaborBuilding(b);
            seen.Add(b.Id);var state=new Contribution(b.Zone,b.Zone=="residential"?Units(b):0);bool had=_buildingStates.TryGetValue(b.Id,out var old);
            if(!had||state!=old)
            {
                if(had)RemoveContribution(b.Id,old);_counts[b.Zone]++;
                if(b.Zone=="residential") {if(!_homes.ContainsKey(b.Id))_homeOrder.Add(b.Id);_homes[b.Id]=state.Units;_vacancies+=Math.Max(0,state.Units-HomeCount(b.Id));_housingNeedsReconcile=true;}
                _buildingStates[b.Id]=state;
            }
            if(b.Zone!="residential")
            {
                bool previous=_works.TryGetValue(b.Id,out var work);
                // Compare scalar capacities without allocating unchanged slot arrays.
                int scale=b.Size*b.Size/4*Math.Max(1,b.Level);var policy=b.Zone=="commercial"?_commercial:_industrial;
                bool unchanged=previous;for(int stage=0;stage<5&&unchanged;stage++)unchanged=work!.Slots[stage]==policy[stage]*scale;
                if(!unchanged)
                {
                    var slots=Slots(b);
                    if(previous)foreach(int n in work!.Slots)_jobCount-=n;
                    foreach(int n in slots)_jobCount+=n;if(!previous)_workOrder.Add(b.Id);
                    _works[b.Id]=new Work {Id=b.Id,Slots=slots,Zone=b.Zone};ReconcileWork(b.Id);jobsChanged=true;
                }
                else {work!.Zone=b.Zone;work.HasZone=true;}
            }
        }
        foreach(long id in _buildingStates.Keys.ToArray())if(!seen.Contains(id)) {RemoveContribution(id,_buildingStates[id]);_buildingStates.Remove(id);}
        foreach(long id in _workOrder.ToArray())if(!seen.Contains(id)||_buildingStates[id].Zone=="residential")
        {foreach(int n in _works[id].Slots)_jobCount-=n;_works.Remove(id);_workOrder.Remove(id);ReconcileWork(id);jobsChanged=true;}
        // Input order is the legacy rebuild's insertion priority, including reordered fixtures.
        _homeOrder.Clear();_workOrder.Clear();foreach(var b in buildings)if(b.Zone=="residential")_homeOrder.Add(b.Id);else _workOrder.Add(b.Id);
        // Without a housing edit the previous reconciliation exhausted every vacancy
        // or every unhoused household. Births/job changes cannot alter that result.
        if(_housingNeedsReconcile)
        {
            foreach(var h in _households)if(!_homes.ContainsKey(h.Home))Move(h,-1);
            Rehouse();_housingNeedsReconcile=false;
        }
        if(jobsChanged&&matchChanges&&!_deferMatching) {PrepareLaborCommutersForMatching();IndexVacancies();FillWaiting(0,_people.Count);}
    }
    private void IndexVacancies()
    {
        _laborCursors.Clear();
        foreach(var list in _vacancyLists)list.Clear();System.Array.Clear(_vacancyCursor);_workRanks.Clear();
        for(int order=0;order<_workOrder.Count;order++) {long id=_workOrder[order];var w=_works[id];_workRanks[id]=order;for(int stage=0;stage<5;stage++)if(w.Filled[stage]<w.Slots[stage])_vacancyLists[stage].Add(id);}
    }
    private long Candidate(int stage)
    {
        if(stage<0||stage>=5)return -1;var list=_vacancyLists[stage];int cursor=_vacancyCursor[stage];
        while(cursor<list.Count) {var work=_works[list[cursor]];if(work.Filled[stage]<work.Slots[stage])break;cursor++;}
        _vacancyCursor[stage]=cursor;return cursor<list.Count?list[cursor]:-1;
    }
    private void FillWaiting(int first,int last)
    {
        if(_laborEnabled){FillRoadWaiting(first,last);return;}
        var waiting=new List<Person>();for(int i=first;i<last;i++)if(_people[i].Work==-1&&_people[i].Age>=_workingAge)waiting.Add(_people[i]);
        for(int distance=0;distance<=1;distance++)foreach(var p in waiting)
        {
            if(p.Work!=-1)continue;int lower=p.Education-distance,upper=p.Education+distance;long id=Candidate(lower);int stage=lower;
            if(distance==1) {long other=Candidate(upper);if(other!=-1&&(id==-1||_workRanks[other]<_workRanks[id])) {id=other;stage=upper;}}
            if(id!=-1) {p.Work=id;p.Stage=stage;_works[id].Filled[stage]++;UpdateHappiness(p);}
        }
    }
    public void MatchJobs()
    {
        RequireLaborWorld();
        InvalidateManagedSnapshots();
        foreach(long id in _workOrder)System.Array.Clear(_works[id].Filled);
        // A commute outage is not job loss. Keep eligible incumbents until their
        // actual position disappears; moving home explicitly releases jobs in Move.
        foreach(var p in _people)
        {
            _works.TryGetValue(p.Work,out var work);int stage=p.Stage;
            if(p.Age>=_workingAge&&stage>=0&&stage<5&&Math.Abs(p.Education-stage)<=1&&work!=null&&work.Filled[stage]<work.Slots[stage])work.Filled[stage]++;
            else {bool employed=p.Work!=-1;p.Work=-1;p.Stage=-1;if(employed)UpdateHappiness(p);}
        }
        PrepareLaborCommutersForMatching();IndexVacancies();int boundary=_cohortEnd>=0?Math.Min(_cohortEnd,_people.Count):_people.Count;
        FillWaiting(0,boundary);if(boundary<_people.Count)FillWaiting(boundary,_people.Count);_cohortEnd=-1;
    }
    public void AdvancePacked(double seconds,long[] values)
    {
        if(!double.IsFinite(seconds)||seconds<=0)return;
        // Legacy packed calls age before parsing (including malformed-input failure
        // ordering); managed calls share the same remaining algorithm without parsing.
        AdvanceAges(seconds);AdvanceInternal(seconds,Buildings(values),false);
    }
    private void AdvanceAges(double seconds)
    {
        InvalidateManagedSnapshots();
        _elapsedDays+=seconds/86400.0;foreach(var p in _people) {double old=p.Age;p.Age+=seconds/(86400.0*12);AdvanceHappinessAge(p,old);}
    }
    private void AdvanceInternal(double seconds,List<Building> buildings,bool advanceAges=true)
    {
        if(advanceAges)AdvanceAges(seconds);
        _cohortEnd=_people.Count;_deferMatching=true;SyncInternal(buildings);_deferMatching=false;
        if(!_households.Any(h=>h.Home==-1))foreach(var b in buildings)
        {
            if(b.Zone!="residential"||HomeCount(b.Id)>=_homes[b.Id])continue;
            var h=new Household {Id=_nextHousehold++,Home=-1};_households.Add(h);Move(h,b.Id);
            for(int i=0;i<_immigrantAdults;i++)Add(h.Id,RandomEducation(),_rng.RandfRange(20,50),"immigrant");break;
        }
        while(_birthDay<(int)Math.Floor(_elapsedDays)) {_birthDay++;foreach(var h in _households)if(h.Home!=-1&&_rng.Randf()<_birthProbability)BirthInternal(h.Id);}
    }
    private void CalculateDemand(long[] values)
    {
        // Preserve the packed prepared fast path and its scan-counter semantics.
        if(_demandPrepared){_fullScans++;_demandValid=true;_demandPrepared=false;return;}
        CalculateDemand(Buildings(values));
    }
    private void CalculateDemand(List<Building> buildings)
    {
        _fullScans++;if(_demandPrepared) {_demandValid=true;_demandPrepared=false;return;}
        // An independent demand query may see housing edits before SyncPacked does.
        _housingNeedsReconcile=true;ResetCounts();IndexHouseholds();_homes.Clear();_homeOrder.Clear();
        foreach(var b in buildings) {CountLaborBuilding(b);var state=new Contribution(b.Zone,b.Zone=="residential"?Units(b):0);_buildingStates[b.Id]=state;_counts[b.Zone]++;if(b.Zone=="residential") {_homes[b.Id]=state.Units;_homeOrder.Add(b.Id);_vacancies+=Math.Max(0,state.Units-HomeCount(b.Id));}}
        foreach(long id in _workOrder)foreach(int n in _works[id].Slots)_jobCount+=n;_demandValid=true;
    }
    public D Demand(long[] buildings)
    {
        if(!_tickActive||!_demandValid)CalculateDemand(buildings);return DemandResult();
    }
    private D DemandResult()
    {
        if(_laborEnabled)return LaborDemandResult();
        int target=Math.Max(_initialHousing,(int)Math.Ceiling(_jobCount/4.0));
        return new D {["residential"]=Math.Max(0,target-_households.Count-_vacancies),["commercial"]=Math.Max(0,(int)Math.Ceiling(_people.Count/_commercialRatio)-_counts["commercial"]),["industrial"]=Math.Max(0,(int)Math.Ceiling(_people.Count/_industrialRatio)-_counts["industrial"])};
    }
    public D WorkplaceInfo(long id)
    {
        if(!_works.TryGetValue(id,out var w))return new D();
        var state=new D {["id"]=id,["slots"]=ToArray(w.Slots),["filled"]=ToArray(w.Filled)};
        if(_laborEnabled){state["inbound_reserved"]=ToArray(Enumerable.Range(0,5).Select(stage=>InboundReserved(id,stage)).ToArray());state["free_slots"]=ToArray(FreeLaborSlots(w));}
        if(w.HasZone)state["zone"]=w.Zone;
        return state;
    }
    public D Stats()
    {
        int eligible=0,employed=0;foreach(var p in _people) {if(p.Age>=_workingAge)eligible++;if(p.Work!=-1||LaborExternal(p))employed++;}
        return new D {["population"]=_people.Count,["households"]=_households.Count,["employed"]=employed,["unemployed"]=eligible-employed};
    }
    private static D PersonState(Person p)=>new() {["id"]=p.Id,["household_id"]=p.Household,["education"]=p.Education,["age_years"]=p.Age,["origin"]=p.Origin,["workplace_id"]=p.Work,["job_stage"]=p.Stage};
    private static A ToArray(int[] values) {var result=new A();foreach(int n in values)result.Add(n);return result;}
    public D ExportState()
    {
        var people=new A();foreach(var p in _people)people.Add(PersonState(p));var households=new A();foreach(var h in _households)households.Add(new D {["id"]=h.Id,["home_id"]=h.Home});
        var works=new D();foreach(long id in _workOrder) {var w=_works[id];var state=new D {["id"]=id,["slots"]=ToArray(w.Slots),["filled"]=ToArray(w.Filled)};if(w.HasZone)state["zone"]=w.Zone;works[id]=state;}
        return new D {["people"]=people,["households"]=households,["workplaces"]=works};
    }
    public void ImportState(A people,A households,D works)
    {
        _people.Clear();_households.Clear();_families.Clear();_works.Clear();_workOrder.Clear();
        foreach(var value in people)
        {
            var d=value.AsGodotDictionary();var p=new Person {Id=Id(d,"id"),Household=Id(d,"household_id"),Education=Int(d,"education"),Age=Num(d,"age_years"),Origin=Str(d,"origin"),Work=Id(d,"workplace_id"),Stage=Int(d,"job_stage")};
            _people.Add(p);if(!_families.TryGetValue(p.Household,out var family))_families[p.Household]=family=new();family.Add(p);
        }
        foreach(var value in households) {var d=value.AsGodotDictionary();_households.Add(new Household {Id=Id(d,"id"),Home=Id(d,"home_id")});}
        foreach(var key in works.Keys) {long id=key.AsInt64();var d=works[key].AsGodotDictionary();_works[id]=new Work {Id=id,Zone=d.TryGetValue("zone",out var zone)?zone.AsString():"",HasZone=d.ContainsKey("zone"),Slots=Ints(d["slots"]),Filled=Ints(d["filled"])};_workOrder.Add(id);}
        _reconciliationValid=false;_demandValid=false;_demandPrepared=false;InvalidateHappiness();InvalidateManagedSnapshots();InvalidateLaborImport();IndexHouseholds();IndexVacancies();
    }
}
