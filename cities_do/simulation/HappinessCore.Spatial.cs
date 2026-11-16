using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

public partial class HappinessCore
{
    // Geometry is metres. Road service radii are measured between projected road anchors,
    // not lot centres: off-road fixtures and frontage offsets must keep the old semantics.
    private sealed class Grid<T> where T:class
    {
        private const double Cell=600;
        private readonly Dictionary<(int,int),List<T>> _cells=new();
        internal void Clear()=>_cells.Clear();
        private static int Key(float value)=>(int)Math.Floor(value/Cell);
        internal void Add(T value,Vector2 point)=>Add(value,point,point);
        internal void Add(T value,Vector2 min,Vector2 max)
        {
            for(int x=Key(min.X);x<=Key(max.X);x++)for(int y=Key(min.Y);y<=Key(max.Y);y++)
            {if(!_cells.TryGetValue((x,y),out var list))_cells[(x,y)]=list=new();list.Add(value);}
        }
        internal IEnumerable<T> Near(Vector2 point,double radius)=>Box(point-new Vector2((float)radius,(float)radius),point+new Vector2((float)radius,(float)radius));
        internal IEnumerable<T> Box(Vector2 min,Vector2 max)
        {
            for(int x=Key(min.X);x<=Key(max.X);x++)for(int y=Key(min.Y);y<=Key(max.Y);y++)
                if(_cells.TryGetValue((x,y),out var list))foreach(var item in list)yield return item;
        }
    }
    private readonly Grid<Building> _industrialGrid=new(),_residentialGrid=new(),_serviceBuildingGrid=new();
    private readonly Grid<Facility> _pollutionGrid=new(),_parkPolygonGrid=new(),_parkRoadGrid=new();
    private readonly Dictionary<long,Anchor?> _buildingAnchors=new(),_facilityAnchors=new();
    private Vector2 AnchorPoint(Anchor anchor)
    {var edge=_edges[anchor.Edge];return edge.Start+(edge.End-edge.Start)*(float)(anchor.FromStart/edge.Length);}
    private void IndexSpatial()
    {
        _industrialGrid.Clear();_residentialGrid.Clear();_serviceBuildingGrid.Clear();
        _pollutionGrid.Clear();_parkPolygonGrid.Clear();_parkRoadGrid.Clear();_buildingAnchors.Clear();_facilityAnchors.Clear();
        foreach(var b in _buildings.Values)
        {
            if(b.Zone=="industrial")_industrialGrid.Add(b,b.Position);
            if(b.Zone=="residential")_residentialGrid.Add(b,b.Position);
            var anchor=Attach(b.Road,b.Position);_buildingAnchors[b.Id]=anchor;
            if(anchor.HasValue)_serviceBuildingGrid.Add(b,AnchorPoint(anchor.Value));
        }
        foreach(var f in _facilities.Values)
        {
            var anchor=Attach(f.Road,f.Position);_facilityAnchors[f.Id]=anchor;
            if(f.Kind=="pollution")_pollutionGrid.Add(f,f.Position);
            if(f.Kind!="park")continue;
            if(anchor.HasValue)_parkRoadGrid.Add(f,AnchorPoint(anchor.Value));
            if(f.Polygon.Length==0)continue;
            Vector2 min=f.Polygon[0],max=min;foreach(var p in f.Polygon){min=min.Min(p);max=max.Max(p);}
            _parkPolygonGrid.Add(f,min,max);
        }
    }
    private bool Buffered(Vector2 source,Vector2 target)
    {
        // Multi-cell polygon duplicates do not affect Any; exact segment intersection remains final.
        foreach(var p in _parkPolygonGrid.Box(source.Min(target),source.Max(target)))if(Crosses(source,target,p.Polygon))return true;
        return false;
    }
    private bool HasNearbyPark(Building b)
    {
        if(!_buildingAnchors.TryGetValue(b.Id,out var anchor)||!anchor.HasValue)return false;
        foreach(var f in _parkRoadGrid.Near(AnchorPoint(anchor.Value),400.0001))if(Distance(b,f)<=400.00001)return true;
        return false;
    }
    private IEnumerable<Building> ServiceCandidates(Facility f)
    {
        if(!_facilityAnchors.TryGetValue(f.Id,out var anchor)||!anchor.HasValue)return Enumerable.Empty<Building>();
        return _serviceBuildingGrid.Near(AnchorPoint(anchor.Value),6000.001);
    }
    private int HigherNeighbors(Building b)=>_residentialGrid.Near(b.Position,100.001).Count(n=>n.Id!=b.Id&&n.Level>b.Level&&n.Position.DistanceTo(b.Position)<=100.00001);
}
