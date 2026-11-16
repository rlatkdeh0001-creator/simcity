extends "D:/project/simcity/tools/validate_happiness_scenario.gd"
func run():
 setup()
 for i in range(7350):
  city.advance_utilities(2);city.advance_society(2)
  if i%300==0:await process_frame
 var levels:Array=[];var targets:Array=[];var pollution:Array=[]
 for home in homes:
  levels.append(home.level);targets.append(home.happiness_target);pollution.append(home.happiness_factors.pollution_noise)
  assert(home.has_power and home.has_water)
 assert(levels==[1,4,5] and targets==[40.0,70.0,80.0] and pollution==[-10.0,-10.0,-5.0],"approved real-supply scenario unchanged")
 print("HAPPINESS_OPTIMIZED_SCENARIO_PASS ",JSON.stringify({"levels":levels,"targets":targets,"pollution":pollution,"game_seconds":city.clock.game_seconds}))
 quit()
