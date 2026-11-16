using System.Collections.Generic;

internal sealed class HappinessPeople
{
    internal int Count,Eligible,Employed;
    internal readonly int[] Students=new int[4];
}
public partial class PopulationState
{
    // One membership per person, including both roles even when home == workplace.
    // Aggregate objects are managed-only and read-only to HappinessCore consumers.
    // The dictionary is updated in place: identity is not a population generation.
    private readonly record struct HappinessMembership(long Home,long Work,bool Eligible,int Students);
    private Dictionary<long,HappinessPeople>? _happinessGroups;
    private readonly Dictionary<long,long> _happinessHomes=new();
    private void InvalidateHappiness() {_happinessGroups=null;_happinessHomes.Clear();}
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
        if(_happinessGroups!=null)return _happinessGroups;
        _happinessGroups=new();_happinessHomes.Clear();foreach(var h in _households)_happinessHomes[h.Id]=h.Home;
        foreach(var p in _people) {p.Happiness=Membership(p);ApplyHappiness(p.Happiness,1);}
        return _happinessGroups;
    }
}
