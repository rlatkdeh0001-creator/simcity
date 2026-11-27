extends SceneTree
## E4a §8.1: real main.tscn + viewport input. Native captures are opt-in.
const City = preload("res://core/city_model.gd")
const Paths = preload("res://core/road_junctions.gd")
const VIEW_SIZE := Vector2i(1920, 1080)
const PAPER := Color("142b37")
const LINE := Color("38515e")
const INK := Color("edf4f5")
const ACCENT := Color("36b7ff")
const PALETTE := [PAPER, LINE, INK, ACCENT]
const TAB_INK := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]
const CAPTURES := {
 "kinds": "e4a-one-way-kinds-1920.png",
 "draw": "e4a-one-way-draw-1920.png",
}
const EPS := .001
var game
var passed := 0
var failed := 0
var outputs := {}
var images := {}
var pointer := Vector2.ZERO

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> bool:
 if ok:
  passed += 1
  print("PASS ", message)
 else:
  failed += 1
  printerr("FAIL ", message)
 return ok

func settle(frames := 3) -> void:
 for i in range(frames): await process_frame

func mouse_move(p: Vector2, mask := 0) -> void:
 var e := InputEventMouseMotion.new()
 e.position = p; e.global_position = p; e.relative = p - pointer; e.button_mask = mask
 pointer = p
 root.push_input(e, true)
 await process_frame

func button(p: Vector2, down: bool, which := MOUSE_BUTTON_LEFT) -> void:
 var e := InputEventMouseButton.new()
 e.position = p; e.global_position = p; e.button_index = which; e.pressed = down
 e.button_mask = MOUSE_BUTTON_MASK_LEFT if down and which == MOUSE_BUTTON_LEFT else 0
 root.push_input(e, true)
 await process_frame

func click(p: Vector2) -> void:
 await mouse_move(p)
 await button(p, true)
 await button(p, false)
 await settle()

func key(code: Key) -> void:
 for down: bool in [true, false]:
  var e := InputEventKey.new()
  e.keycode = code; e.physical_keycode = code; e.pressed = down
  root.push_input(e, true)
  await process_frame
 await settle()

func press(control: Control, label: String) -> bool:
 if not check(is_instance_valid(control) and control.is_visible_in_tree() and root.get_visible_rect().has_point(control.get_global_rect().get_center()), label + " has a viewport target"):
  return false
 await click(control.get_global_rect().get_center())
 return true

func node_named(name: String) -> Control:
 return game.find_child(name, true, false) as Control

func map_point(p: Vector2) -> Vector2:
 return game.screen(p)

func aim(p: Vector2) -> bool:
 var screen := map_point(p)
 await mouse_move(screen)
 return check(root.get_visible_rect().has_point(screen) and root.gui_get_hovered_control() == null, "map input is not intercepted at " + str(p))

func click_map(p: Vector2) -> bool:
 if not await aim(p): return false
 await button(pointer, true)
 await button(pointer, false)
 await settle()
 return true

func frame_on(world: Vector2, screen: Vector2, zoom: float) -> void:
 game.map_zoom = zoom
 game.origin = Vector2.ZERO
 game.origin = screen - map_point(world)
 game.refresh()
 await settle()

func make_city():
 var city = City.new(120, 120, 42)
 city.funds = 1000000
 city.population_enabled = false
 city.happiness_enabled = false
 return city

func replace_city() -> void:
 # Test fixture only: like the existing E1 UI test, swap from the paused worker
 # to a clean local model. All tested road/demolition edits still go through GUI.
 game.traffic.stop()
 if game.city.simulation != null: game.city.simulation.shutdown()
 game.city = make_city()
 game.refresh()
 await settle()

func private_building(id: int, x: int, y: int, size_cells: int, asset := "") -> Dictionary:
 return {"id": id, "x": x, "y": y, "size": size_cells, "level": 3, "zone": "residential", "asset_id": asset, "score": 0.0}

func flat_fill(control: Control, style_type: String, color: Color) -> bool:
 var style := control.get_theme_stylebox(style_type)
 return style is StyleBoxFlat and style.bg_color.is_equal_approx(color)

func all_ink(control: Control, color: Color) -> bool:
 return TAB_INK.all(func(k): return control.get_theme_color(k).is_equal_approx(color))

func part_a_fixture(city) -> bool:
 for pair in [[Vector2(10,20), Vector2(90,20)], [Vector2(90,20), Vector2(90,80)], [Vector2(90,80), Vector2(10,80)], [Vector2(10,80), Vector2(10,20)]]:
  var made: Dictionary = city.add_road(PackedVector2Array(pair), "local", true, 4)
  if not made.get("ok", false): return false
 var curb: float = city.RoadProfile.asphalt_width(city.roads[0])/2
 for p: Vector2 in [Vector2(35,20+curb), Vector2(65,80-curb)]:
  if not city.public_facilities.place("bus-stop-01", p).get("ok", false): return false
 var stops: Array = city.public_facilities.lots.map(func(lot): return lot.id)
 if not city.create_transit_line("bus", stops).get("ok", false): return false
 city.buildings.append(private_building(901, 40, 44, 4, "mansion-a-4x4-4f"))
 city.next_id = 902
 return true

