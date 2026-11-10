extends SceneTree
var checks := 0
var failed := 0
func _initialize(): run.call_deferred()
func verify(value: bool, description: String):
 checks+=1
 if value: print("PASS "+description)
 else:
  failed+=1
  push_error("FAIL "+description)
func run():
 var game=load("res://main.tscn").instantiate()
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
  verify(game.drawer_box.find_children("RoadLanes","OptionButton",true,false).size()==1,"bottom road tools expose existing lane width choice")
  var zoom_before: float=game.map_zoom
  var origin_before: Vector2=game.origin
  game.select_category("fire")
  verify(game.map_zoom==zoom_before and game.origin==origin_before,"tab changes never reset the player camera")
  game.select_category("build")
  verify(game.drawer_box.find_children("Tool_reset","Button",true,false).size()==1,"city reset remains reachable from the bottom tools")
  verify(game.drawer_box.find_children("Tool_upgrade","Button",true,false).size()==1,"existing selected-building upgrade remains reachable")
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
   verify(settings.size()==1,kind+" retains existing output and display controls in a bottom-launched popup")
   if settings.size()==1:
    settings[0].pressed.emit()
    verify(game.utility_popup.visible,kind+" settings popup opens")
    var overlay=game.power_overlay if kind=="power" else game.water_overlay
    verify(game.utility_popup.is_ancestor_of(overlay.output),kind+" popup uses the actual existing capacity input")
    game.utility_popup.hide()
    verify(not overlay.panel.visible and overlay.panel.is_ancestor_of(overlay.output),kind+" settings close returns controls to hidden owner")
  game.select_category("fire")
  var escape := InputEventKey.new()
  escape.keycode=KEY_ESCAPE
  escape.pressed=true
  game._unhandled_key_input(escape)
  verify(not game.drawer.visible,"main Escape collapses drawer")
  var clock_before: float=game.city.clock.game_seconds
  game._process(1)
  verify(game.city.clock.game_seconds==clock_before,"main pause freezes unified clock")
  game.paused=false
  game.simulation_speed=3
  game._process(1)
  verify(is_equal_approx(game.city.clock.game_seconds-clock_before,72),"main 3x uses existing clock conversion")
  verify(game.population_label.text==str(game.city.population.stats().population) and "년" in game.date_label.text,"main status exposes actual population and date")
 game.queue_free()
 await process_frame
 print("RESULT %d/%d main bottom UI checks passed" % [checks-failed,checks])
 quit(1 if failed else 0)
