using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using D=Godot.Collections.Dictionary;

public partial class HappinessCore
{
    private readonly record struct PreparedTarget(ScoreInputs Inputs,double Pollution,bool Park,D Result,bool Evaluated,bool PollutionEvaluated);
    private int _parallelWorkers=Math.Max(1,Math.Min(8,Environment.ProcessorCount-1));
    private int _parallelMinimum=128;
    // Zero is the serial oracle. Positive values force the parallel path for regression tests.
    public void SetParallelWorkers(int workers)
    {_parallelWorkers=Math.Clamp(workers,0,Math.Max(1,Environment.ProcessorCount));_parallelMinimum=workers>0?0:128;}
    private PreparedTarget[]? PrepareBucket(List<Building> batch)
    {
        if(_parallelWorkers<=1||batch.Count<_parallelMinimum)return null;
        // Distance's route cache is the only lazy graph mutation. Finish it before fan-out.
        var attached=_buildings.Values.FirstOrDefault(b=>_buildingAnchors.GetValueOrDefault(b.Id).HasValue);
        if(attached!=null)foreach(var f in _facilities.Values)if(f.Kind=="park"||f.Kind=="health"||f.Kind=="police"||f.Kind=="fire"||f.Kind=="education")Distance(attached,f);
        var prepared=new PreparedTarget[batch.Count];
        Parallel.For(0,batch.Count,new ParallelOptions {MaxDegreeOfParallelism=_parallelWorkers},i=>
        {
            var b=batch[i];_targetCache.TryGetValue(b.Id,out var cache);
            double pollution=cache?.Pollution??Pollution(b);bool park=cache?.Park??HasNearbyPark(b);
            var inputs=InputsFor(b,pollution,park);bool evaluate=cache?.Inputs!=inputs;
            // All world/state/cache dictionaries are read-only here. Each new result dictionary
            // belongs to one worker; it is transferred only after Parallel.For has joined.
            var result=evaluate?EvaluateScore(inputs):cache!.Result;
            prepared[i]=new(inputs,pollution,park,result,evaluate,cache==null||!cache.Pollution.HasValue);
        });
        return prepared;
    }
    private void PublishTarget(Building b,State state,PreparedTarget prepared)
    {
        var cache=Cache(b.Id);cache.Inputs=prepared.Inputs;cache.Pollution=prepared.Pollution;cache.Park=prepared.Park;cache.Result=prepared.Result;
        if(prepared.Evaluated)_targetEvaluations++;if(prepared.PollutionEvaluated)_pollutionEvaluations++;
        state.Target=prepared.Result["target"].AsDouble();state.Factors=prepared.Result["factors"].AsGodotDictionary().Duplicate();
    }
}