func check_part_a() -> void:
 await frame_on(Vector2(50,50), Vector2(1114,475), .9)
 if not await press(node_named("Bottom_transport"), "Part A transport category"): return
 if not check(game.transport_tabs.is_visible_in_tree() and game.transport_tabs.get_child_count() >= 2, "Part A transport tray exposes actual tabs"): return
 for index in [1, 0]:
  if not await press(game.transport_tabs.get_child(index), "Part A transport tab %d" % index): return
  check(game.transport_tab == index, "Part A tab selected by viewport click %d" % index)
  for tab: Button in game.transport_tabs.get_children():
   check(all_ink(tab, PAPER if tab.get_index() == index else INK), "Part A effective tab ink (including hover/focus/press): " + tab.text)
 if not await press(node_named("Tool_transit_line"), "Part A route-list card"): return
 var overlay = game.route_overlay
 if check(overlay.visible and overlay.mode == "bus" and overlay.rows.get_child_count() == 1, "Part A viewport click opens a real bus line list"):
  var row: Control = overlay.rows.get_child(0)
  var title := row.get_child(1) as Label
  check(flat_fill(overlay.panel, "panel", PAPER) and title != null and title.text == "버스 1" and title.get_theme_color("font_color").is_equal_approx(INK), "Part A real route-list panel and original bus title retain approved palette")
  for b: Button in [row.get_node("DeleteRoute"), overlay.create_buttons["bus"]]:
   check(flat_fill(b, "normal", PAPER) and all_ink(b, INK), "Part A route-list action uses approved chrome: " + str(b.name))
  check(not overlay.paths.is_empty() and not overlay.arrow_primitives.is_empty(), "Part A route-list geometry is real, not a mock window")
 if not await press(game.drawer_box.get_child(-1) as Control, "Part A actual drawer close"): return
 check(not overlay.visible and not game.drawer.visible, "Part A actual close hides the route list and tray")
 var b: Dictionary = game.city.find_building(901)
 var visual: Dictionary = game.building_visual(b)
 if not check(not visual.is_empty(), "Part A real selectable building has art"): return
 var rect: Rect2 = visual.rect
 var target := rect.get_center()
 if not check(game.pick_rendered_building(target).get("id", -1) == 901, "Part A building target belongs to #901"): return
 await click(target)
 var info: Label = game.info
 var asset: Dictionary = game.city.catalog.get_asset("mansion-a-4x4-4f")
 var expected := "#901 · 4×4 · 레벨 3\n성장 수치 0 / %d\n%s · %s · 지상 %d층" % [game.city.config.score_threshold, asset.category_name, asset.name, asset.storeys]
 check(game.selected == 901 and info.visible and info.text == expected and flat_fill(info, "normal", PAPER) and info.get_theme_color("font_color").is_equal_approx(INK) and info.get_theme_font_size("font_size") >= 18, "Part A selected building retains exact three lines and approved 18px plate")
 await mouse_move(info.get_global_rect().get_center())
 check(info.mouse_filter == Control.MOUSE_FILTER_IGNORE and info.focus_mode == Control.FOCUS_NONE and root.gui_get_hovered_control() == null and root.get_visible_rect().encloses(info.get_global_rect()) and not info.get_global_rect().intersects(game.dock.get_global_rect()), "Part A building plate passes input and clears the dock")
 # Clear selection via real map input before swapping in the empty E4a city.
 await click(Vector2(900,100))
 check(game.selected == -1 and not info.visible, "Part A building deselect clears the plate")

func caption(card: Button) -> Label:
 return card.get_node_or_null("NameBand/AssetName") as Label

func card_title(card: Button) -> String:
 var label := caption(card)
 return label.text if label != null else card.text

func strip() -> ScrollContainer:
 return node_named("RoadCardStrip") as ScrollContainer

func open_roads(label: String) -> bool:
 # Clicking the already open category collapses it; first establish the actual tray state.
 if not game.drawer.visible or game.chosen != "road":
  if not await press(node_named("Bottom_road"), label): return false
 return check(strip() != null and strip().is_visible_in_tree(), label + " shows the actual road strip")

func card_for(text: String) -> Button:
 var s := strip()
 if s == null: return null
 for child in s.get_node("Cards").get_children():
  var card := child as Button
  if card != null and card_title(card) == text: return card
 return null

func scroll_to(card: Button) -> bool:
 var s := strip()
 if s == null or card == null: return false
 var bar := s.get_h_scroll_bar()
 var view := s.get_global_rect()
 if bar.visible: view.size.y -= bar.size.y
 var target := view.get_center()
 var before_zoom: float = game.map_zoom
 for i in range(16):
  var r := card.get_global_rect()
  if view.grow(1.0).encloses(r): return check(is_equal_approx(game.map_zoom, before_zoom), "scroll strip owns wheel without map zoom: " + str(card.name))
  var wheel := MOUSE_BUTTON_WHEEL_DOWN if r.end.x > view.end.x else MOUSE_BUTTON_WHEEL_UP
  var old := s.scroll_horizontal
  await mouse_move(target)
  await button(target, true, wheel)
  await button(target, false, wheel)
  await settle()
  if old == s.scroll_horizontal: break
 return check(false, "actual scroll strip reveals the whole card: " + str(card.name))

func pick_card(text: String) -> bool:
 var card := card_for(text)
 if not check(card != null, "real road card exists: " + text): return false
 if not await scroll_to(card): return false
 var target := card.get_global_rect().get_center()
 if not check(card.is_visible_in_tree() and root.get_visible_rect().has_point(target), "road card " + text + " has a viewport target"): return false
 # Deliver the motion and its matching click as one GUI gesture. Leaving an
 # engine frame between press and release lets native pointer motion retarget it.
 var motion := InputEventMouseMotion.new()
 motion.position = target; motion.global_position = target; motion.relative = target - pointer
 pointer = target
 root.push_input(motion, true)
 var hovered := root.gui_get_hovered_control()
 if not check(hovered == card or (hovered != null and card.is_ancestor_of(hovered)), "card owns the actual mouse target: " + text): return false
 for down: bool in [true, false]:
  var event := InputEventMouseButton.new()
  event.position = target; event.global_position = target; event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = down; event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
  root.push_input(event, true)
 await settle()
 return check(card.button_pressed and game.mode == "road", "viewport card click arms road tool: " + text)

