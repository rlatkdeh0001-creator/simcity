extends SceneTree
## E4c §8.3. Exercise main.tscn with real viewport events, including the four capture compositions.
## --fixture-check always wins over --e4c-capture-dir=... and never reads the framebuffer.
const City = preload("res://core/city_model.gd")
const Height = preload("res://core/road_height.gd")
const Units = preload("res://core/road_length_units.gd")
const SIZE := Vector2i(1920, 1080)
const SMALL := Vector2i(1280, 820)
const EPS := 0.001
const CAPTURES := {
 "4lane": "e4c-flyover-4lane-1920.png",
 "split": "e4c-split-closeup-1920.png",
 "8lane": "e4c-flyover-8lane-1920.png",
 "warning": "e4c-preview-warning-1920.png",
}
var game
var checks := 0
var failures := 0
var destination := ""
var frames: Dictionary = {}

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, label: String) -> bool:
 checks += 1
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ", label)
 return ok

func settle(count := 3) -> void:
 for i in range(count): await process_frame

func node_named(value: String) -> Control:
 return game.find_child(value, true, false) as Control

func move_mouse(p: Vector2) -> void:
 var event := InputEventMouseMotion.new()
 event.position = p; event.global_position = p
 root.push_input(event, true)

func mouse_button(p: Vector2, down: bool, which: MouseButton) -> void:
 var event := InputEventMouseButton.new()
 event.position = p; event.global_position = p; event.button_index = which; event.pressed = down
 event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and which == MOUSE_BUTTON_LEFT else 0
 root.push_input(event, true)

func gesture(p: Vector2, which := MOUSE_BUTTON_LEFT) -> void:
 # Stationary motion/press/release without a native cursor update between events.
 move_mouse(p)
 mouse_button(p, true, which)
 mouse_button(p, false, which)
 await settle()

func key(code: Key) -> void:
 for down: bool in [true, false]:
  var event := InputEventKey.new()
  event.keycode = code; event.physical_keycode = code; event.pressed = down
  root.push_input(event, true)
 await settle()

func press(control: Control, label: String) -> bool:
 if not check(is_instance_valid(control) and control.is_visible_in_tree(), label + " control is visible"): return false
 var p := control.get_global_rect().get_center()
 move_mouse(p)
 var hovered := root.gui_get_hovered_control()
 if not check(root.get_visible_rect().has_point(p) and (hovered == control or (hovered != null and control.is_ancestor_of(hovered))), label + " owns its viewport click target"): return false
 await gesture(p)
 return true

func screen_at(p: Vector2, height := 0.0) -> Vector2:
 return game.screen(p) - Vector2(0, height * game.tile.x / 4 * sqrt(1.5) * game.map_zoom)

func unobstructed(p: Vector2) -> bool:
 if not root.get_visible_rect().has_point(p): return false
 for panel: Control in [game.drawer, game.dock, game.road_modes]:
  if panel.is_visible_in_tree() and panel.get_global_rect().has_point(p): return false
 return true

func map_input(p: Vector2, height := 0.0, click := true) -> bool:
 var pos := screen_at(p, height)
 move_mouse(pos)
 if not check(unobstructed(pos) and root.gui_get_hovered_control() == null, "projected map target clears HUD: %s at %.3f m -> %s" % [p, height, pos]): return false
 if click: await gesture(pos)
 else: await settle()
 return true

func center_name(lanes: int) -> String:
 return "RoadCenter_%d" % lanes

func open_roads() -> bool:
 if not game.drawer.visible or game.chosen != "road":
  if not await press(node_named("Bottom_road"), "road category"): return false
 return check(node_named("RoadCardStrip") != null and game.drawer.visible, "production horizontal road strip is open")

