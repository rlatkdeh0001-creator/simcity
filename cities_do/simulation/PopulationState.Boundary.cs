using System;
using Godot;
using D=Godot.Collections.Dictionary;

public partial class PopulationState
{
    // Worker-only route proof. No reachability is inferred from an open regional flag.
    public D GetLaborBoundaryDistances(long roadId,Vector2 boundary)
    {
        RequireLaborWorld();
        var result=new D();
        if(!float.IsFinite(boundary.X)||!float.IsFinite(boundary.Y))return result;
        var source=_laborRoads.Anchor(roadId,new LaborRoadGraph.P(boundary.X,boundary.Y),false,true);
        if(!source.Valid)return result;
        var distances=_laborRoads.Distances(source);
        foreach(var pair in _laborAccess)
        {
            if(!pair.Value.Valid)continue;
            double distance=_laborRoads.Distance(source,pair.Value,distances);
            if(double.IsFinite(distance))result[pair.Key]=distance;
        }
        return result;
    }
}
