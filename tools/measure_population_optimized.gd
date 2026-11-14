extends "D:/project/simcity/tools/measure_population_tick.gd"
func run():
 var stage:="before"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--stage="):stage=arg.trim_prefix("--stage=")
 assert(stage in ["before","after"])
 var folder:="D:/project/simcity/docs/population-optimization-validation";DirAccess.make_dir_recursive_absolute(folder)
 var rows:Array=[]
 for count in [0,240,1000,5000]:
  var city=fixture(count);var pop=city.population;assert(pop.people.size()==count)
  var start:=Time.get_ticks_usec();city.advance_society(2);var total:=Time.get_ticks_usec()-start
  assert(city.clock.game_seconds==48)
  if stage=="after":assert(pop.jobs_calls==1)
  var row:={"population":count,"population_after":pop.people.size(),"total_tick_ms":total/1000.0,"population_advance_ms":pop.advance_us/1000.0,"sync_excluding_jobs_ms":(pop.sync_us-pop.sync_match_us)/1000.0,"match_jobs_ms":pop.jobs_us/1000.0,"match_jobs_calls":pop.jobs_calls,"development_ms":city.development_us/1000.0,"demand_ms":pop.demand_us/1000.0,"demand_calls":pop.demand_calls,"demand_full_scans":pop.demand_full_scans if stage=="after" else pop.demand_calls}
  rows.append(row);print("POPULATION_OPT ",stage," ",JSON.stringify(row))
  var file:=FileAccess.open(folder.path_join(stage+".json"),FileAccess.WRITE);file.store_string(JSON.stringify({"stage":stage,"method":"same 20261114 seed fixture, full houses, jobs primed, 32 designated cells; one real 2-second society tick; development includes demand","rows":rows},"  "));file.close()
 print("POPULATION_OPT_PASS "+stage);quit()