func pick_road(name: String) -> bool:
 if not await open_roads(): return false
 var card := node_named(name) as Button
 var strip := node_named("RoadCardStrip") as ScrollContainer
 if not check(card != null and strip.get_node("Cards").is_ancestor_of(card), name + " lives in the original strip"): return false
 var bar := strip.get_h_scroll_bar()
 var visible := strip.get_global_rect()
 if bar.visible: visible.size.y -= bar.size.y
 var zoom: float = game.map_zoom
 for i in range(24):
  if visible.grow(1).encloses(card.get_global_rect()): break
  var direction := MOUSE_BUTTON_WHEEL_DOWN if card.global_position.x >= visible.position.x else MOUSE_BUTTON_WHEEL_UP
  var last := strip.scroll_horizontal
  await gesture(visible.get_center(), direction)
  if strip.scroll_horizontal == last: break
 if not check(visible.grow(1).encloses(card.get_global_rect()) and game.map_zoom == zoom, name + " scrolls fully into view without map zoom"): return false
 if not await press(card, name): return false
 return check(card.button_pressed and card.has_focus() and game.mode == "road" and game.road_drawer.anchors.is_empty() and game.road_lanes == card.get_meta("lanes"), name + " takes focus and begins a fresh stroke")

func grid_off() -> bool:
 if game.road_grid_enabled and not await press(node_named("RoadGridToggle"), "grid toggle"): return false
 return check(not game.road_grid_enabled, "road grid is OFF through the viewport control")

func height_is(value: float) -> bool:
 var text := "0 m" if value == 0 else ("+%d m" % value if value > 0 else "−%d m" % -value)
 return game.road_drawer.target_height_m == value and (node_named("HeightValue") as Label).text == text