func check_card(n: int) -> bool:
 var text := "편도 %d차로" % n
 var card := card_for(text)
 if not check(card != null, "one-way card is in the existing scroll strip: " + text): return false
 check(str(card.name) == "RoadOneWay_%d" % n and card.get_meta("lanes", 0) == n and card.get_meta("travel_dir", 0) == 1, "one-way UI identity: " + text)
 var label := caption(card)
 var texture := card.get_node_or_null("AssetThumbnail") as TextureRect
 var path := str(card.get_meta("source_preview", ""))
 var title_control: Control = label if label != null else card
 var available := title_control.size.x
 if label == null: available -= card.get_theme_stylebox("normal").get_minimum_size().x
 var font_size := title_control.get_theme_font_size("font_size")
 check(font_size >= 18 and title_control.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available + EPS, "card has untruncated >=18px caption: " + text)
 check(title_control.get_theme_color("font_color").is_equal_approx(INK), "one-way card caption uses #edf4f5: " + text)
 for state in ["normal", "hover", "pressed"]:
  var style := card.get_theme_stylebox(state)
  check(style is StyleBoxFlat and style.bg_color in PALETTE and style.border_color in [LINE, ACCENT], "one-way card chrome is in approved palette (%s): %s" % [state, text])
 check(path == "res://assets/ui/roads/one-way-%d.png" % n, "one-way card points only to its own thumbnail: " + text)
 if FileAccess.file_exists(path) or DisplayServer.get_name() != "headless":
  check(texture != null and texture.texture != null and label != null and flat_fill(label.get_parent() as Panel, "panel", PAPER), "one-way card uses real studio art and approved name band: " + text)
 else:
  check(texture == null, "deferred studio art has no placeholder: " + text)
 check(card.tooltip_text in ["", text], "one-way card has no tooltip explanation: " + text)
 return await pick_card(text)

func check_drawer_copy() -> void:
 var allowed := ["도로", "지하", "지상", "고가", "−", "+", "0 m", "⌄", "⌃", "▾", "▴", "˅", "∨", "닫기"]
 for n in range(2,9): allowed.append("%d차선" % n)
 for n in range(1,5): allowed.append("편도 %d차로" % n)
 var extras: Array[String] = []
 for c in game.drawer_box.find_children("*", "Control", true, false):
  if not c.is_visible_in_tree() or not (c is Label or c is Button) or c.text.is_empty(): continue
  if str(c.name) == "HeightValue":
   if c.text != "0 m": extras.append(c.text)
  elif c.text not in allowed: extras.append(c.text)
 check(extras.is_empty(), "road drawer has only tool names/controls, no new explanatory copy: " + str(extras))

func clean_success() -> bool:
 var names := ["SuccessToast", "RoadSuccessToast", "ConstructionSuccessToast"]
 return game.message.is_empty() and not game.hud.visible and game.money.tooltip_text.is_empty() and (not is_instance_valid(game.money_toast) or not game.money_toast.visible) and names.all(func(n): return node_named(n) == null)

func grid_off() -> bool:
 var grid := node_named("RoadGridToggle") as Button
 if not check(grid != null, "existing road grid toggle is present"): return false
 if grid.button_pressed:
  if not await press(grid, "grid toggle"): return false
 return check(not grid.button_pressed and not game.road_grid_enabled, "grid is OFF by real UI input")

func is_forward(road: Dictionary, count: int) -> bool:
 # Candidate core record contract: no key/zero is legacy; +1 follows points.
 return int(road.get("travel_dir", 0)) == 1 and int(road.get("lanes", 0)) == count

func exact_points(points: PackedVector2Array, first: Vector2, last: Vector2) -> bool:
 return points.size() >= 2 and points[0].distance_to(first) <= EPS and points[-1].distance_to(last) <= EPS

func outline(p: Dictionary) -> Color:
 return game.road_drawer.preview_colors(p.get("ok", false), p.get("warning", false)).get("outline", Color.TRANSPARENT)

func preview_arrows(p: Dictionary) -> Array:
 # Inspect the same world-cell polygons that draw_preview consumes.
 var shapes: Array = game.road_drawer.preview_arrow_polygons(p)
 if not check(not shapes.is_empty(), "valid live one-way preview has arrow polygons"):
  return []
 for shape in shapes:
  if not check(shape is PackedVector2Array and shape.size() >= 3, "preview arrow is a nonempty production polygon"):
   return []
 return shapes

func start_preview(a: Vector2, b: Vector2) -> bool:
 var count: int = game.city.roads.size()
 if not await click_map(a): return false
 if not check(game.road_drawer.anchors.size() == 1 and game.road_drawer.anchors[0].distance_to(a) <= EPS and game.city.roads.size() == count, "first click accepts exact grid-off anchor without committing"):
  return false
 if not await aim(b): return false
 await settle()
 return true

