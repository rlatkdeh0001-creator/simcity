extends "D:/project/simcity/tools/validate_happiness_scenario.gd"
func run():
 setup();city.happiness.enable_background()
 for i in range(7350):
  # Match the authored scenario's utility-before-society order at logical boundaries.
  city.happiness.publish_boundary()
  city.advance_utilities(2);city.advance_society(2)
  city.happiness.suspend_background()
  if i%300==0:await process_frame
 city.happiness.publish_boundary();city.happiness.materialize_values(homes)
 var levels:Array=[];var targets:Array=[];var pollution:Array=[]
 for home in homes:
  levels.append(home.level);targets.append(home.happiness_target);pollution.append(home.happiness_factors.pollution_noise)
  assert(home.has_power and home.has_water)
 assert(levels==[1,4,5] and targets==[40.0,70.0,80.0] and pollution==[-10.0,-10.0,-5.0],"real-supply background scenario unchanged")
 print("HAPPINESS_BACKGROUND_SCENARIO_PASS ",JSON.stringify({"levels":levels,"targets":targets,"pollution":pollution,"game_seconds":city.clock.game_seconds,"logical_ticks":city.happiness.core.BackgroundStatus().published}))
 city.happiness.suspend_background();quit()
