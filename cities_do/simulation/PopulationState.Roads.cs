using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using A=Godot.Collections.Array;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    private bool _laborWorldPrepared;
    private LaborRoadGraph _laborRoads=new();
    private LaborRoadGraph.Road[] _laborRoadInputs=System.Array.Empty<LaborRoadGraph.Road>();
    private Dictionary<long,LaborRoadGraph.Access> _laborAccess=new();
    private readonly Dictionary<long,long> _laborHouseholdHomes=new();
    private readonly Dictionary<long,List<(long Work,double Metres)>> _laborOrders=new();
    private readonly Dictionary<long,Dictionary<long,double>> _laborRouteLookup=new();
    private readonly Dictionary<(long Home,int Education),List<(long Work,int Stage)>> _laborCandidates=new();
    private readonly Dictionary<(long Home,int Education),int> _laborCursors=new();
    private int _laborTopologyBuilds,_laborRouteSearches,_laborCandidateBuilds;
    private int _laborCacheLimit=128;
    private readonly LinkedList<long> _laborRouteLru=new();
    private readonly Dictionary<long,LinkedListNode<long>> _laborRouteLruNodes=new();
    private void ClearLaborRoutes()
    {_laborOrders.Clear();_laborRouteLookup.Clear();_laborCandidates.Clear();_laborCursors.Clear();_laborRouteLru.Clear();_laborRouteLruNodes.Clear();}
    private void TrimLaborRouteCache()
    {
        while(_laborRouteLru.Count>_laborCacheLimit)
        {
            long home=_laborRouteLru.First!.Value;_laborRouteLru.RemoveFirst();_laborRouteLruNodes.Remove(home);_laborOrders.Remove(home);_laborRouteLookup.Remove(home);
            foreach(var key in _laborCandidates.Keys.Where(k=>k.Home==home).ToArray()){_laborCandidates.Remove(key);_laborCursors.Remove(key);}
        }
    }

    /// <summary>Worker-only. Native roads use parcel_id and PackedVector2Array points
    /// in city cells (4m); buildings use id, zone, front_road_id, polygon or position.
    /// No borrowed dictionaries survive this call. Call when geometry/frontage dirty.
    /// Configuration/capacity edits do not invalidate road distances.</summary>
    public void PrepareLaborWorld(A buildings,A roads)
    {
        var inputs=LaborRoadGraph.ReadRoads(roads);
        bool topologyChanged=!LaborRoadGraph.SameRoads(inputs,_laborRoadInputs);
        // Build into temporaries: malformed geometry must not partially replace caches.
        var graph=topologyChanged?new LaborRoadGraph(inputs):_laborRoads;
        var access=new Dictionary<long,LaborRoadGraph.Access>();
        foreach(var value in buildings)
        {
            var b=value.AsGodotDictionary();long id=Id(b,"id");
            var point=LaborRoadGraph.BuildingPoint(b);
            long road=b.TryGetValue("front_road_id",out var r)?r.AsInt64():-1;
            access.Add(id,graph.Anchor(road,point,Str(b,"zone")!="residential"));
        }
        bool accessChanged=access.Count!=_laborAccess.Count||access.Any(p=>!_laborAccess.TryGetValue(p.Key,out var old)||old!=p.Value);
        if(topologyChanged||accessChanged)ClearLaborRoutes();
        _laborRoadInputs=inputs;_laborRoads=graph;_laborAccess=access;
        if(topologyChanged)_laborTopologyBuilds++;
        _laborWorldPrepared=true;InvalidateManagedSnapshots();
    }
    private void RequireLaborWorld()
    {
        if(_laborEnabled&&!_laborWorldPrepared)throw new InvalidOperationException("PrepareLaborWorld is required after import/restore and before road-based matching");
    }
    private void InvalidateLaborImport()
    {
        _laborInbound.Clear();_laborOutbound.Clear();_pendingLaborPlan=null;
        _laborWorldPrepared=false;ClearLaborRoutes();
        _laborHouseholdHomes.Clear();foreach(var h in _households)_laborHouseholdHomes[h.Id]=h.Home;
    }
    private List<(long Work,double Metres)> LaborOrder(long home)
    {
        RequireLaborWorld();if(_laborOrders.TryGetValue(home,out var order))
        {var node=_laborRouteLruNodes[home];_laborRouteLru.Remove(node);_laborRouteLru.AddLast(node);return order;}
        order=new();
        if(_laborAccess.TryGetValue(home,out var source)&&source.Valid)
        {
            var distances=_laborRoads.Distances(source);_laborRouteSearches++;
            foreach(var pair in _laborAccess)if(pair.Value.Workplace&&pair.Value.Valid)
            {
                double metres=_laborRoads.Distance(source,pair.Value,distances);
                if(double.IsFinite(metres))order.Add((pair.Key,metres));
            }
            order.Sort((a,b)=>{int c=a.Metres.CompareTo(b.Metres);return c!=0?c:a.Work.CompareTo(b.Work);});
        }
        _laborOrders[home]=order;_laborRouteLookup[home]=order.ToDictionary(p=>p.Work,p=>p.Metres);
        _laborRouteLruNodes[home]=_laborRouteLru.AddLast(home);TrimLaborRouteCache();return order;
    }
    private void FillRoadWaiting(int first,int last)
    {
        RequireLaborWorld();
        for(int i=first;i<last;i++)
        {
            var p=_people[i];if(p.Work!=-1||p.Age<_workingAge||LaborExternal(p))continue;
            long home=_laborHouseholdHomes.GetValueOrDefault(p.Household,-1);var key=(home,p.Education);
            if(!_laborCandidates.TryGetValue(key,out var candidates))
            {
                candidates=new();foreach(var job in LaborOrder(home))for(int stage=Math.Max(0,p.Education-1);stage<=Math.Min(4,p.Education+1);stage++)candidates.Add((job.Work,stage));
                _laborCandidates[key]=candidates;_laborCandidateBuilds++;
            }
            int cursor=_laborCursors.GetValueOrDefault(key);
            while(cursor<candidates.Count)
            {
                var candidate=candidates[cursor];
                if(_works.TryGetValue(candidate.Work,out var w)&&w.Filled[candidate.Stage]+InboundReserved(w.Id,candidate.Stage)<w.Slots[candidate.Stage])
                {p.Work=candidate.Work;p.Stage=candidate.Stage;w.Filled[p.Stage]++;UpdateHappiness(p);break;}
                cursor++;
            }
            _laborCursors[key]=cursor;
        }
    }
    public double GetLaborRoadDistance(long homeId,long workplaceId)
    {
        LaborOrder(homeId);return _laborRouteLookup[homeId].GetValueOrDefault(workplaceId,-1);
    }
    public D LaborRoadDiagnostics()=>new(){["prepared"]=_laborWorldPrepared,["topology_builds"]=_laborTopologyBuilds,["route_searches"]=_laborRouteSearches,["candidate_builds"]=_laborCandidateBuilds,["cached_homes"]=_laborOrders.Count,["nodes"]=_laborRoads.NodeCount};
}