func check_green(a: Vector2, b: Vector2) -> Array:
 var p: Dictionary = game.road_drawer.preview()
 check(p.get("ok", false) and not p.get("warning", false) and outline(p).is_equal_approx(Color("3ddc84")) and exact_points(p.get("points", PackedVector2Array()), a, b), "green grid-off preview preserves both click positions")
 return preview_arrows(p) if p.get("ok", false) else []

func is_ground() -> bool:
 return absf(float(game.road_drawer.target_height_m)) < EPS and not game.transit_view.underground

func check_ground_lock(a: Vector2, b: Vector2) -> bool:
 var elevated := node_named("Elevated") as Button
 if not check(elevated != null and not elevated.disabled, "ordinary road exposes working elevated height action"): return false
 if not await press(elevated, "ordinary +10m"): return false
 check(is_equal_approx(float(game.road_drawer.target_height_m), 10.0), "ordinary card height action is a positive control")
 await key(KEY_PAGEUP)
 check(is_equal_approx(float(game.road_drawer.target_height_m),15.0), "ordinary PgUp reaches the real height handler")
 await key(KEY_PAGEDOWN)
 check(is_equal_approx(float(game.road_drawer.target_height_m),10.0), "ordinary PgDn reaches the real height handler")
 if not await pick_card("편도 2차로"): return false
 check(is_ground() and is_zero_approx(float(game.road_drawer.start_height_m)), "one-way card resets a prior +10m tool to ground")
 for name in ["Elevated", "Underground", "HeightPlus", "HeightMinus"]:
  var control := node_named(name) as Button
  if control != null and control.is_visible_in_tree():
   if not await press(control, "one-way tries " + name): return false
  check(is_ground(), "one-way stays ground after height control attempt: " + name)
 if not await start_preview(a,b): return false
 for code: Key in [KEY_PAGEUP, KEY_PAGEDOWN]:
  await key(code)
  check(is_ground() and game.road_drawer.anchors.size() == 1 and game.road_drawer.anchors[0].distance_to(a) <= EPS, "one-way locks height and keeps the live start after key %s" % OS.get_keycode_string(code))
 return true

func draw_commit(text: String, a: Vector2, b: Vector2, one_way := 0) -> Dictionary:
 if not await pick_card(text): return {}
 if not await start_preview(a, b): return {}
 var preview: Dictionary = game.road_drawer.preview()
 if not check(preview.get("ok", false) and not preview.get("warning", false), "clear stroke accepted for " + text + ": " + str(preview.get("reason", ""))): return {}
 var before: int = game.city.roads.size()
 if not await click_map(b): return {}
 if not check(game.city.roads.size() == before + 1, "endpoint click commits " + text): return {}
 var road: Dictionary = game.city.roads[-1]
 check(exact_points(road.points, a, b) and (is_forward(road, one_way) if one_way > 0 else int(road.get("travel_dir", 0)) == 0), "stored direction and exact endpoints match viewport stroke: " + text)
 return road

func cuts_match(id: int, a: Vector2, b: Vector2) -> bool:
 var cuts: Array = game.demolition_hover.get("selection", {}).get("cuts", [])
 return cuts.size() == 1 and cuts[0].id == id and exact_points(cuts[0].points, a,b)

func road_span(a: Vector2, b: Vector2, lanes: int) -> bool:
 return game.city.roads.any(func(r): return is_forward(r, lanes) and exact_points(r.points, a,b))

func check_overlap_and_demolition(a: Vector2, b: Vector2, id: int) -> void:
 if not await pick_card("편도 2차로"): return
 if not await start_preview(b, a): return
 var before := var_to_bytes(game.city.roads)
 var red: Dictionary = game.road_drawer.preview()
 check(not red.get("ok", false) and not red.get("warning", false) and not str(red.get("reason", "")).is_empty() and outline(red).is_equal_approx(Color("ef5350")) and exact_points(red.get("points", PackedVector2Array()), b, a), "reverse overpaint of the same full footprint shows red, not a warning")
 if not await click_map(a): return
 check(var_to_bytes(game.city.roads) == before and node_named("RoadDemolitionWarning") == null, "red endpoint click does not mutate or open a warning")
 await key(KEY_ESCAPE)
 if not await open_roads("road category after escape"): return
 var junction := Vector2(59.25, a.y)
 var crossing := await draw_commit("2차선", junction + Vector2(0,-14), junction + Vector2(0,14))
 if crossing.is_empty(): return
 check(not (node_named("Elevated") as Button).disabled and not (node_named("Underground") as Button).disabled, "returning to legacy restores the regular height controls")
 check(Paths.analyze(game.city.roads).junctions.size() == 1, "bulldozer fixture has one real mixed junction")
 if not await press(game.bulldozer, "existing bulldozer"): return
 if not check(game.mode == "demolish", "viewport click arms bulldozer"): return
 var hit := Vector2(45.25, a.y)
 if not await aim(hit): return
 check(cuts_match(id, a, junction), "bulldozer hover picks the one-way arm only up to the junction")
 before = var_to_bytes(game.city.roads)
 await button(pointer, true)
 check(var_to_bytes(game.city.roads) == before, "bulldozer press does not delete before release")
 await button(pointer, false)
 await settle()
 check(game.city.roads.size() == 2 and road_span(junction, b, 2) and crossing in game.city.roads, "click deletes only the selected junction arm; opposite arm and crossing survive")
 var press_at := Vector2(65.55, a.y)
 var release_at := press_at + Vector2(.8,0)
 var fragment_id := -1
 for road: Dictionary in game.city.roads:
  if is_forward(road, 2): fragment_id = int(road.parcel_id)
 if not check(fragment_id >= 0, "surviving one-way arm has a stable selectable ID"): return
 if not await aim(press_at): return
 before = var_to_bytes(game.city.roads)
 await button(pointer, true)
 await mouse_move(map_point(release_at), MOUSE_BUTTON_MASK_LEFT)
 check(cuts_match(fragment_id, press_at, press_at + Vector2(2,0)) and var_to_bytes(game.city.roads) == before, "3.2m drag previews one 8m cut without mutation")
 await button(pointer, false)
 await settle()
 check(game.city.roads.size() == 3 and crossing in game.city.roads and road_span(junction, press_at, 2) and road_span(press_at + Vector2(2,0), b, 2), "drag release removes precisely the 8m preview; both directed fragments and crossing survive")
 check(clean_success(), "bulldozer success stays silent")

