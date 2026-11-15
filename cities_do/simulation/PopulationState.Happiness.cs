using System.Collections.Generic;

internal sealed class HappinessPeople
{
    internal int Count,Eligible,Employed;
    internal readonly int[] Students=new int[4];
}
public partial class PopulationState
{
    // Internal managed-to-managed aggregation. No per-person Godot dictionary export.
    internal Dictionary<long,HappinessPeople> HappinessGroups()
    {
        var homes=new Dictionary<long,long>();foreach(var h in _households)homes[h.Id]=h.Home;
        var groups=new Dictionary<long,HappinessPeople>();
        void Add(long id,Person person)
        {
            if(id<0)return;
            if(!groups.TryGetValue(id,out var group))groups[id]=group=new();
            group.Count++;if(person.Age>=_workingAge)group.Eligible++;if(person.Work>=0)group.Employed++;
            if(person.Age>=6&&person.Age<_educationMinAges[1])group.Students[0]++;
            for(int stage=1;stage<4;stage++)if(person.Age>=_educationMinAges[stage]&&person.Age<_educationMinAges[stage+1])group.Students[stage]++;
        }
        foreach(var person in _people)
        {
            if(homes.TryGetValue(person.Household,out long home))Add(home,person);
            if(person.Work>=0)Add(person.Work,person);
        }
        return groups;
    }
}