// Undirected centreline shortest paths, not lane traffic/vehicle routes. Crossings
// split at their true coordinates; no raster/Euclidean endpoint approximation.
internal sealed class LaborRoadGraph
{
    internal readonly record struct P(double X,double Y)
    {
        public static P operator +(P a,P b)=>new(a.X+b.X,a.Y+b.Y);
        public static P operator -(P a,P b)=>new(a.X-b.X,a.Y-b.Y);
        public static P operator *(P a,double n)=>new(a.X*n,a.Y*n);
        internal double Length=>Math.Sqrt(X*X+Y*Y);
        internal double Dot(P b)=>X*b.X+Y*b.Y;
        internal double Cross(P b)=>X*b.Y-Y*b.X;
    }
    internal sealed record Road(long Id,string Kind,double Elevation,P[] Points);
    private sealed record Segment(long Road,string Kind,double Elevation,P A,P B);
    private sealed record Edge(long Road,string Kind,P A,P B,int First,int Last,double Length);
    internal readonly record struct Access(int Edge,int First,int Last,double Offset,double Length,bool Workplace)
    {internal bool Valid=>Edge>=0;}
    private readonly List<Edge> _edges=new();
    private readonly List<List<(int Node,double Length)>> _neighbors=new();
    private int[] _components=System.Array.Empty<int>();
    internal bool CanReach(Access source,Access target)=>source.Valid&&target.Valid&&_components[source.First]==_components[target.First];
    internal int NodeCount=>_neighbors.Count;
    internal LaborRoadGraph(){}
    private const double Eps=1e-8;
    internal static Road[] ReadRoads(A values)
    {
        var roads=new List<Road>();var ids=new HashSet<long>();
        foreach(var value in values)
        {
            var d=value.AsGodotDictionary();long id=d["parcel_id"].AsInt64();if(!ids.Add(id))throw new ArgumentException("Duplicate road parcel_id");
            var points=d["points"].AsVector2Array().Select(v=>new P(v.X,v.Y)).ToArray();
            double elevation=d.TryGetValue("elevation_m",out var e)?e.AsDouble():0;
            if(!double.IsFinite(elevation)||points.Any(p=>!double.IsFinite(p.X)||!double.IsFinite(p.Y)))throw new ArgumentException("Nonfinite road geometry");
            roads.Add(new(id,d.TryGetValue("kind",out var k)?k.AsString():"local",elevation,points));
        }
        return roads.OrderBy(r=>r.Id).ToArray();
    }
    internal static bool SameRoads(Road[] a,Road[] b)=>a.Length==b.Length&&a.Zip(b).All(p=>p.First.Id==p.Second.Id&&p.First.Kind==p.Second.Kind&&p.First.Elevation==p.Second.Elevation&&p.First.Points.SequenceEqual(p.Second.Points));
    internal static P BuildingPoint(D b)
    {
        P point;
        if(b.TryGetValue("polygon",out var polygon))
        {
            var points=polygon.AsVector2Array();if(points.Length>0){P sum=new(0,0);foreach(var p in points)sum+=new P(p.X,p.Y);point=sum*(1.0/points.Length);return Finite(point);}
        }
        if(b.TryGetValue("position",out var position)){var p=position.AsVector2();return Finite(new(p.X,p.Y));}
        if(b.TryGetValue("frame",out var frame))
        {
            var f=frame.AsGodotDictionary();var origin=f["origin"].AsVector2();var along=f["along"].AsVector2();var outward=f["outward"].AsVector2();
            double half=b["size"].AsDouble()/2,u=b["u"].AsDouble()+half,v=b["v"].AsDouble()+half;
            return Finite(new(origin.X+along.X*u+outward.X*v,origin.Y+along.Y*u+outward.Y*v));
        }
        if(b.ContainsKey("x")&&b.ContainsKey("y"))return Finite(new(b["x"].AsDouble()+b["size"].AsDouble()/2,b["y"].AsDouble()+b["size"].AsDouble()/2));
        throw new ArgumentException("Labor building requires polygon/position, frame/u/v/size or x/y/size in cells");
    }
    private static P Finite(P point)
    {
        if(!double.IsFinite(point.X)||!double.IsFinite(point.Y))throw new ArgumentException("Nonfinite building geometry");return point;
    }
    private static double Project(P point,P a,P b)
    {var direction=b-a;double length2=direction.Dot(direction);return length2==0?0:Math.Clamp((point-a).Dot(direction)/length2,0,1);}
    internal LaborRoadGraph(Road[] roads)
    {
        var segments=new List<Segment>();
        foreach(var road in roads)for(int i=1;i<road.Points.Length;i++)if((road.Points[i]-road.Points[i-1]).Length>Eps)segments.Add(new(road.Id,road.Kind,road.Elevation,road.Points[i-1],road.Points[i]));
        var cuts=segments.Select(_=>new List<double>{0,1}).ToArray();
        for(int i=0;i<segments.Count;i++)for(int j=i+1;j<segments.Count;j++)
        {
            var a=segments[i];var b=segments[j];if(a.Elevation!=b.Elevation)continue;
            var u=a.B-a.A;var v=b.B-b.A;double cross=u.Cross(v);
            if(Math.Abs(cross)>Eps)
            {
                double t=(b.A-a.A).Cross(v)/cross,s=(b.A-a.A).Cross(u)/cross;
                if(t>=-Eps&&t<=1+Eps&&s>=-Eps&&s<=1+Eps){cuts[i].Add(Math.Clamp(t,0,1));cuts[j].Add(Math.Clamp(s,0,1));}
            }
            else if(Math.Abs((b.A-a.A).Cross(u))<=Eps)
            {
                // Shared/overlapping collinear endpoints also form real nodes.
                foreach(var p in new[]{b.A,b.B}){double t=Project(p,a.A,a.B);if((a.A+u*t-p).Length<Eps)cuts[i].Add(t);}
                foreach(var p in new[]{a.A,a.B}){double t=Project(p,b.A,b.B);if((b.A+v*t-p).Length<Eps)cuts[j].Add(t);}
            }
        }
        var nodes=new Dictionary<(double X,double Y,double Elevation),int>();
        int Node(P p,double elevation)
        {
            // Numerical intersection identity only (1e-8 cell), never proximity snapping.
            var key=(Math.Round(p.X,8),Math.Round(p.Y,8),elevation);
            if(nodes.TryGetValue(key,out int n))return n;n=_neighbors.Count;nodes[key]=n;_neighbors.Add(new());return n;
        }
        for(int i=0;i<segments.Count;i++)
        {
            var segment=segments[i];var sorted=cuts[i].Distinct().OrderBy(v=>v).ToArray();
            for(int j=1;j<sorted.Length;j++)
            {
                P a=segment.A+(segment.B-segment.A)*sorted[j-1],b=segment.A+(segment.B-segment.A)*sorted[j];double length=(b-a).Length*4;
                if(length<=Eps)continue;int first=Node(a,segment.Elevation),last=Node(b,segment.Elevation);
                _edges.Add(new(segment.Road,segment.Kind,a,b,first,last,length));_neighbors[first].Add((last,length));_neighbors[last].Add((first,length));
            }
        }
        _components=Enumerable.Repeat(-1,_neighbors.Count).ToArray();var pending=new Queue<int>();
        for(int start=0;start<_neighbors.Count;start++)
        {
            if(_components[start]>=0)continue;_components[start]=start;pending.Enqueue(start);
            while(pending.TryDequeue(out int node))foreach(var edge in _neighbors[node])if(_components[edge.Node]<0){_components[edge.Node]=start;pending.Enqueue(edge.Node);}
        }
    }
    internal Access Anchor(long road,P point,bool workplace,bool allowHighway=false)
    {
        int chosen=-1;double best=double.PositiveInfinity,offset=0;
        for(int i=0;i<_edges.Count;i++)
        {
            var edge=_edges[i];if(edge.Road!=road||(!allowHighway&&edge.Kind!="local"))continue;
            double t=Project(point,edge.A,edge.B),gap=(point-(edge.A+(edge.B-edge.A)*t)).Length;
            if(gap<best){chosen=i;best=gap;offset=t*edge.Length;}
        }
        if(chosen<0)return new(-1,-1,-1,0,0,workplace);
        var e=_edges[chosen];return new(chosen,e.First,e.Last,offset,e.Length,workplace);
    }
    internal double[] Distances(Access source)
    {
        var result=Enumerable.Repeat(double.PositiveInfinity,_neighbors.Count).ToArray();var queue=new PriorityQueue<int,double>();
        void Seed(int n,double d){if(d<result[n]){result[n]=d;queue.Enqueue(n,d);}}
        Seed(source.First,source.Offset);Seed(source.Last,source.Length-source.Offset);
        while(queue.TryDequeue(out int n,out double distance))
        {
            if(distance>result[n])continue;
            foreach(var edge in _neighbors[n])Seed(edge.Node,distance+edge.Length);
        }
        return result;
    }
    internal double Distance(Access source,Access target,double[] distances)
    {
        double distance=Math.Min(distances[target.First]+target.Offset,distances[target.Last]+target.Length-target.Offset);
        if(source.Edge==target.Edge)distance=Math.Min(distance,Math.Abs(source.Offset-target.Offset));return distance;
    }
}