func check_warning() -> void:
 # In-footprint grown buildings and a near but strictly outside control building.
 game.city.buildings.assign([private_building(91, 44, 69, 2), private_building(92, 54, 70, 2), private_building(93, 50, 73, 2)])
 game.city.next_id = 94
 game.refresh()
 await settle()
 if not await open_roads("road category after demolition"): return
 if not await pick_card("편도 2차로") or not await grid_off(): return
 var a := Vector2(38.25,70.25)
 var b := Vector2(74.25,70.25)
 var before := var_to_bytes([game.city.roads, game.city.buildings, game.city.next_road_id])
 for action: String in ["Cancel", "Confirm"]:
  if not await start_preview(a,b): return
  var p: Dictionary = game.road_drawer.preview()
  var ids: Array = Array(p.get("demolish_ids", []))
  ids.sort()
  check(p.get("ok", false) and p.get("warning", false) and ids == [91,92] and outline(p).is_equal_approx(Color("e6c442")), "yellow preview names exactly the two footprint IDs: " + str(ids))
  if not await click_map(b): return
  var panel := node_named("RoadDemolitionWarning")
  if not check(panel != null and panel.is_visible_in_tree() and var_to_bytes([game.city.roads, game.city.buildings, game.city.next_road_id]) == before, "B bubble is visible and blocks mutation before " + action): return
  var count := panel.find_child("DemolitionCount", true, false) as Label
  var title_ok := false
  for l: Label in panel.find_children("*", "Label", true, false):
   if l.text == "⚠ 이미 지어진 건물이 파괴됩니다" and l.get_theme_font_size("font_size") >= 18: title_ok = true
  check(count != null and count.text == "2" and title_ok, "B bubble shows two affected lots and the approved warning")
  var control := panel.find_child(action, true, false) as Button
  if not await press(control, "B actual " + action): return
  check(node_named("RoadDemolitionWarning") == null, "B bubble closes after " + action)
  if action == "Cancel":
   check(var_to_bytes([game.city.roads, game.city.buildings, game.city.next_road_id]) == before, "cancel leaves roads, private buildings and next road ID unchanged")
  else:
   check(game.city.find_building(91).is_empty() and game.city.find_building(92).is_empty() and not game.city.find_building(93).is_empty() and game.city.buildings.size() == 1 and road_span(a,b,2), "confirm removes only pending IDs and commits the exact directed stroke")
   check(clean_success(), "one-way confirm shows no success notice")

func ui_regression() -> void:
 await replace_city()
 await frame_on(Vector2(55.25,53.25), Vector2(960,418), .95)
 if not await open_roads("road category"): return
 var names: Array = []
 for child in strip().get_node("Cards").get_children():
  if child is Button and card_title(child).begins_with("편도 "): names.append(card_title(child))
 if not check(names == ["편도 1차로", "편도 2차로", "편도 3차로", "편도 4차로"], "exactly four one-way cards, in lane count order: " + str(names)): return
 for n in range(1,5):
  if not await check_card(n): return
 if not await pick_card("2차선") or not await grid_off(): return
 var a := Vector2(37.25,50.25)
 var b := Vector2(73.25,50.25)
 if not await check_ground_lock(a, b) or failed > 0: return
 check_drawer_copy()
 check_green(a,b)
 if not await click_map(b): return
 if not check(game.city.roads.size() == 1 and road_span(a,b,2), "second click commits the exact grid-off two-lane one-way record"): return
 var road: Dictionary = game.city.roads[0]
 var heights: PackedFloat64Array = road.get("heights_m", PackedFloat64Array())
 check(Array(heights).all(func(h): return absf(float(h)) < EPS) and is_ground(), "committed one-way geometry and view are both ground-level")
 check(clean_success(), "one-way commit produces no success copy")
 await check_overlap_and_demolition(a,b,int(road.parcel_id))
 await check_warning()

