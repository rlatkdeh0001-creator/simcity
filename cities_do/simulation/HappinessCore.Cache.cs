using System;
using System.Collections.Generic;
using System.Linq;
using Godot;
using D=Godot.Collections.Dictionary;

public partial class HappinessCore
{
    private readonly record struct ScoreInputs(double Employment,double Health,double Police,double Fire,double Education,double Park,double Housing,double Pollution,bool Power,bool Water);
    private sealed class CachedTarget
    {
        internal double? Pollution;internal bool? Park;internal ScoreInputs? Inputs;internal D Result=new();
    }
    private readonly Dictionary<long,CachedTarget> _targetCache=new();
    private double[] _indexedRoads=System.Array.Empty<double>();
    private long _targetEvaluations,_pollutionEvaluations;
    public D CacheStats()=>new D {["target_evaluations"]=_targetEvaluations,["pollution_evaluations"]=_pollutionEvaluations};
    private CachedTarget Cache(long id)
    {if(!_targetCache.TryGetValue(id,out var value))_targetCache[id]=value=new();return value;}
    private double CachedPollution(Building b)
    {
        var cache=Cache(b.Id);if(!cache.Pollution.HasValue){cache.Pollution=Pollution(b);_pollutionEvaluations++;}return cache.Pollution.Value;
    }
    private bool CachedPark(Building b)
    {var cache=Cache(b.Id);cache.Park??=HasNearbyPark(b);return cache.Park.Value;}
    private D CachedScore(Building b,ScoreInputs inputs)
    {
        var cache=Cache(b.Id);if(cache.Inputs.HasValue&&cache.Inputs.Value==inputs)return cache.Result;
        cache.Inputs=inputs;_targetEvaluations++;
        return cache.Result=EvaluateScore(inputs);
    }
    private D EvaluateScore(ScoreInputs inputs)=>Score(new D {["employment"]=inputs.Employment,["power"]=inputs.Power,["water"]=inputs.Water,
        ["health"]=inputs.Health,["police"]=inputs.Police,["fire"]=inputs.Fire,["education"]=inputs.Education,
        ["park"]=inputs.Park,["housing"]=inputs.Housing,["pollution_noise"]=inputs.Pollution});
    private static bool SameSource(Building a,Building b)=>a.Zone==b.Zone&&a.Position==b.Position;
    private static bool SameFacility(Facility a,Facility b)=>a.Kind==b.Kind&&a.Position==b.Position&&a.Road==b.Road&&a.Polygon.SequenceEqual(b.Polygon);
    private void DirtyPollution(IEnumerable<Building> buildings)
    {foreach(var b in buildings)if(_targetCache.TryGetValue(b.Id,out var cache))cache.Pollution=null;}
    private void DirtyPark(IEnumerable<Building> buildings)
    {foreach(var b in buildings)if(_targetCache.TryGetValue(b.Id,out var cache))cache.Park=null;}
    private void InvalidateSpatial(Dictionary<long,Building> previous,Dictionary<long,Facility> facilities,Dictionary<long,Anchor?> anchors,bool roadsChanged)
    {
        foreach(long id in _targetCache.Keys.ToArray())if(!_buildings.ContainsKey(id))_targetCache.Remove(id);
        foreach(var b in _buildings.Values)
            if(!previous.TryGetValue(b.Id,out var old)||old.Position!=b.Position||old.Zone!=b.Zone||old.Road!=b.Road||old.Noise!=b.Noise)_targetCache.Remove(b.Id);
        foreach(var old in previous.Values)
            if(old.Zone=="industrial"&&(!_buildings.TryGetValue(old.Id,out var b)||!SameSource(old,b)))DirtyPollution(_buildingGrid.Near(old.Position,200.001));
        foreach(var b in _buildings.Values)
            if(b.Zone=="industrial"&&(!previous.TryGetValue(b.Id,out var old)||!SameSource(old,b)))DirtyPollution(_buildingGrid.Near(b.Position,200.001));
        // Road topology has non-local effects on reachable parks, unlike Euclidean pollution.
        if(roadsChanged)foreach(var cache in _targetCache.Values)cache.Park=null;
        void ChangedFacility(Facility f,bool old)
        {
            if(f.Kind=="pollution")DirtyPollution(_buildingGrid.Near(f.Position,600.001));
            if(f.Kind!="park")return;
            if(f.Polygon.Length>0)
            {
                Vector2 min=f.Polygon[0],max=min;foreach(var p in f.Polygon){min=min.Min(p);max=max.Max(p);}
                var pad=new Vector2(600.001f,600.001f);DirtyPollution(_buildingGrid.Box(min-pad,max+pad));
            }
            // Old projected anchors use the old graph. On graph changes all park scores were dirtied already.
            if(roadsChanged)return;
            var map=old?anchors:_facilityAnchors;
            if(map.TryGetValue(f.Id,out var anchor)&&anchor.HasValue)DirtyPark(_serviceBuildingGrid.Near(AnchorPoint(anchor.Value),401));
        }
        foreach(var f in facilities.Values)if(!_facilities.TryGetValue(f.Id,out var next)||!SameFacility(f,next))ChangedFacility(f,true);
        foreach(var f in _facilities.Values)if(!facilities.TryGetValue(f.Id,out var old)||!SameFacility(f,old))ChangedFacility(f,false);
    }
}
