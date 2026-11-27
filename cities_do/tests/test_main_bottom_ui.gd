extends SceneTree
const PLAYBACK_EXPOSURE_SECONDS := 4.125
const PLAYBACK_MAX_FRAME_SECONDS := 0.125
const GAME_SECONDS_PER_TICK := 48.0 # 2 simulation seconds × 24 game seconds/second.
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, description: String):
 checks+=1
 if value: print("PASS "+description)
 else:
  failed+=1
  push_error("FAIL "+description)
func measure_playback(game,speed:float,expected_ticks:int)->float:
 var sim=game.city.simulation
 var start_tick:int=sim.get_published_tick()
 var start_clock:float=game.city.clock.game_seconds
 var exposure:=0.0
 var deadline:=Time.get_ticks_msec()+20000 # Watchdog only; not part of exposure.
 game.simulation_speed=speed
 while exposure<PLAYBACK_EXPOSURE_SECONDS and Time.get_ticks_msec()<deadline and sim.get_fault().is_empty():
  await process_frame # Before the engine calls the game's own _process.
  var delta:float=game.get_process_delta_time()
  # Exclude worker waits so scheduler variance cannot consume a fixed step as busy.
  game.paused=delta<=0.0 or delta>PLAYBACK_MAX_FRAME_SECONDS or (sim.has_pending() and not sim.worker.IsComplete())
  if not game.paused:exposure+=delta
 await process_frame # Let the final counted frame run before reading publication.
 game.paused=true
 var published:int=sim.get_published_tick()-start_tick
 var advanced:float=game.city.clock.game_seconds-start_clock
 verify(exposure>=PLAYBACK_EXPOSURE_SECONDS and sim.get_fault().is_empty(),"%dx completed the active frame window without a worker fault: %s"%[speed,sim.get_fault()])
 verify(published==expected_ticks and advanced==expected_ticks*GAME_SECONDS_PER_TICK,"%dx normal frames published %d ticks and %d game seconds (expected %d ticks)"%[speed,published,advanced,expected_ticks])
 var unpublished:float=exposure*speed*24.0-advanced
 verify(unpublished>=0 and unpublished<GAME_SECONDS_PER_TICK,"%dx clock matches the absolute rate to within one fixed tick"%speed)
 print("PLAYBACK speed=%dx active_seconds=%.6f published_ticks=%d game_seconds=%.0f"%[speed,exposure,published,advanced])
 return advanced
func verify_playback(game):
 var sim=game.city.simulation
 var deadline:=Time.get_ticks_msec()+10000
 while not sim.is_ready() and sim.get_fault().is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 verify(sim.is_ready(),"main worker is ready for playback: "+sim.get_fault())
 if not sim.is_ready():return
 var before:float=game.city.clock.game_seconds
 var tick_before:int=sim.get_published_tick()
 game._process(2.0)
 verify(game.city.clock.game_seconds==before and sim.get_published_tick()==tick_before and not sim.has_pending(),"main pause freezes the unified clock and submits no tick")
 game.paused=false
 game.simulation_speed=2.0
 sim.worker.SetValidationGate(true)
 game._process(0.75)
 verify(not sim.has_pending(),"2x does not submit before one real second")
 game._process(0.25)
 verify(sim.has_pending() and not sim.worker.IsComplete() and sim.get_published_tick()==tick_before and game.city.clock.game_seconds==before,"2x submits one held tick without advancing unpublished time")
 game.paused=true
 sim.worker.SetValidationGate(false)
 var old_max_fps:=Engine.max_fps
 Engine.max_fps=64
 # Both windows end in [4.125, 4.25] active seconds. Starting with one queued
 # tick, they cross exactly 4 and 6 publication boundaries; even the combined
 # simulated overshoot (2*0.25 + 3*0.25) is less than the 2-second tick.
 var at_2x:float=await measure_playback(game,2.0,4)
 var at_3x:float=await measure_playback(game,3.0,6)
 Engine.max_fps=old_max_fps
 verify(at_2x>0 and at_3x*2.0==at_2x*3.0,"3x publishes exactly 1.5x the 2x game time over the same active-frame window")