func grid_modes() -> void:
 await replace_city()
 await frame_on(Vector2(50,50), Vector2(960,420), .82)
 if not await open_roads("grid-on drawing modes") or not await pick_card("편도 1차로"): return
 if not await press(node_named("RoadGridToggle"), "enable grid by viewport click"): return
 if not check(game.road_grid_enabled, "grid is ON for all three one-way modes"): return
 var end := Vector2.ZERO
 for mode_name: String in ["straight", "curve", "free"]:
  if not await press(node_named("RoadMode_" + mode_name), "select one-way " + mode_name): return
  var a := end if mode_name == "free" else Vector2(28.28, 57.31 if mode_name == "curve" else 40.28)
  var b := Vector2(49.31, 40.27) if mode_name == "straight" else (Vector2(48.26,68.31) if mode_name == "curve" else end + Vector2(20.21, 7.16))
  var count: int = game.city.roads.size()
  if not await click_map(a): return
  if mode_name == "curve" and not await click_map(Vector2(28.54, 68.66)): return
  if not await aim(b): return
  var p: Dictionary = game.road_drawer.preview()
  if not check(game.city.roads.size() == count and p.ok and not p.get("warning",false) and p.travel_dir == 1 and p.width == 1.5 and not p.grid_frame.is_empty(), "grid-on %s uses the selected 6m one-way preview: %s" % [mode_name,p.reason]): return
  if not check(p.points.size() == 2 if mode_name == "straight" else p.points.size() > 8, "%s uses its real drawing geometry" % mode_name): return
  if mode_name == "free":
   check(p.points[0].is_equal_approx(end), "free curve keeps the committed forward endpoint")
  if not await click_map(b): return
  if not check(game.city.roads.size() == count + 1, "grid-on %s commits only on the final click" % mode_name): return
  var road: Dictionary = game.city.roads[-1]
  check(is_forward(road, 1) and road.points == p.points and Array(road.heights_m).all(func(h): return absf(float(h)) < EPS), "grid-on %s commits exact directed preview geometry at 0m" % mode_name)
  if mode_name == "straight": end = road.points[-1]
 # The exact next composition starts in the straight drawing mode.
 await press(node_named("RoadMode_straight"), "restore straight for capture fixtures")

func seed_and_sample(roads: Array) -> bool:
 if not check(game.traffic.rebuild(game.city.roads), "production traffic builds from the four UI-authored roads and crossing"): return false
 var sim = game.traffic.simulation
 var assets := ["car-hatch-01", "car-sedan-03", "car-wagon-04", "car-coupe-07"]
 var observations: Array[Dictionary] = []
 for i in range(roads.size()):
  var road: Dictionary = roads[i]
  var index: int = game.city.roads.find(road)
  var lanes: Array = game.traffic.network.lanes.filter(func(l): return int(l.get("road", -1)) == index)
  if not check(not lanes.is_empty() and lanes.all(func(l): return int(l.direction) == 1), "kind %d has no reverse production lanes" % (i+1)): return false
  var available: Array = game.traffic.catalog.filter(func(asset): return asset.id == assets[i])
  if not check(not available.is_empty(), "existing traffic asset for kind %d" % (i+1)): return false
  var a: Vector2 = road.points[0]
  var b: Vector2 = road.points[-1]
  var axis := (b-a).normalized()
  # Spawn away from end caps, approach markings and arrow centers. Crossed road
  # uses its longest straight section; the vehicle stays on it for all samples.
  var longest: Dictionary = lanes[0]
  for lane: Dictionary in lanes:
   if lane.length > longest.length: longest = lane
  for fraction: float in [.30, .63]:
   var car: Dictionary = sim.spawn(available[0], [longest.id], float(longest.length)*fraction)
   if not check(not car.is_empty(), "real car spawned on kind %d at %.2f lane progress" % [i+1,fraction]): return false
   observations.append({"car": car, "start": sim.position(car), "axis": axis, "kind": i+1, "lane": longest.id, "forward": true, "last": sim.position(car)})
 # No teleports, no injected poses. Advance the real fixed-step simulation;
 # check every sample for sign, then require actual positive net displacement.
 for i in range(54):
  sim.update(1.0/30.0)
  for row in observations:
   var p: Vector2 = sim.position(row.car)
   var previous: Vector2 = row.last
   var axis: Vector2 = row.axis
   var heading: Vector2 = sim.heading(row.car)
   row.forward = row.forward and (p-previous).dot(axis) >= -EPS and heading.dot(axis) > .99 and row.car.lane == row.lane
   row.last = p
 sim.paused = true # Freeze this already-advanced real traffic state for exact framing.
 await settle()
 var ok := true
 for row in observations:
  var moved: Vector2 = row.last - row.start
  var sprite: Sprite2D = game.world_renderer.cars.get(row.car.id)
  var visible := sprite != null and sprite.visible and sprite.texture != null and root.get_visible_rect().has_point(map_point(Vector2(row.last)/4))
  ok = check(row.forward and row.car.speed > 0.0 and moved.dot(row.axis) > 1.0 and visible, "kind %d real car %d moved only with the authored stroke and is rendered" % [row.kind,row.car.id]) and ok
 return ok

func frame() -> Image:
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()

func composition_kinds() -> void:
 await replace_city()
 await frame_on(Vector2(50,45), Vector2(960,415), .98)
 if not await open_roads("kinds composition road category") or not await grid_off(): return
 var roads: Array = []
 var widths := [6.0,12.0,12.0,20.0]
 for n in range(1,5):
  var y := 24.0 + (n-1)*14.0
  var a := Vector2(28,y)
  var b := Vector2(72,y)
  if n%2 == 0:
   a = Vector2(72,y); b = Vector2(28,y)
  var r := await draw_commit("편도 %d차로" % n, a,b,n)
  if r.is_empty(): return
  check(absf(float(r.width)*4.0-widths[n-1]) < EPS, "composition kind %d has %.0fm physical width" % [n,widths[n-1]])
  roads.append(r)
 var cross := await draw_commit("2차선", Vector2(56,44), Vector2(56,60))
 if cross.is_empty(): return
 var junctions: Array = Paths.analyze(game.city.roads).junctions
 check(game.city.roads.size() == 5 and junctions.size() == 1, "kinds composition contains exactly four parallel one-ways and one two-way X junction")
 await key(KEY_ESCAPE)
 if game.drawer.visible and not await press(game.drawer_box.get_child(-1) as Control, "kinds composition close tray"): return
 if not check(not game.drawer.visible and game.road_drawer.anchors.is_empty(), "kinds composition clears the tray and live stroke"): return
 await mouse_move(Vector2(142,435))
 if not await seed_and_sample(roads): return
 if not outputs.is_empty() and failed == 0:
  images["kinds"] = await frame()