func check_cards_and_controls() -> void:
 if not await open_roads(): return
 var cards: Array = node_named("RoadCardStrip").get_node("Cards").get_children()
 var expected: Array[String] = []
 for lanes in range(2,9): expected.append("%d차선" % lanes)
 for lanes in range(1,5): expected.append("편도 %d차로" % lanes)
 for lanes in [4,6,8]: expected.append("중앙 %d차선" % lanes)
 if not check(cards.map(func(card): return card.tooltip_text) == expected, "seven ordinary and four one-way cards preserved; exactly three central cards appended"): return
 for lanes: int in [4,6,8]:
  if not await pick_road(center_name(lanes)): return
  var card := node_named(center_name(lanes)) as Button
  var caption: Control = card.get_node_or_null("NameBand/AssetName") as Control
  if caption == null: caption = card
  var title := "중앙 %d차선" % lanes
  var available := caption.size.x - (card.get_theme_stylebox("normal").get_minimum_size().x if caption == card else 0.0)
  var font_size := caption.get_theme_font_size("font_size")
  check(caption.get("text") == title and font_size >= 18 and caption.get_theme_font("font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available + EPS, "central caption is exact and untruncated at >=18px: " + title)
  check(card.get_meta("source_preview") == "res://assets/ui/roads/center-%d.png" % lanes, "central card only refers to its own studio thumbnail")
  var art := card.get_node_or_null("AssetThumbnail") as TextureRect
  if FileAccess.file_exists(card.get_meta("source_preview")):
   check(art != null and art.texture != null, "delivered studio thumbnail loads for " + title)
  else: check(art == null, "no borrowed image while studio render is pending")
 var allowed := expected.duplicate()
 allowed.append_array(["도로", "지하", "지상", "고가", "−", "+", "0 m", "⌄", "⌃", "▾", "▴", "˅", "∨", "닫기"])
 var extra: Array = []
 for c in game.drawer_box.find_children("*", "Control", true, false):
  if c.is_visible_in_tree() and (c is Label or c is Button) and not c.text.is_empty() and c.text not in allowed: extra.append(c.text)
 check(extra.is_empty(), "temporary controls add no instructional/development copy: " + str(extra))
 if not await press(node_named("RoadMode_curve"), "existing curve mode") or not await grid_off(): return
 if not await pick_road("RoadLane_4"): return
 if not await press(node_named("Elevated"), "ordinary elevated button"): return
 await key(KEY_PAGEUP)
 check(height_is(15), "ordinary card retains five-metre PgUp")
 if not await map_input(Vector2(54,75), 15): return
 check(game.road_drawer.anchors.size() == 1, "ordinary stroke has an anchor before switching tools")
 if not await pick_road(center_name(6)): return
 check(height_is(0) and game.road_drawer.start_height_m == 0 and game.road_drawer.kind == "curve" and not game.road_grid_enabled, "central card clears raised stroke while keeping curve and grid preferences")
 await key(KEY_PAGEDOWN)
 check(height_is(0) and not game.transit_view.underground, "central PgDn cannot enter underground from ground")
 await key(KEY_PAGEUP)
 check(height_is(10), "central PgUp jumps from ground to +10m")
 await key(KEY_PAGEUP)
 check(height_is(10), "central PgUp is capped at +10m")
 for name in ["Underground", "HeightMinus", "HeightPlus"]:
  var button := node_named(name) as Button
  if not check(button != null and button.disabled and button.self_modulate != Color.WHITE, name + " is disabled and dimmed in central mode"): return
  # A disabled Godot button should ignore real input and forced signals alike.
  await gesture(button.get_global_rect().get_center())
  check(height_is(10), name + " does not act on a real click")
  button.pressed.emit()
  check(height_is(10), name + " forced signal cannot modify the central height")
 await key(KEY_PAGEDOWN)
 check(height_is(0), "central PgDn returns directly to ground")
 if not await press(node_named("Elevated"), "central elevated button"): return
 check(height_is(10), "central elevated button selects +10m")
 if not await press(node_named("Ground"), "central ground button"): return
 check(height_is(0), "central ground button selects 0m")
 if not await press(node_named("RoadMode_straight"), "existing straight mode"): return
 var first := Vector2(50.25,75.25)
 var last := first + Vector2(18,0)
 if not await stroke(first,last,0,0): return
 check(game.city.roads.size() == 1 and not Height.off_ground(game.city.roads[0]) and game.city.roads[0].lanes == 6 and not game.city.roads[0].has("center_role"), "D13 yields one regular flat six-lane road")
 if not await pick_road("RoadOneWay_2"): return
 await key(KEY_PAGEUP)
 check(height_is(0) and (node_named("Elevated") as Button).disabled, "one-way remains ground-only")
 if not await pick_road("RoadLane_4"): return
 if not await press(node_named("Underground"), "ordinary underground button"): return
 check(height_is(-10) and game.transit_view.underground, "ordinary underground operation is restored")
 # The height widget is shared with rail. Actual transport tab + tool input is
 # the positive control that the road-specific restrictions didn't leak there.
 if not await press(node_named("Bottom_transport"), "transport category"): return
 if not await press(game.transport_tabs.get_child(2) as Control, "train tab"): return
 if not await press(node_named("Tool_rail"), "rail tool"): return
 var rail := node_named("RailHeightControls")
 if not check(rail != null, "train tab exposes its own height controls"): return
 if not await press(rail.find_child("Underground",true,false) as Control, "rail underground button"): return
 if not check(game.transit_view.target_height_m == -10 and game.transit_view.underground, "rail retains its underground button"): return
 if not await press(rail.find_child("HeightPlus",true,false) as Control, "rail five-metre plus"): return
 check(game.transit_view.target_height_m == -5 and game.transit_view.underground, "rail retains its own five-metre layer adjustment")

func new_game(size: Vector2i) -> bool:
 if is_instance_valid(game): game.free()  # main._exit_tree owns the live worker
 if DisplayServer.get_name() == "headless": root.size = size
 game = load("res://main.tscn").instantiate()
 game.city = City.new(160,160,20261127)
 game.city.funds = 1000000
 game.city.population_enabled = false
 game.city.happiness_enabled = false
 game.paused = true
 root.add_child(game)
 current_scene = game
 await settle(8)
 return check(root.size == size, "actual root viewport size %s" % size)

func frame_on(world: Vector2, screen: Vector2, zoom: float) -> void:
 game.map_zoom = zoom
 game.origin = Vector2.ZERO
 game.origin = screen - screen_at(world)
 game.refresh()
 await settle()

func aim_stroke(a: Vector2, b: Vector2, from_height: float, to_height: float, continued := false) -> Dictionary:
 var before := var_to_bytes(game.city.roads)
 if not continued and not await map_input(a, from_height): return {}
 if not check(game.road_drawer.anchors.size() == 1 and game.road_drawer.anchors[0].distance_to(a) < EPS and game.road_drawer.start_height_m == from_height and var_to_bytes(game.city.roads) == before, "first viewport click preserves the exact grid-off anchor without editing"): return {}
 # Move off the anchor before changing the target layer.
 if not await map_input(b, from_height, false): return {}
 if to_height != from_height: await key(KEY_PAGEUP if to_height > from_height else KEY_PAGEDOWN)
 if not check(height_is(to_height), "keyboard chooses the requested endpoint layer"): return {}
 if not await map_input(b, to_height, false): return {}
 var plan: Dictionary = game.road_drawer.preview()
 var points: PackedVector2Array = plan.get("points", PackedVector2Array())
 if not check(plan.get("ok", false) and points.size() >= 2 and points[0].distance_to(a) < EPS and points[-1].distance_to(b) < EPS, "live resolved preview keeps both endpoints: " + str(plan.get("reason", ""))): return {}
 return plan

func stroke(a: Vector2, b: Vector2, from_height: float, to_height: float, continued := false) -> bool:
 var plan := await aim_stroke(a,b,from_height,to_height,continued)
 if not check(not plan.is_empty() and not plan.get("warning", false), "stroke is ready to commit without a warning"): return false
 var revision: int = game.city.road_topology_revision
 if not await map_input(b,to_height): return false
 if not check(game.city.road_topology_revision == revision+1 and game.road_drawer.last_result.get("ok", false) and game.road_drawer.anchors.size() == 1 and game.road_drawer.anchors[0].distance_to(b) < EPS, "endpoint click commits the preview once and continues at the exact endpoint: " + str(game.road_drawer.last_result.get("reason", ""))): return false
 if plan.get("center_tool",false) and (from_height != 0 or to_height != 0):
  var members: Array = plan.get("center_preview", [])
  var same_geometry := true
  for member: Dictionary in members:
   same_geometry = same_geometry and not member.ribbon_polygons.is_empty() and has_member_geometry(member.road)
  if not check(members.size() == 3 and same_geometry, "all three production preview ribbons use the geometry that the same viewport gesture committed"): return false
 return true

func has_member_geometry(member:Dictionary) -> bool:
 for road: Dictionary in game.city.roads:
  if road.points == member.points and road.get("heights_m", []) == member.get("heights_m", []) and road.width == member.width and road.get("center_role",-1) == member.get("center_role",-1): return true
 return false

func road_id(road: Dictionary) -> int:
 return int(road.parcel_id)

func projected_rect(world: Rect2) -> Rect2:
 return Rect2(game.origin + world.position*game.map_zoom, world.size*game.map_zoom)

func clear_rect(rect: Rect2) -> bool:
 if not rect.has_area() or not root.get_visible_rect().encloses(rect): return false
 for panel: Control in [game.drawer, game.dock, game.road_modes]:
  if panel.is_visible_in_tree() and panel.get_global_rect().intersects(rect): return false
 return true

func seed_moving_cars(center: Dictionary, sides: Array) -> bool:
 if not check(game.traffic.rebuild(game.city.roads), "real traffic lane graph builds from the viewport-authored corridor"): return false
 var sim = game.traffic.simulation
 var catalog: Array = game.traffic.catalog.filter(func(a): return a.id == "car-hatch-01")
 if not check(not catalog.is_empty(), "production hatchback asset is present"): return false
 var vehicles: Array[Dictionary] = []
 var roads: Array = [center] + sides
 for road: Dictionary in roads:
  # Pick a real baked lane near the deck plateau (or the side road past its X).
  var raised := Height.raised(road)
  var target := Vector2(69.5,75) if raised else Vector2(78,Height.point_at(road.points,Height.length_cells(road.points)*.5).y)
  var index: int = game.city.roads.find(road)
  var best: Dictionary = {}
  var best_distance := INF
  for lane: Dictionary in game.traffic.network.lanes:
   if lane.road != index: continue
   for progress in range(4, floori(lane.length)-10):
    var p: Vector2 = game.traffic.network.sample(lane.id,progress)/4
    if raised and Height.height_at(road,p) < 10-EPS: continue
    var distance := p.distance_to(target)
    if distance < best_distance:
     best_distance = distance; best = {"lane":lane.id,"progress":progress}
  if not check(not best.is_empty(), "real lane has room for moving vehicle on road %d" % road_id(road)): return false
  var car: Dictionary = sim.spawn(catalog[0], [best.lane], best.progress)
  if not check(not car.is_empty(), "traffic simulation spawns on the selected production lane"): return false
  vehicles.append(car)
 for i in range(30): sim.update(1.0/30)
 sim.paused = true
 await settle()
 for i in range(vehicles.size()):
  var car := vehicles[i]
  var sprite: Sprite2D = game.world_renderer.cars.get(car.id)
  var raised := i == 0
  if not check(car.distance > .5 and car.speed > 0 and sprite != null and sprite.is_visible_in_tree() and sprite.texture != null, "real vehicle advances and has a retained sprite"): return false
  var drawn := sprite.get_global_transform() * sprite.get_rect()
  var art: Rect2 = game.traffic.sprite_rect(car.asset_id,Vector2.ZERO,game.tile.x/4*sqrt(2.0))
  var expected := screen_at(sim.position(car)/4,10.0 if raised else 0.0) + art.position*float(game.map_zoom)
  if not check(drawn.position.distance_to(expected) < .01 and clear_rect(drawn), "actual vehicle sprite has unobstructed %s projection" % ("deck" if raised else "branch")): return false
 return true

func verify_structure(center: Dictionary, expected_supports: int) -> bool:
 var saw_deck := false
 var columns := {}
 var support_bounds: Array = []
 for piece in game.world_renderer.elevated.nodes:
  if not piece.road.get("source_ids", [piece.road.get("parcel_id", -1)]).has(road_id(center)): continue
  if piece.commands.is_empty(): continue
  var rect := projected_rect(piece.world_bounds)
  if piece.footprint.size() == 1 and piece.commands.size() == 3 and piece.commands.all(func(command): return command.has("texture") and command.has("rect")):
   support_bounds.append([piece.footprint[0], rect, piece.visible])
   if piece.visible and clear_rect(rect): columns[piece.footprint[0]] = true
  if piece.visible and piece in game.world_renderer.elevated.decks and absf(piece.height_m-10) < EPS and clear_rect(rect): saw_deck = true
 var sample := false
 for station: Dictionary in center.get("piers", []):
  if absf(float(station.height_m)-10) >= EPS or station.positions.size() != expected_supports: continue
  if not Array(station.positions).all(func(point): return columns.has(point)): continue
  if expected_supports == 1: sample = absf(station.positions[0].y-75) < EPS or sample
  else:
   var offsets: Array = Array(station.positions).map(func(p): return p.y-75)
   offsets.sort()
   sample = (absf(offsets[0]+1) < EPS and absf(offsets[1]-1) < EPS) or sample
 if not saw_deck or not sample: print("E4C support bounds: ", support_bounds)
 return check(saw_deck and sample, "live retained renderer has visible plateau pieces and all %d textured columns of one planned plateau station" % expected_supports)

func flyover(lanes: int) -> void:
 if not await new_game(SIZE): return
 var a := Vector2(30,75)
 var b := Vector2(74,75)
 var c := Vector2(110,75)
 await frame_on(Vector2(70,75),Vector2(960,400),1)
 if not await pick_road("RoadLane_%d" % lanes) or not await grid_off(): return
 if not await stroke(Vector2(22,75),a,0,0): return
 if not await pick_road(center_name(lanes)) or not await stroke(a,b,0,10) or not await stroke(b,c,10,0,true): return
 if not await pick_road("RoadLane_%d" % lanes) or not await stroke(c,Vector2(118,75),0,0): return
 var raised: Array = game.city.roads.filter(func(r): return Height.raised(r))
 var sides: Array = game.city.roads.filter(func(r): return int(r.get("travel_dir",0)) != 0 and not Height.off_ground(r))
 if not check(not raised.is_empty() and sides.size() >= 2 and game.city.junctions.is_empty(), "central corridor has an independent deck and both ground branches without a controlled split"): return
 var center: Dictionary = {}
 for road: Dictionary in raised:
  if float(Units.projection(road.points,Vector2(70,75)).distance) < EPS and absf(Height.height_at(road,Vector2(70,75))-10) < EPS:
   center = road; break
 if not check(not center.is_empty() and absf(float(center.width)*4-(8 if lanes == 4 else 16)) < EPS, "crossing lies under the actual +10m plateau of the correct width"): return
 # Select the actual sides that the planned 0m crossing hits, not the continuation records.
 var sides_at_cross: Array = sides.filter(func(r): return float(Units.projection(r.points,Vector2(70,75)).distance) < 4 and r.points[0].x != r.points[-1].x and 70.0 >= minf(r.points[0].x,r.points[-1].x) and 70.0 <= maxf(r.points[0].x,r.points[-1].x))
 if not check(sides_at_cross.size() == 2 and sides_at_cross.all(func(r): return absf(float(r.width)*4-(6 if lanes == 4 else 8)) < EPS), "two correct-width branch records cross the plateau station"): return
 if not await pick_road("RoadLane_2") or not await stroke(Vector2(70,57),Vector2(70,93),0,0): return
 var crossings: Array = game.city.junctions.duplicate()
 if not check(crossings.size() == 2 and absf(crossings[0].position.distance_to(crossings[1].position)*4-(14 if lanes == 4 else 24)) < EPS and crossings.all(func(j): return absf(float(j.get("height_m",0))) < EPS), "viewport-authored two-way crossing creates exactly two at-grade junctions"): return
 var cross: Dictionary = game.city.roads[-1]
 await key(KEY_ESCAPE)
 if game.drawer.visible and not await press(game.drawer_box.get_child(-1) as Control, "close build tray"): return
 move_mouse(Vector2(200,390)); await settle()
 if not verify_structure(center,1 if lanes == 4 else 2) or not await seed_moving_cars(center,sides_at_cross): return
 await remember("4lane" if lanes == 4 else "8lane")
 if lanes == 4:
  await frame_on(Vector2(35,75),Vector2(960,360),2.4)
  if not check(unobstructed(screen_at(a)) and unobstructed(screen_at(Vector2(34,75))) and unobstructed(screen_at(Vector2(50,75),5)), "split close-up exposes seam, ramp onset and the +5m structure transition"): return
  await remember("split")
  await frame_on(Vector2(70,75),Vector2(960,400),1)
  if not await press(game.bulldozer, "existing bulldozer"): return
  var point := Vector2(71.5,75)
  if not await map_input(point,10,false): return
  var pick: Dictionary = game.demolition_hover
  var cuts: Array = pick.get("selection", {}).get("cuts", [])
  var id := road_id(center)
  if not check(not cuts.is_empty() and cuts.all(func(cut): return int(cut.id) == id), "drawn deck hover selects only its stable road ID"): return
  var kept: Array = sides_at_cross + [cross]
  if not await map_input(point,10): return
  check(game.city.roads.all(func(r): return road_id(r) != id) and kept.all(func(r): return r in game.city.roads), "deck click demolishes only the center; both branches and crossing survive")

func warning_fixture() -> void:
 if not await new_game(SIZE): return
 await frame_on(Vector2(55,75),Vector2(960,360),1)
 var host: Dictionary = game.city.add_road(PackedVector2Array([Vector2(46,79.5),Vector2(64,79.5)]))
 var target: Dictionary = game.city.add_building_at(Vector2(56,77))
 var control: Dictionary = game.city.add_building_at(Vector2(56,82))
 if not check(host.ok and target.get("ok", false) and control.get("ok", false) and game.city.buildings.size() == 2, "warning setup has real frontage and two legally placed private lots: %s / %s" % [target,control]): return
 var target_id: int = game.city.buildings[0].id
 var control_id: int = game.city.buildings[1].id
 game.refresh(); await settle()
 if not await pick_road(center_name(4)) or not await grid_off(): return
 var first := Vector2(30.25,75.25)
 var last := Vector2(74.25,75.25)
 var before := var_to_bytes([game.city.roads,game.city.buildings,game.city.next_road_id,game.city.road_topology_revision])
 for action: String in ["Cancel", "Confirm"]:
  var plan := await aim_stroke(first,last,0,10)
  if not check(plan.get("warning", false) and Array(plan.get("demolish_ids", [])) == [target_id] and plan.get("center_preview", []).size() == 3 and game.road_drawer.preview_colors(true,true).outline == Color("e6c442"), "yellow plan resolves three real draw pieces and only the in-footprint private building"): return
  if not await map_input(last,10): return
  var panel := node_named("RoadDemolitionWarning")
  if not check(panel != null and panel.is_visible_in_tree() and clear_rect(panel.get_global_rect()) and var_to_bytes([game.city.roads,game.city.buildings,game.city.next_road_id,game.city.road_topology_revision]) == before, "real warning B opens at the exact endpoint without applying the edit"): return
  var badge := panel.find_child("DemolitionCount",true,false) as Label
  if not check(badge != null and badge.text == "1" and panel.find_children("*", "Label", true, false).any(func(l): return l.text == "⚠ 이미 지어진 건물이 파괴됩니다"), "warning preserves approved text and actual affected lot count"): return
  var sprite: Sprite2D = game.world_renderer.buildings.get(target_id)
  if not check(sprite != null and sprite.modulate != Color.WHITE and clear_rect(projected_rect(sprite.get("world_bounds"))), "actual target art is visibly tinted and unobstructed"): return
  if action == "Confirm": await remember("warning")
  if not await press(panel.find_child(action,true,false) as Control, "warning " + action): return
  if not check(node_named("RoadDemolitionWarning") == null, "warning closes after " + action): return
  if action == "Cancel":
   if not check(var_to_bytes([game.city.roads,game.city.buildings,game.city.next_road_id,game.city.road_topology_revision]) == before and sprite.modulate == Color.WHITE, "cancel changes no roads, IDs or lots and clears tint"): return
   if not await pick_road(center_name(4)): return
  else:
   check(game.city.roads.size() == 4 and plan.new_roads.all(has_member_geometry) and game.city.find_building(target_id).is_empty() and not game.city.find_building(control_id).is_empty() and game.message.is_empty(), "confirm commits the exact three preview pieces and removes only the approved target, without success copy")

func configure_capture() -> bool:
 var args := OS.get_cmdline_user_args()
 if "--fixture-check" in args: return true
 for arg in args:
  if not arg.begins_with("--e4c-capture-dir="): continue
  if not check(destination.is_empty(), "one capture directory at most"): return false
  destination = arg.trim_prefix("--e4c-capture-dir=")
  if not check(destination.is_absolute_path() and DirAccess.dir_exists_absolute(destination), "capture directory must already exist and be absolute"): return false
 if destination.is_empty(): return true
 if not check(DisplayServer.get_name() != "headless" and DisplayServer.window_get_size() == SIZE and RenderingServer.get_current_rendering_method() == "gl_compatibility" and RenderingServer.get_current_rendering_driver_name() == "opengl3", "actual native 1920x1080 OpenGL Compatibility capture"): return false
 return fresh_destinations()

func fresh_destinations() -> bool:
 for name: String in CAPTURES.values():
  var path := destination.path_join(name)
  if not check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path), "capture destination is fresh: " + path): return false
 return true

