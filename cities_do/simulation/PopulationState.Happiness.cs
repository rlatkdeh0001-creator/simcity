using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.Immutable;

// Mutable aggregates preserve the legacy oracle API. Frozen copies reject all writes,
// including indexed student writes, and are the only values placed in snapshot roots.
internal sealed class HappinessPeople
{
    internal sealed class StudentCounts:IReadOnlyList<int>
    {
        private readonly int[] _values;
        private readonly bool _frozen;
        internal StudentCounts(int[] values,bool frozen){_values=values;_frozen=frozen;}
        public int Count=>_values.Length;
        public int this[int index]
        {get=>_values[index];set {if(_frozen)throw new InvalidOperationException("Immutable happiness snapshot");_values[index]=value;}}
        public IEnumerator<int> GetEnumerator()=>((IEnumerable<int>)_values).GetEnumerator();
        IEnumerator IEnumerable.GetEnumerator()=>GetEnumerator();
    }
    private readonly bool _frozen;
    private int _count,_eligible,_employed;
    private void RequireMutable(){if(_frozen)throw new InvalidOperationException("Immutable happiness snapshot");}
    internal int Count {get=>_count;set {RequireMutable();_count=value;}}
    internal int Eligible {get=>_eligible;set {RequireMutable();_eligible=value;}}
    internal int Employed {get=>_employed;set {RequireMutable();_employed=value;}}
    internal StudentCounts Students {get;}
    internal HappinessPeople(){Students=new(new int[4],false);}
    internal HappinessPeople(int count,int eligible,int employed,ImmutableArray<int> students)
    {
        _count=count;_eligible=eligible;_employed=employed;_frozen=true;
        var owned=new int[4];students.CopyTo(owned);Students=new(owned,true);
    }
    internal HappinessPeople Freeze()=>new(Count,Eligible,Employed,ImmutableArray.CreateRange(Students));
}
public partial class PopulationState
{
    // One membership per person, including both roles even when home == workplace.
    // Aggregate objects are managed-only and read-only to HappinessCore consumers.
    // The dictionary is updated in place: identity is not a population generation.
    private readonly record struct HappinessMembership(long Home,long Work,bool Eligible,int Students);
    private Dictionary<long,HappinessPeople>? _happinessGroups;
    private ImmutableDictionary<long,HappinessPeople> _happinessSnapshot=ImmutableDictionary<long,HappinessPeople>.Empty;
    private readonly HashSet<long> _dirtyHappinessGroups=new();
    private readonly Dictionary<long,long> _happinessHomes=new();
    private void InvalidateHappiness()
    {_happinessGroups=null;_happinessHomes.Clear();_dirtyHappinessGroups.Clear();_happinessSnapshot=ImmutableDictionary<long,HappinessPeople>.Empty;}
    private int HappinessStudents(double age)
    {
        int mask=age>=6&&age<_educationMinAges[1]?1:0;
        for(int stage=1;stage<4;stage++)if(age>=_educationMinAges[stage]&&age<_educationMinAges[stage+1])mask|=1<<stage;
        return mask;
    }
    private HappinessMembership Membership(Person p)=>new(_happinessHomes.GetValueOrDefault(p.Household,-1),p.Work,p.Age>=_workingAge,HappinessStudents(p.Age));
    private void ApplyHappiness(HappinessMembership member,int delta)
    {
        void Apply(long id)
        {
            if(id<0)return;
            if(!_happinessGroups!.TryGetValue(id,out var group))_happinessGroups[id]=group=new();
            group.Count+=delta;if(member.Eligible)group.Eligible+=delta;if(member.Work>=0)group.Employed+=delta;
            for(int stage=0;stage<4;stage++)if((member.Students&(1<<stage))!=0)group.Students[stage]+=delta;
            if(group.Count==0)_happinessGroups.Remove(id);
            _dirtyHappinessGroups.Add(id);
        }
        Apply(member.Home);Apply(member.Work);
    }
    private void UpdateHappiness(Person p)
    {
        if(_happinessGroups==null)return;
        var next=Membership(p);if(next==p.Happiness)return;
        ApplyHappiness(p.Happiness,-1);p.Happiness=next;ApplyHappiness(next,1);
    }
    private void MoveHappiness(Household household)
    {
        if(_happinessGroups==null)return;
        _happinessHomes[household.Id]=household.Home;
        if(_families.TryGetValue(household.Id,out var family))foreach(var p in family)UpdateHappiness(p);
    }
    private void AdvanceHappinessAge(Person p,double oldAge)
    {
        if(_happinessGroups==null)return;
        // AdvancePacked already traverses people. Only threshold crossings change
        // membership; happiness's much faster cadence performs no person scan.
        bool Crossed(double threshold)=>oldAge<threshold&&p.Age>=threshold;
        if(Crossed(_workingAge)||Crossed(6)||Crossed(_educationMinAges[1])||Crossed(_educationMinAges[2])||Crossed(_educationMinAges[3])||Crossed(_educationMinAges[4]))UpdateHappiness(p);
    }
    // Internal managed-to-managed aggregation. No per-person Godot dictionary export.
    internal Dictionary<long,HappinessPeople> HappinessGroups()
    {
        if(_happinessGroups==null)
        {
            _happinessGroups=new();_happinessHomes.Clear();foreach(var h in _households)_happinessHomes[h.Id]=h.Home;
            foreach(var p in _people){p.Happiness=Membership(p);ApplyHappiness(p.Happiness,1);}
        }
        return _happinessGroups;
    }
    // Main-thread-only accessor: only dirty IDs are copied into the next persistent root.
    internal IReadOnlyDictionary<long,HappinessPeople> HappinessGroupSnapshot()
    {
        HappinessGroups();
        if(_dirtyHappinessGroups.Count==0)return _happinessSnapshot;
        var next=_happinessSnapshot.ToBuilder();
        foreach(long id in _dirtyHappinessGroups)
            if(_happinessGroups!.TryGetValue(id,out var group))next[id]=group.Freeze();else next.Remove(id);
        _happinessSnapshot=next.ToImmutable();_dirtyHappinessGroups.Clear();return _happinessSnapshot;
    }
}