func light_arrow_pixels(img: Image, shape: PackedVector2Array) -> int:
 # Sample strictly inside the actual projected polygon, not a generic white
 # swatch elsewhere in the HUD/measurement badge. No synthetic screenshot.
 var projected := PackedVector2Array()
 for point in shape: projected.append(map_point(point))
 var bounds := Rect2(projected[0], Vector2.ZERO)
 for p in projected: bounds = bounds.expand(p)
 var safe := bounds.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
 var bright := 0
 for y in range(ceili(safe.position.y), floori(safe.end.y)):
  for x in range(ceili(safe.position.x), floori(safe.end.x)):
   if not Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5), projected): continue
   var c := img.get_pixel(x,y)
   if minf(c.r,minf(c.g,c.b)) > .7 and absf(c.r-c.g) < .14 and absf(c.g-c.b) < .14: bright += 1
 return bright

func composition_draw() -> void:
 await replace_city()
 await frame_on(Vector2(59.25,51.25), Vector2(960,400), 1.48)
 if not await open_roads("draw composition road category") or not await grid_off(): return
 if not await pick_card("편도 2차로"): return
 # Reveal the appended block with real wheel events BEFORE the first map click;
 # wheel events over the tray must not obscure or reposition the ghost.
 var right := card_for("편도 4차로")
 if not await scroll_to(right): return
 var s := strip()
 for n in range(1,5):
  var card := card_for("편도 %d차로" % n)
  if card == null:
   check(false, "draw composition lacks card %d" % n); return
  check(s.get_global_rect().encloses(card.get_global_rect()), "draw capture fully exposes one-way card %d" % n)
 check(card_for("편도 2차로").button_pressed and game.drawer.visible, "draw capture retains visible selected two-lane card and tray")
 check_drawer_copy()
 var a := Vector2(28.25,51.25)
 var b := Vector2(90.25,51.25)
 if not await start_preview(a,b): return
 var shapes := check_green(a,b)
 check(game.city.roads.is_empty() and game.road_drawer.pending.is_empty(), "draw capture is live before commit, not a built road or pending warning")
 if not outputs.is_empty() and failed == 0:
  var raw := await frame()
  if not check(raw != null and raw.get_size() == VIEW_SIZE, "draw buffer is the actual 1920x1080 viewport"): return
  var green := raw.get_pixelv(Vector2i(map_point(a.lerp(b,.49)+Vector2(0,.9))))
  check(green.g > green.r+.08 and green.g > green.b+.04, "native framebuffer shows green preview road fill off the centerline")
  check(shapes.any(func(shape): return light_arrow_pixels(raw, shape) >= 3), "native framebuffer shows white ink inside a real preview arrow polygon")
  images["draw"] = raw

func check_live_traffic_edits() -> void:
 await replace_city()
 await frame_on(Vector2(46,45), Vector2(960,410), 1.0)
 var a := Vector2(35,45)
 var b := Vector2(57,45)
 if not await open_roads("live traffic road category") or not await grid_off(): return
 var old_road := await draw_commit("2차선", a,b)
 if old_road.is_empty(): return
 game.toggle_traffic()
 if not check(game.traffic.running, "live edit fixture starts real traffic"): return
 var old_sim = game.traffic.simulation
 old_sim.paused = true
 check(not old_sim.vehicles.is_empty(), "live edit fixture has old-graph cars")
 game.refresh()
 check(game.traffic.simulation == old_sim, "unrelated refresh preserves the active fleet")
 if not await press(game.bulldozer, "live traffic bulldozer") or not await click_map(a.lerp(b,.5)): return
 if not check(game.city.roads.is_empty(), "viewport demolition removes the route"): return
 check(not game.traffic.running and game.traffic.resume_on_road_edit, "main drops old lanes while waiting for roads")
 if not await open_roads("live traffic replacement category"): return
 var new_road := await draw_commit("편도 1차로", b,a,1)
 if new_road.is_empty(): return
 if not check(game.traffic.running and game.traffic.simulation != old_sim, "main restarts the waiting fleet against committed replacement lanes"): return
 var sim = game.traffic.simulation
 check(sim.paused, "road changes preserve the independent traffic pause")
 sim.paused = false
 game.traffic.update(1.0)
 check(not sim.vehicles.is_empty() and sim.vehicles.all(func(car):return car.distance>0.0 and game.traffic.network.lanes[car.lane].direction==1 and game.traffic.network.tangent(car.lane,car.progress).x<-.9), "replacement cars move only in the new road's authored direction")

func check_queued_traffic_edit() -> void:
 # Use the live main callback and worker, but step worker boundaries explicitly.
 game.set_process(false)
 await exercise_queued_traffic_edit()
 if game.city.simulation != null and game.city.simulation.enabled:
  game.city.simulation.worker.SetValidationGate(false)
  game.city.simulation.shutdown()
 game.set_process(true)

