using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class HappinessCore
{
    private sealed class Building
    {
        internal long Id,Road;internal int Level;internal string Zone="";
        internal Vector2 Position;internal Vector2[] Polygon=System.Array.Empty<Vector2>();
        internal bool Power,Water,Noise;internal HappinessPeople Fixture=new();
    }
    private sealed class Facility
    {
        internal long Id,Road;internal string Kind="";internal int School;
        internal double Capacity;internal Vector2 Position;internal Vector2[] Polygon=System.Array.Empty<Vector2>();
    }
    private sealed class State
    {
        internal bool Initialized,Pending;internal int Level;internal double Actual,Target,Housing;internal double? Since;
        internal D Factors=new();
    }
    private readonly record struct Edge(int A,int B,long Road,Vector2 Start,Vector2 End,double Length);
    private readonly record struct Anchor(int Edge,double FromStart);
    private readonly Dictionary<long,Building> _buildings=new();
    private readonly List<Building>[] _buckets=Enumerable.Range(0,75).Select(_=>new List<Building>()).ToArray();
    private readonly Dictionary<long,Facility> _facilities=new();
    private readonly Dictionary<long,State> _states=new();
    private readonly List<Edge> _edges=new();
    private readonly List<List<(int Node,double Cost)>> _graph=new();
    private readonly Dictionary<long,(Anchor Anchor,double[] Costs)> _routes=new();
    private readonly Dictionary<(long Building,string Kind,int School),long> _assignments=new();
    private Dictionary<long,HappinessPeople> _groups=new();
    private PopulationState? _population;
    private double _elapsed,_nextDay=86400;
    private bool _assigned;
    private int _bucket;
    public void BindPopulation(PopulationState population)=>_population=population;
    private static long Long(D d,string key)=>d.TryGetValue(key,out var v)?v.AsInt64():0;
    private static bool Flag(D d,string key)=>d.TryGetValue(key,out var v)&&v.AsBool();
    private static Vector2[] Polygon(D d)=>d.TryGetValue("polygon",out var v)?v.AsVector2Array():System.Array.Empty<Vector2>();
    public void SetWorld(A buildings,A facilities,double[] roads)
    {
        var previous=new Dictionary<long,Building>(_buildings);var previousFacilities=new Dictionary<long,Facility>(_facilities);
        var previousAnchors=new Dictionary<long,Anchor?>(_facilityAnchors);bool roadsChanged=!_indexedRoads.SequenceEqual(roads);_indexedRoads=(double[])roads.Clone();
        var seen=new HashSet<long>();_buildings.Clear();_facilities.Clear();_routes.Clear();
        foreach(var bucket in _buckets)bucket.Clear();
        foreach(var value in buildings)
        {
            var d=value.AsGodotDictionary();long id=Long(d,"id");seen.Add(id);
            var b=new Building {Id=id,Road=Long(d,"road"),Position=d["position"].AsVector2(),Polygon=Polygon(d),Zone=d["zone"].AsString(),
                Level=(int)Long(d,"level"),Power=Flag(d,"power"),Water=Flag(d,"water"),Noise=Flag(d,"noise")};
            b.Fixture.Count=(int)Long(d,"occupants");b.Fixture.Eligible=(int)Long(d,"eligible");b.Fixture.Employed=(int)Long(d,"employed");
            if(d.TryGetValue("students",out var students))for(int i=0;i<4;i++)b.Fixture.Students[i]=(int)students.AsGodotArray()[i].AsInt64();
            _buildings[id]=b;_buckets[(int)(((id%75)+75)%75)].Add(b);
            if(!_states.TryGetValue(id,out var state))_states[id]=state=new();
            if(state.Level!=b.Level){state.Since=null;state.Pending=false;}state.Level=b.Level;
        }
        foreach(long id in _states.Keys.ToArray())if(!seen.Contains(id))_states.Remove(id);
        foreach(var value in facilities)
        {
            var d=value.AsGodotDictionary();var f=new Facility {Id=Long(d,"id"),Road=Long(d,"road"),Position=d["position"].AsVector2(),Polygon=Polygon(d),
                Kind=d["kind"].AsString(),School=(int)Long(d,"school_stage"),Capacity=Number(d,"capacity")};
            if(f.Kind=="fire")f.Capacity*=_fireMultiplier;
            _facilities[f.Id]=f;
        }
        BuildRoads(roads);IndexSpatial();InvalidateSpatial(previous,previousFacilities,previousAnchors,roadsChanged);RefreshGroups();
    }
    private void RefreshGroups()=>_groups=_population?.HappinessGroups()??_buildings.ToDictionary(p=>p.Key,p=>p.Value.Fixture);
    private HappinessPeople People(long id)=>_groups.TryGetValue(id,out var p)?p:new HappinessPeople();
    private void BuildRoads(double[] roads)
    {
        if(roads.Length%5!=0)throw new ArgumentException("Road segments require road ID and endpoint XY pairs");
        _edges.Clear();_graph.Clear();var nodes=new Dictionary<(long,long),int>();
        int Node(Vector2 position)
        {
            var key=((long)Math.Round(position.X*1000),(long)Math.Round(position.Y*1000));
            if(!nodes.TryGetValue(key,out int id)){id=nodes.Count;nodes[key]=id;_graph.Add(new());}return id;
        }
        for(int i=0;i<roads.Length;i+=5)
        {
            var a=new Vector2((float)roads[i+1],(float)roads[i+2]);var b=new Vector2((float)roads[i+3],(float)roads[i+4]);
            double length=a.DistanceTo(b);if(length<.00001)continue;int from=Node(a),to=Node(b);
            _edges.Add(new(from,to,(long)roads[i],a,b,length));_graph[from].Add((to,length));_graph[to].Add((from,length));
        }
    }
    private Anchor? Attach(long road,Vector2 point)
    {
        if(road<0)return null;double nearest=double.PositiveInfinity;Anchor? anchor=null;
        for(int i=0;i<_edges.Count;i++)
        {
            var edge=_edges[i];if(edge.Road!=road)continue;Vector2 delta=edge.End-edge.Start;
            double t=Math.Clamp((point-edge.Start).Dot(delta)/delta.LengthSquared(),0,1);Vector2 projected=edge.Start+delta*(float)t;
            double gap=point.DistanceSquaredTo(projected);if(gap<nearest){nearest=gap;anchor=new(i,t*edge.Length);}
        }
        return anchor;
    }
    private double Distance(Building building,Facility facility)
    {
        var target=_buildingAnchors.GetValueOrDefault(building.Id);if(target==null)return double.PositiveInfinity;
        if(!_routes.TryGetValue(facility.Id,out var route))
        {
            var start=_facilityAnchors.GetValueOrDefault(facility.Id);if(start==null)return double.PositiveInfinity;
            var costs=Enumerable.Repeat(double.PositiveInfinity,_graph.Count).ToArray();var queue=new PriorityQueue<int,double>();
            var e=_edges[start.Value.Edge];costs[e.A]=start.Value.FromStart;costs[e.B]=e.Length-start.Value.FromStart;
            queue.Enqueue(e.A,costs[e.A]);queue.Enqueue(e.B,costs[e.B]);
            while(queue.TryDequeue(out int node,out double cost))
            {
                if(cost>costs[node])continue;
                foreach(var next in _graph[node])if(cost+next.Cost<costs[next.Node]){costs[next.Node]=cost+next.Cost;queue.Enqueue(next.Node,costs[next.Node]);}
            }
            _routes[facility.Id]=route=(start.Value,costs);
        }
        var edge=_edges[target.Value.Edge];double result=Math.Min(route.Costs[edge.A]+target.Value.FromStart,route.Costs[edge.B]+edge.Length-target.Value.FromStart);
        if(target.Value.Edge==route.Anchor.Edge)result=Math.Min(result,Math.Abs(target.Value.FromStart-route.Anchor.FromStart));
        return result;
    }
    public int DistanceScore(double metres)=>!double.IsFinite(metres)||metres>6000.00001?0:Math.Max(5,11-Math.Max(1,(int)Math.Ceiling((metres-.00001)/1000)));
    private int Demand(Building b,string kind,int school)=>kind=="fire"?1:kind=="education"?People(b.Id).Students[school]:People(b.Id).Count;
    private void AssignServices()
    {
        _assignments.Clear();_assigned=true;
        foreach(string kind in new[]{"health","police","fire","education"})
        for(int school=0;school<(kind=="education"?4:1);school++)
        {
            var remaining=_facilities.Values.Where(f=>f.Kind==kind&&(kind!="education"||f.School==school)).ToDictionary(f=>f.Id,f=>f.Capacity);
            var pairs=new List<(double Distance,long Building,long Facility)>();
            foreach(var f in _facilities.Values.Where(f=>remaining.ContainsKey(f.Id)))foreach(var b in ServiceCandidates(f))
            {
                if(Demand(b,kind,school)<=0)continue;double distance=Distance(b,f);if(DistanceScore(distance)>0)pairs.Add((distance,b.Id,f.Id));
            }
            pairs.Sort((a,b)=>{int order=a.Distance.CompareTo(b.Distance);if(order!=0)return order;order=a.Building.CompareTo(b.Building);return order!=0?order:a.Facility.CompareTo(b.Facility);});
            foreach(var pair in pairs)
            {
                var key=(pair.Building,kind,school);int demand=Demand(_buildings[pair.Building],kind,school);
                if(_assignments.ContainsKey(key)||remaining[pair.Facility]<demand)continue;
                remaining[pair.Facility]-=demand;_assignments[key]=pair.Facility;
            }
        }
    }
    private double Service(Building b,string kind,int school=0)=>_assignments.TryGetValue((b.Id,kind,school),out long id)&&_facilities.TryGetValue(id,out var f)?DistanceScore(Distance(b,f)):0;
    private static bool OnSegment(Vector2 p,Vector2 a,Vector2 b)=>Math.Abs((b-a).Cross(p-a))<.00001&&(p-a).Dot(p-b)<=.00001;
    private static bool Inside(Vector2 p,Vector2[] polygon)
    {
        bool inside=false;
        for(int i=0,j=polygon.Length-1;i<polygon.Length;j=i++)
        {
            var a=polygon[j];var b=polygon[i];if(OnSegment(p,a,b))return true;
            if((a.Y>p.Y)!=(b.Y>p.Y)&&p.X<(b.X-a.X)*(p.Y-a.Y)/(b.Y-a.Y)+a.X)inside=!inside;
        }
        return inside;
    }
    private static bool Crosses(Vector2 from,Vector2 to,Vector2[] polygon)
    {
        if(Inside(from,polygon)||Inside(to,polygon))return true;
        for(int i=0;i<polygon.Length;i++)
        {
            var a=polygon[i];var b=polygon[(i+1)%polygon.Length];var r=to-from;var s=b-a;double cross=r.Cross(s);
            if(Math.Abs(cross)<.000001){if(OnSegment(a,from,to)||OnSegment(b,from,to))return true;continue;}
            double t=(a-from).Cross(s)/cross,u=(a-from).Cross(r)/cross;if(t>=0&&t<=1&&u>=0&&u<=1)return true;
        }
        return false;
    }
    private double Pollution(Building b)
    {
        double penalty=b.Noise?5:0;
        double Source(Vector2 position,bool heavy)
        {
            double distance=b.Position.DistanceTo(position);double value=heavy?(distance<=300?15:distance<=600?8:0):(distance<=100?10:distance<=200?5:0);
            if(value>0&&b.Zone=="residential"&&Buffered(position,b.Position))value*=.5;
            return value;
        }
        foreach(var source in _industrialGrid.Near(b.Position,200.001)){penalty+=Source(source.Position,false);if(penalty>=15)return -15;}
        foreach(var source in _pollutionGrid.Near(b.Position,600.001)){penalty+=Source(source.Position,true);if(penalty>=15)return -15;}
        return -Math.Min(15,penalty);
    }
    private ScoreInputs InputsFor(Building b,double pollution,bool park)
    {
        var people=People(b.Id);double education=0;int students=people.Students.Sum();
        if(students>0)for(int i=0;i<4;i++)education+=Service(b,"education",i)*people.Students[i]/students;
        return new ScoreInputs(people.Eligible>0?(double)people.Employed/people.Eligible:0,
            Service(b,"health"),Service(b,"police"),Service(b,"fire"),education,
            park?5:0,_states[b.Id].Housing,pollution,b.Power,b.Water);
    }
    private D Calculate(Building b)=>CachedScore(b,InputsFor(b,CachedPollution(b),CachedPark(b)));
    public D Preview(long id)=>Calculate(_buildings[id]).Duplicate(true);
    private void Target(Building b,State state){var value=Calculate(b);state.Target=value["target"].AsDouble();state.Factors=value["factors"].AsGodotDictionary().Duplicate();}
    private bool Qualifies(Building b,State s)=>s.Initialized&&b.Power&&b.Water&&People(b.Id).Count>0&&b.Level<5&&s.Actual>=40+b.Level*10;
    private void Observe(Building b,State s)
    {
        if(!b.Power||!b.Water){s.Actual=0;s.Target=0;}
        if(!Qualifies(b,s))s.Since=null;
    }
    public D Inspect(long id)
    {
        var s=_states[id];return new D {["initialized"]=s.Initialized,["actual"]=s.Actual,["target"]=s.Target,["factors"]=s.Factors,
            ["housing"]=s.Housing,["held_seconds"]=s.Since.HasValue?Math.Max(0,_elapsed-s.Since.Value):0};
    }
    private Variant _cityHappiness;
    public Variant CityHappiness()=>_cityHappiness;
    private void UpdateCityHappiness()
    {
        double weighted=0;int residents=0;bool complete=true;
        foreach(var b in _buildings.Values)
        {
            if(b.Zone!="residential")continue;int count=People(b.Id).Count;if(count<=0)continue;
            residents+=count;var state=_states[b.Id];complete&=state.Initialized;weighted+=state.Actual*count;
        }
        _cityHappiness=residents>0&&complete?Variant.From(weighted/residents):default;
    }
    public D Tick(double seconds,long[] supplies)
    {
        var upgrades=new A();var updates=new D();if(!double.IsFinite(seconds)||seconds<=0)return new D {["upgrades"]=upgrades,["updates"]=updates};
        _elapsed+=seconds;RefreshGroups();
        for(int i=0;i+2<supplies.Length;i+=3)if(_buildings.TryGetValue(supplies[i],out var b)){b.Power=supplies[i+1]!=0;b.Water=supplies[i+2]!=0;}
        if(!_assigned)AssignServices();
        foreach(var b in _buildings.Values)
        {
            var s=_states[b.Id];double before=s.Actual;Observe(b,s);if(before!=s.Actual)updates[b.Id]=Inspect(b.Id);
        }
        while(_elapsed+1e-8>=_nextDay)
        {
            AssignServices();
            foreach(var b in _buildings.Values)
            {
                var s=_states[b.Id];if(!s.Initialized)continue;
                int neighbors=b.Zone=="residential"?HigherNeighbors(b):0;
                s.Housing+=Math.Sign(Math.Min(5,neighbors)-s.Housing);Target(b,s);
                s.Actual+=Math.Clamp(s.Target-s.Actual,-5,5);Observe(b,s);updates[b.Id]=Inspect(b.Id);
            }
            _nextDay+=86400;
        }
        var prepared=PrepareBucket(_buckets[_bucket]);int preparedIndex=0;
        foreach(var b in _buckets[_bucket])
        {
            var s=_states[b.Id];if(prepared==null)Target(b,s);else PublishTarget(b,s,prepared[preparedIndex++]);
            if(!s.Initialized){s.Actual=s.Target;s.Initialized=true;}
            Observe(b,s);if(Qualifies(b,s)&&!s.Since.HasValue)s.Since=_elapsed;
            if(s.Since.HasValue&&_elapsed-s.Since.Value>=86400-1e-8&&!s.Pending){s.Pending=true;upgrades.Add(b.Id);}
            updates[b.Id]=Inspect(b.Id);
        }
        _bucket=(_bucket+1)%75;UpdateCityHappiness();return new D {["upgrades"]=upgrades,["updates"]=updates,["city_happiness"]=_cityHappiness};
    }
    public void Acknowledge(long id,bool success,int level)
    {
        if(!_states.TryGetValue(id,out var s)||!_buildings.TryGetValue(id,out var b))return;
        s.Pending=false;if(success){b.Level=level;s.Level=level;s.Since=Qualifies(b,s)?_elapsed:null;}
    }
}
