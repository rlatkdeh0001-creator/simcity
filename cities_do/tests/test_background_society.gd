extends "res://tests/test_happiness_spatial.gd"
const Model=preload("res://core/city_model.gd")
func town(seed_value:int):
 var city=Model.new(100,100,seed_value)
 assert(city.add_road(PackedVector2Array([Vector2(10,40),Vector2(42,40)])).ok)
 var i:=0
 for frame in city.zoning_grid.frames.values():
  if i==8:break
  city.paint_zones(city.Parcels.polygon(frame,0,0,2),"residential" if i%4<2 else ("commercial" if i%4==2 else "industrial"));i+=1
 return city
func population_state(pop)->Array:
 return [pop.people,pop.households,pop.workplaces,pop.rng.state,pop.next_person,pop.next_household,pop.elapsed_days,pop.birth_day]
func run():
 for speed in [1,2,3]:
  var city=town(88);city.happiness.enable_background();city.happiness.core.SetBackgroundGateForValidation(true)
  city.advance_society(2)
  check(city.happiness.core.BackgroundStatus().submitted==1,"one job is submitted at the first boundary")
  city.advance_utilities(2)
  city.advance_society(6*speed)
  city.advance_utilities(6*speed)
  check(city.utilities.elapsed==city.clock.game_seconds,"utility logical time never outruns the frozen clock speed="+str(speed))
  check(city.happiness.core.BackgroundStatus().submitted==1 and city.happiness.core.BackgroundStatus().published==0,"busy speed=%d never queues or publishes"%speed)
  check(city.clock.game_seconds==48 and city.society_elapsed<city.config.development_interval_seconds and city.society_frozen_cycles==3*speed,"busy cycles freeze logical time and leave no debt speed="+str(speed))
  city.happiness.core.SetBackgroundGateForValidation(false);city.happiness.suspend_background()
  check(city.happiness.core.BackgroundStatus().published==0,"joining test work is not publication")
  city.advance_society(2);city.happiness.suspend_background();city.happiness.publish_boundary()
  check(city.clock.game_seconds==96 and city.happiness.core.BackgroundStatus().published==2,"resume commits at a boundary and executes one new logical tick")
 for seed_value in [42,20261114]:
  var before=town(seed_value);var after=town(seed_value);after.happiness.enable_background()
  var exact:=true
  for tick in range(5400):
   before.advance_society(2);after.advance_society(2)
   # Functional barrier only: advance the next logical publication boundary without waiting wall time.
   after.happiness.suspend_background();after.happiness.publish_boundary();after.happiness.materialize_values(after.buildings)
   if not same(before.buildings,after.buildings) or not same(population_state(before.population),population_state(after.population)):
    print("BACKGROUND_MODEL_DIFFERENCE seed=",seed_value," tick=",tick);exact=false;break
  check(exact and before.clock.game_seconds==259200 and after.clock.game_seconds==259200,"three logical days preserve complete buildings/people/households/jobs/RNG seed="+str(seed_value))
  check(after.buildings.size()>1 and after.population.stats().population>0,"real construction and migration exercised")
  after.happiness.suspend_background()
 print("RESULT %d/%d background society checks passed"%[count-failed,count]);quit(0 if failed==0 else 1)