func exercise_queued_traffic_edit() -> void:
 var a := Vector2(34,66)
 var b := Vector2(58,66)
 var active = game.traffic.simulation
 if not check(active != null and game.traffic.running, "queued edit starts with an active replacement fleet"): return
 active.paused = true
 await frame_on(Vector2(46,66), Vector2(960,410), 1.0)
 if not await open_roads("queued traffic road category") or not await pick_card("편도 1차로"): return
 game.city.enable_simulation_worker()
 var worker = game.city.simulation
 if not check(worker != null and worker.enabled, "queued road test starts the real simulation worker"): return
 worker.worker.Suspend()
 if not check(worker.is_ready(), "worker is ready before holding the road edit boundary"): return
 worker.edit_completed.connect(game._simulation_edit_completed)
 var completions: Array = []
 worker.edit_completed.connect(func(result):completions.append([result,game.traffic.simulation,game.city.road_topology_revision]))
 worker.worker.SetValidationGate(true)
 var interval: float = game.city.config.development_interval_seconds
 worker.advance(interval)
 if not check(worker.has_pending(), "held worker has an unpublished step"): return
 var old_revision: int = game.city.road_topology_revision
 var before: int = game.city.roads.size()
 var first: Dictionary = game.city.add_elevated_road(PackedVector2Array([b,a]),PackedFloat64Array([0,0]),"local",true,1,false,1,{},null,1)
 if not check(first.get("queued",false), "opposite stroke is queued first without committing"): return
 if not await start_preview(a,b): return
 var preview: Dictionary = game.road_drawer.preview()
 if not check(preview.ok and not preview.get("warning",false), "second stroke is valid against the currently visible world"): return
 if not await click_map(b): return
 check(worker.queued_edit_count()==2 and game.city.roads.size()==before and game.city.road_topology_revision==old_revision, "real endpoint input queues the second stroke without publishing road geometry")
 check(game.traffic.running and game.traffic.simulation==active, "queued endpoint does not stop or reseed the active fleet")
 worker.worker.SetValidationGate(false)
 if not check(worker.validation_publish(), "held step publishes without applying either queued edit"): return
 check(completions.is_empty() and worker.queued_edit_count()==2, "publication itself does not replay unallocated edits")
 worker.resume()
 worker.advance(interval)
 if not check(completions.size()==2 and worker.queued_edit_count()==0, "both road edits complete in FIFO order"): return
 var accepted: Array = completions[0]
 var rejected: Array = completions[1]
 check(accepted[0].ok and not rejected[0].ok and not str(rejected[0].reason).is_empty() and game.message==str(rejected[0].reason), "the committed opposite stroke rejects the stale viewport plan and reports the real reason")
 check(game.city.roads.size()==before+1 and road_span(b,a,1) and accepted[2]==old_revision+1 and rejected[2]==accepted[2], "only the accepted stroke changes the road topology")
 check(game.traffic.running and accepted[1]!=null and accepted[1]!=active and rejected[1]==accepted[1] and game.traffic.simulation.paused, "accepted replay reseeds once and rejected replay preserves that paused fleet")

func configure_outputs() -> bool:
 # Check-only takes precedence even if a capture command is reused by mistake.
 if "--fixture-check" in OS.get_cmdline_user_args(): return true
 for arg: String in OS.get_cmdline_user_args():
  for tag in CAPTURES:
   var prefix := "--e4a-%s-capture=" % tag
   if not arg.begins_with(prefix): continue
   var filename := arg.trim_prefix(prefix)
   if not check(not outputs.has(tag) and filename.is_absolute_path() and filename.get_file() == CAPTURES[tag] and DirAccess.dir_exists_absolute(filename.get_base_dir()) and not FileAccess.file_exists(filename) and not DirAccess.dir_exists_absolute(filename), "fresh absolute capture path for " + str(tag)):
    return false
   outputs[tag] = filename
 if outputs.is_empty(): return true
 return check(outputs.size() == 2 and DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility" and RenderingServer.get_current_rendering_driver_name() == "opengl3" and root.size == VIEW_SIZE and DisplayServer.window_get_size() == VIEW_SIZE, "both captures require one real 1920x1080 native OpenGL Compatibility run")

func save_outputs() -> void:
 for tag in CAPTURES:
  var img: Image = images.get(tag)
  if not check(img != null and img.get_size() == VIEW_SIZE and not FileAccess.file_exists(outputs[tag]), "raw framebuffer ready and destination still fresh: " + str(tag)):
   return
 for tag in CAPTURES:
  var img: Image = images[tag]
  if not check(img.save_png(outputs[tag]) == OK, "save actual 1920x1080 framebuffer: " + str(outputs[tag])): return

func run() -> void:
 var native := DisplayServer.get_name() != "headless"
 if not native: root.size = VIEW_SIZE
 if not configure_outputs():
  finish(); return
 var city = make_city()
 if not check(part_a_fixture(city), "fixture has authoritative bus loop and selected-building target"):
  finish(); return
 game = load("res://main.tscn").instantiate()
 game.city = city; game.paused = true
 root.add_child(game)
 current_scene = game
 await settle(6)
 await check_part_a()
 await ui_regression()
 # Fail closed before attempting any framebuffer read.
 if failed == 0: await grid_modes()
 if failed == 0: await check_live_traffic_edits()
 if failed == 0: await check_queued_traffic_edit()
 if failed == 0: await composition_kinds()
 if failed == 0: await composition_draw()
 if failed == 0 and not outputs.is_empty(): save_outputs()
 finish()

func finish() -> void:
 if is_instance_valid(game):
  game.free() # main._exit_tree owns worker teardown
  game = null
 print("RESULT %d/%d one-way UI checks passed" % [passed,passed+failed])
 quit(1 if failed else 0)