func remember(tag: String) -> void:
 if destination.is_empty() or failures > 0: return
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 if check(image != null and image.get_size() == SIZE, "raw frame dimensions: " + tag): frames[tag] = image

func run() -> void:
 if configure_capture():
  var small := "--small-controls" in OS.get_cmdline_user_args() and destination.is_empty()
  var ui_size := SMALL if small else SIZE
  if await new_game(ui_size):
   await frame_on(Vector2(59,75),Vector2(ui_size)*Vector2(.5,.35),1)
   await check_cards_and_controls()
   if not small and failures == 0 and check(game.city.has_method("add_center_flyover"), "production city exposes the central corridor edit API"):
    await flyover(4)
    if failures == 0: await flyover(8)
    if failures == 0: await warning_fixture()
  if failures == 0 and not destination.is_empty() and check(frames.size() == CAPTURES.size(), "exactly the four approved compositions are ready") and fresh_destinations():
   for tag: String in CAPTURES:
    var path := destination.path_join(CAPTURES[tag]); var image: Image = frames[tag]
    if not check(image.save_png(path) == OK, "saved native framebuffer: " + path): break
 if is_instance_valid(game): game.free()
 print("RESULT %d/%d center flyover UI checks passed" % [checks-failures,checks])
 quit(1 if failures > 0 or checks == 0 else 0)