func run():
 var game=load("res://main.tscn").instantiate()
 game.paused=true # Frame advances must come from the explicit playback fixture below.
 root.add_child(game)
 current_scene=game
 await process_frame
 await process_frame
 verify(game.has_method("select_category"),"default main scene provides the shared bottom HUD")
 if game.has_method("select_category"):
  verify(game.categories.size()==11,"main has eleven categories")
  verify(game.city.buildings.is_empty() and game.city.roads.is_empty(),"main preserves empty starting city instead of preview fixture")
  verify(not game.show_zoning_tiles(),"main starts with placement grid hidden before choosing a category")
  verify(game.has_method("service_slots"),"service slots are loaded from separate data")
  if game.has_method("service_slots"):
   var slots: Array=game.service_slots()
   verify(slots.size()==7,"seven confirmed slots exist")
   var expected := {"fire":["fire.small","fire.standard","fire.regional"],"police":["police.small","police.standard","police.headquarters","police.prison"]}
   var before := JSON.stringify(game.city.buildings)+JSON.stringify(game.city.roads)+str(game.city.funds)+str(game.city.clock.game_seconds)
   for category in expected:
    game.select_category(category)
    var buttons: Array= game.drawer_box.get_children().filter(func(n):return n is Button and n.name.begins_with("Slot_"))
    verify(buttons.size()==expected[category].size(),category+" has exact slot count")
    for id in expected[category]:
     var matches := slots.filter(func(s):return s.id==id and s.category==category)
     verify(matches.size()==1 and matches[0].status=="ready" and not str(matches[0].asset).is_empty(),id+" is ready with a real spec path")
     var match_buttons: Array= buttons.filter(func(b):return b.get_meta("slot_id")==id)
     verify(match_buttons.size()==1 and not match_buttons[0].disabled,id+" inspector button is enabled")
     if match_buttons.size()==1:
      verify(match_buttons[0].has_meta("thumbnail_asset_id") and match_buttons[0].get_node_or_null("NameBand/AssetName")!=null,id+" uses the real PNG C card and name band")
     verify(not game.slot_asset(matches[0]).is_empty(),id+" resolves real geometry metadata")
   var after := JSON.stringify(game.city.buildings)+JSON.stringify(game.city.roads)+str(game.city.funds)+str(game.city.clock.game_seconds)
   verify(before==after,"asset browsing preserves city, funds and clock")
   verify(game.slot_asset({"status":"pending_asset","asset":slots[0].asset}).is_empty(),"pending status remains fail-closed even with a populated path")
  game.select_category("road")
  var lane_counts:Array=game.road_lane_cards.map(func(card):return card.get_meta("lanes"))
  verify(lane_counts==[2,3,4,5,6,7,8] and game.drawer_box.find_children("RoadLanes","OptionButton",true,false).is_empty() and game.road_grid_button!=null,"bottom road tools expose the approved 2–8 lane cards and grid toggle instead of the old selector")
  var zoom_before: float=game.map_zoom
  var origin_before: Vector2=game.origin
  game.select_category("fire")
  verify(game.map_zoom==zoom_before and game.origin==origin_before,"tab changes never reset the player camera")
  game.select_category("build")
  verify(game.drawer_box.find_children("Tool_reset","Button",true,false).is_empty(),"city reset button removed without removing reset logic")
  verify(game.drawer_box.find_children("Tool_upgrade","Button",true,false).is_empty(),"manual building growth button removed without removing growth logic")
  verify(game.find_children("PowerTabButton","Button",true,false).is_empty(),"main never creates the legacy side buttons")
  game.paused=true
  for size_value in [Vector2i(1920,1080),Vector2i(1280,820),Vector2i(960,640)]:
   root.size=size_value
   await process_frame
   await process_frame
   var viewport_rect := root.get_visible_rect()
   verify(absf(game.dock.get_global_rect().end.y-viewport_rect.end.y)<2,"main dock anchored at "+str(size_value))
   verify(viewport_rect.encloses(game.bulldozer.get_global_rect()),"rightmost bulldozer remains inside "+str(size_value))
   for key in game.NAMES:
    game.select_category(key)
    await process_frame
    await process_frame
    verify(viewport_rect.encloses(game.drawer.get_global_rect()),key+" drawer fits "+str(size_value))
   for tooltip in ["일시정지 / 재개","도시 전체 보기","도구 모음 접기 / 펼치기"]:
    var controls: Array=game.find_children("*","Button",true,false).filter(func(b):return b.tooltip_text==tooltip)
    verify(controls.size()==1 and viewport_rect.encloses(controls[0].get_global_rect()),tooltip+" remains reachable at "+str(size_value))
   game.categories[0].grab_focus()
   for i in range(11):
    verify(root.gui_get_focus_owner()==game.categories[i],"keyboard traverses category %d at %s" % [i,size_value])
    var right := InputEventAction.new()
    right.action="ui_right"
    right.pressed=true
    root.push_input(right)
    right.pressed=false
    root.push_input(right)
    await process_frame
   verify(root.gui_get_focus_owner()==game.categories[0],"keyboard wraps eleven categories at "+str(size_value))
  game.select_category("road")
  game.drawing=true
  game.stroke=PackedVector2Array([Vector2(2,2),Vector2(10,2)])
  game.select_category("fire")
  verify(not game.drawing and game.stroke.is_empty(),"changing tabs cancels an unfinished road before release")
  for kind in ["power","water"]:
   game.select_category(kind)
   var settings: Array=game.drawer_box.find_children("Tool_"+kind+"_settings","Button",true,false)
   verify(settings.is_empty(),kind+" settings button absent from player HUD")
   game.open_utility_settings(kind) # Internal test fixture only; no player-facing button.
   verify(game.utility_popup.visible,kind+" internal settings helper preserved")
   var overlay=game.power_overlay if kind=="power" else game.water_overlay
   verify(game.utility_popup.is_ancestor_of(overlay.output),kind+" internal helper still owns actual capacity input")
   game.utility_popup.hide()
   verify(not overlay.panel.visible and overlay.panel.is_ancestor_of(overlay.output),kind+" internal close restores hidden control owner")
  game.select_category("fire")
  var escape := InputEventKey.new()
  escape.keycode=KEY_ESCAPE
  escape.pressed=true
  game._unhandled_key_input(escape)
  verify(not game.drawer.visible,"main Escape collapses drawer")
  await verify_playback(game)
  verify(game.population_label.text==str(game.city.population.stats().population) and "년" in game.date_label.text,"main status exposes actual population and date")
 game.queue_free()
 await process_frame
 print("RESULT %d/%d main bottom UI checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
