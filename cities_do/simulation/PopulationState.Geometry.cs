using System;
using System.Collections.Generic;
using D = Godot.Collections.Dictionary;

public partial class PopulationState
{
    // Main-thread owned in stage 1. Neither this mutable list nor live population
    // state is published to the background happiness worker (which uses snapshots).
    private readonly List<Building> _geometry=new();
    private readonly Dictionary<long,int> _geometryIndices=new();
    private bool _geometryEnabled, _geometryDemandDirty;
    private D? _managedStats, _managedDemand;

    public int GetGeometryCount()=>_geometry.Count;
    public void EnableGeometryTransport(long[] values)
    {
        // Validate the complete seed before replacing the authoritative cache.
        var buildings=Buildings(values);var indices=new Dictionary<long,int>();
        for(int i=0;i<buildings.Count;i++)indices.Add(buildings[i].Id,i);
        _geometry.Clear();_geometry.AddRange(buildings);
        _geometryIndices.Clear();foreach(var pair in indices)_geometryIndices.Add(pair.Key,pair.Value);
        _geometryEnabled=true;_geometryDemandDirty=true;InvalidateManagedSnapshots();
    }
    public void RecordBuilding(long id,int zone,int size,int level)
    {
        RequireGeometry();
        if(zone<0||zone>=Zones.Length)throw new ArgumentException("Unknown building zone");
        var building=new Building(id,Zones[zone],size,level);
        if(_geometryIndices.TryGetValue(id,out int index))
        {
            if(_geometry[index]==building)return;
            _geometry[index]=building;
        }
        else {_geometryIndices.Add(id,_geometry.Count);_geometry.Add(building);}
        _geometryDemandDirty=true;_managedDemand=null;
    }
    public void RemoveBuilding(long id)
    {
        RequireGeometry();if(!_geometryIndices.Remove(id,out int index))return;
        // Stable compaction, never swap with the tail: first-home/job priority is
        // original array order; an ID reused after demolition must append.
        _geometry.RemoveAt(index);
        for(int i=index;i<_geometry.Count;i++)_geometryIndices[_geometry[i].Id]=i;
        _geometryDemandDirty=true;_managedDemand=null;
    }
    private void RequireGeometry()
    {
        if(!_geometryEnabled)throw new InvalidOperationException("Enable geometry transport before using managed geometry");
    }
    private void InvalidateManagedSnapshots(){_managedStats=null;_managedDemand=null;}
    public bool SyncManaged()
    {
        RequireGeometry();InvalidateManagedSnapshots();bool result=SyncInternal(_geometry);_geometryDemandDirty=false;return result;
    }
    public void AdvanceManaged(double seconds)
    {
        RequireGeometry();if(!double.IsFinite(seconds)||seconds<=0)return;
        AdvanceInternal(seconds,_geometry);_geometryDemandDirty=false;
    }
    public D DemandManaged()
    {
        RequireGeometry();
        if(_managedDemand==null)
        {
            // Reconciliation/Move already maintain these totals. Only an initial,
            // imported/configured, or demand-before-sync query needs a scan.
            if(!_reconciliationValid||_geometryDemandDirty)
            {
                if(_geometryDemandDirty)_demandPrepared=false;
                CalculateDemand(_geometry);_geometryDemandDirty=false;
            }
            _managedDemand=DemandResult();
        }
        // HUD callers own their dictionaries, not the cached snapshot.
        _demandValid=true;_demandPrepared=false;
        return _managedDemand.Duplicate();
    }
    public D StatsManaged()
    {
        RequireGeometry();_managedStats??=Stats();return _managedStats.Duplicate();
    }
    private void RefreshManagedSnapshots()
    {
        if(!_geometryEnabled)return;
        _managedStats=Stats();_managedDemand=null;DemandManaged();
    }
}
