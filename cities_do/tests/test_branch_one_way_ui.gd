extends SceneTree
## E4b §8.2 — real main.tscn, real GUI and map input. Capture is strictly opt-in.
const City = preload("res://core/city_model.gd")
const Profile = preload("res://core/road_profile.gd")
const MAIN = preload("res://main.tscn")
const VIEW := Vector2i(1920, 1080)
const EPS := 0.00025 # cells (1 mm), also a tighter bore for metre-space joins
const SIX := "branch-one-way-6m"
const EIGHT := "branch-one-way-8m"
const STOP := "bus-stop-01"
const KINDS_X := 35.25
const KINDS_Y := [36.25, 45.25, 54.25]
const CONT_Y8 := 40.25
const CONT_Y6 := 53.25
const STOP_CURB := Vector2(40.25, CONT_Y8 + 0.75)
const CAPTURES := {
 "kinds": "e4b-branch-kinds-1920.png",
 "continue": "e4b-branch-continue-1920.png",
}

var game
var passed := 0
var failed := 0
var pointer := Vector2.ZERO
var outputs: Dictionary = {}
var images: Dictionary = {}
var kinds_done := false
var continue_done := false
var demolition_done := false
var warning_done := false

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

func settle(count := 3) -> void:
 for i in range(count):
  await process_frame

func control(name_value: String) -> Control:
 return game.find_child(name_value, true, false) as Control

func move(p: Vector2, mask := 0) -> void:
 var e := InputEventMouseMotion.new()
 e.position = p
 e.global_position = p
 e.relative = p - pointer
 e.button_mask = mask
 pointer = p
 root.push_input(e, true)

func button(p: Vector2, down: bool, which := MOUSE_BUTTON_LEFT) -> void:
 var e := InputEventMouseButton.new()
 e.position = p
 e.global_position = p
 e.button_index = which
 e.pressed = down
 e.button_mask = MOUSE_BUTTON_MASK_LEFT if down and which == MOUSE_BUTTON_LEFT else 0
 root.push_input(e, true)

func key(code: Key) -> void:
 for down: bool in [true, false]:
  var e := InputEventKey.new()
  e.keycode = code
  e.physical_keycode = code
  e.pressed = down
  root.push_input(e, true)
 await settle()

func click_control(target: Control, label: String) -> bool:
 if not check(is_instance_valid(target) and target.is_visible_in_tree(), label + " control is visible"):
  return false
 var p := target.get_global_rect().get_center()
 if not check(root.get_visible_rect().has_point(p), label + " has an on-screen click point"):
  return false
 move(p)
 var hovered := root.gui_get_hovered_control()
 if not check(hovered == target or (hovered != null and target.is_ancestor_of(hovered)), label + " owns actual GUI input"):
  return false
 # Keep real OS pointer motion from retargeting a GUI press between frames.
 button(p, true)
 button(p, false)
 await settle()
 return true

func screen(world: Vector2) -> Vector2:
 return game.screen(world)

func aim(world: Vector2) -> bool:
 var p := screen(world)
 move(p)
 return check(root.get_visible_rect().has_point(p) and root.gui_get_hovered_control() == null, "map point is unobscured by the actual HUD: " + str(world))

func click_map(world: Vector2) -> bool:
 if not aim(world):
  return false
 var p := screen(world)
 button(p, true)
 button(p, false)
 await settle()
 return true

func make_city():
 var city = City.new(120, 120, 42)
 city.population_enabled = false
 city.happiness_enabled = false
 city.funds = 1000000 + ceili(city.public_facilities.price(STOP))
 return city

func replace_city(focus: Vector2, zoom: float) -> void:
 # The startup scene really boots a worker. main._exit_tree can only join its
 # current model, so explicitly join the outgoing one before changing ownership.
 game.traffic.stop()
 if game.city.simulation != null:
  game.city.simulation.shutdown()
 game.city = make_city()
 game.map_zoom = zoom
 game.origin = Vector2.ZERO
 game.origin = Vector2(960, 411) - screen(focus)
 game.refresh()
 await settle(6)

func road_by_id(id: int) -> Dictionary:
 for road: Dictionary in game.city.roads:
  if int(road.parcel_id) == id:
   return road
 return {}

func points_match(points: PackedVector2Array, a: Vector2, b: Vector2) -> bool:
 return points.size() == 2 and points[0].distance_to(a) <= EPS and points[1].distance_to(b) <= EPS

func road_is(road: Dictionary, variant: String, lanes: int, width_m: float, a: Vector2, b: Vector2) -> bool:
 return (not road.is_empty() and str(road.get("road_variant", "")) == variant
  and (not variant.is_empty() or not road.has("road_variant"))
  and road.kind == "local" and road.travel_dir == 1 and road.lanes == lanes
  and absf(float(road.width)*4.0 - width_m) <= 0.001 and points_match(road.points, a, b)
  and Array(road.get("heights_m", PackedFloat64Array())).all(func(h): return absf(float(h)) <= EPS))

func branch(a: Vector2, b: Vector2, eight: bool) -> Dictionary:
 var count: int = game.city.roads.size()
 var revision: int = game.city.road_topology_revision
 var result: Dictionary = game.city.add_branch_one_way(PackedVector2Array([a, b]),
  Profile.BranchVariant.EIGHT_METRE if eight else Profile.BranchVariant.SIX_METRE)
 if not check(result.get("ok", false) and not result.get("queued", false)
  and game.city.roads.size() == count + 1 and game.city.road_topology_revision == revision + 1,
  "branch producer committed one authoritative road: " + str(result.get("reason", ""))):
  return {}
 var road: Dictionary = game.city.roads.back()
 if not check(road_is(road, EIGHT if eight else SIX, 2 if eight else 1, 8.0 if eight else 6.0, a, b), "producer stored the exact directed branch record"):
  return {}
 return road.duplicate(true)

func open_category(id: String) -> bool:
 if not game.drawer.visible or game.chosen != id:
  if not await click_control(control("Bottom_" + id), "category " + id):
   return false
 return check(game.drawer.visible and game.chosen == id, "real drawer shows " + id)

func road_strip() -> ScrollContainer:
 return control("RoadCardStrip") as ScrollContainer

func check_card_inventory() -> bool:
 var strip := road_strip()
 if not check(strip != null and strip.is_visible_in_tree() and strip.has_node("Cards"), "real road-card strip is populated"):
  return false
 var expected: Array[String] = []
 for count in range(2, 9):
  expected.append("RoadLane_%d" % count)
 for count in range(1, 5):
  expected.append("RoadOneWay_%d" % count)
 var central_lanes := [4, 6, 8]
 for count in central_lanes:
  expected.append("RoadCenter_%d" % count)
 var got: Array[String] = []
 for child in strip.get_node("Cards").get_children():
  got.append(str(child.name))
 if not check(got == expected and game.road_lane_cards.size() == 14, "exactly 7 ordinary + 4 one-way + 3 central cards; no hidden branch cards: " + str(got)):
  return false
 var cards_ok := true
 for i in range(got.size()):
  var card := strip.get_node("Cards").get_child(i) as Button
  if card == null:
   cards_ok = false
   break
  var center := i >= 11
  var directed := i >= 7 and not center
  var lanes: int = central_lanes[i - 11] if center else (i - 6 if directed else i + 2)
  var id := ("center-%d" if center else ("one-way-%d" if directed else "local-%d")) % lanes
  cards_ok = cards_ok and card.get_meta("lanes", -1) == lanes and card.get_meta("travel_dir", -1) == int(directed) and card.get_meta("center_tool", false) == center
  cards_ok = cards_ok and card.get_meta("thumbnail_asset_id", "") == "road-" + id and card.get_meta("source_preview", "") == "res://assets/ui/roads/" + id + ".png"
  cards_ok = cards_ok and not card.has_meta("road_variant") and not card.has_meta("branch_variant")
 return check(cards_ok, "actual menu records retain approved family IDs and no branch selection metadata")

func choose_one_way(lanes: int) -> bool:
 var strip := road_strip()
 var card := control("RoadOneWay_%d" % lanes) as Button
 if not check(strip != null and card != null, "normal one-way %d card exists" % lanes):
  return false
 var view := strip.get_global_rect()
 var bar := strip.get_h_scroll_bar()
 if bar.visible:
  view.size.y -= bar.size.y
 var zoom: float = game.map_zoom
 for i in range(20):
  var bounds := card.get_global_rect()
  if view.grow(1.0).encloses(bounds):
   break
  var wheel := MOUSE_BUTTON_WHEEL_DOWN if bounds.end.x > view.end.x else MOUSE_BUTTON_WHEEL_UP
  var p := view.get_center()
  var old := strip.scroll_horizontal
  move(p)
  button(p, true, wheel)
  button(p, false, wheel)
  await settle()
  if strip.scroll_horizontal == old:
   break
 if not check(view.grow(1.0).encloses(card.get_global_rect()) and is_equal_approx(zoom, game.map_zoom), "viewport scroll reveals the complete normal card without zooming the map"):
  return false
 if not await click_control(card, "ordinary one-way %d card" % lanes):
  return false
 return check(game.mode == "road" and card.button_pressed and game.road_lanes == lanes and game.road_drawer.travel_dir == 1
  and game.road_drawer.anchors.is_empty(), "existing card armed a fresh ordinary one-way stroke")

func grid_off() -> bool:
 var toggle := control("RoadGridToggle") as Button
 if not check(toggle != null, "existing grid switch found"):
  return false
 if toggle.button_pressed and not await click_control(toggle, "road grid switch"):
  return false
 return check(not toggle.button_pressed and not game.road_grid_enabled and game.road_drawer.kind == "straight", "real straight tool is in grid OFF mode")

func edit_snapshot() -> PackedByteArray:
 return var_to_bytes([game.city.roads, game.city.road_topology_revision, game.city.next_road_id,
  game.city.buildings, game.city.public_facilities.lots, game.city.funds, game.city.next_id])

func start_preview(a: Vector2, b: Vector2, lanes: int) -> Dictionary:
 var before := edit_snapshot()
 if not await click_map(a):
  return {}
 if not check(game.road_drawer.anchors.size() == 1 and game.road_drawer.anchors[0].distance_to(a) <= EPS and edit_snapshot() == before,
  "first viewport click accepts the exact authored endpoint without mutation"):
  return {}
 if not aim(b):
  return {}
 var plan: Dictionary = game.road_drawer.preview()
 if not check(plan.get("ok", false) and points_match(plan.get("points", PackedVector2Array()), a, b)
  and plan.get("travel_dir", 0) == 1 and plan.get("lanes", 0) == lanes and plan.get("grid_frame", {"missing": true}).is_empty()
  and absf(float(plan.width)*4.0 - (12.0 if lanes == 2 else 6.0)) <= 0.001 and edit_snapshot() == before,
  "preview uses the exact independent grid-off targets and selected ordinary profile: " + str(plan.get("reason", ""))):
  return {}
 return plan

func extend_ui(a: Vector2, b: Vector2, lanes: int) -> Dictionary:
 if not await choose_one_way(lanes):
  return {}
 var plan := await start_preview(a, b, lanes)
 if plan.is_empty() or not check(not plan.get("warning", false) and game.road_drawer.preview_colors(true, false).outline == Color("3ddc84"), "unobstructed stroke uses the established green preview, not Warning B"):
  return {}
 var revision: int = game.city.road_topology_revision
 var count: int = game.city.roads.size()
 var next_id: int = game.city.next_road_id
 var sources := var_to_bytes(game.city.roads)
 if not await click_map(b):
  return {}
 if not check(game.city.roads.size() == count + 1 and game.city.road_topology_revision == revision + 1,
  "second real click adds one road in one topology revision"):
  return {}
 var road := road_by_id(next_id)
 if not check(road_is(road, "", lanes, 12.0 if lanes == 2 else 6.0, a, b) and road.points == plan.points
  and var_to_bytes(game.city.roads.slice(0, count)) == sources and game.message.is_empty(),
  "ordinary continuation stores approved preview and untouched source lineage, without inheriting branch metadata"):
  return {}
 return road.duplicate(true)

func idle_view() -> bool:
 await key(KEY_ESCAPE)
 if game.drawer.visible:
  if not await click_control(game.drawer_box.get_child(-1) as Control, "existing drawer close"):
   return false
 # RoadDrawer consumes Escape to drop anchors, Bottom UI owns exit. Use actual
 # right click if the road tool still owns the map after those transitions.
 if game.mode in ["road", "public_placement"]:
  var p := Vector2(110, 435)
  move(p)
  if not check(root.gui_get_hovered_control() == null, "idle map gesture is unobscured"):
   return false
  button(p, true, MOUSE_BUTTON_RIGHT)
  button(p, false, MOUSE_BUTTON_RIGHT)
  await settle()
 # Opening then closing the existing neutral category removes road-grid and
 # approach overlays without changing renderer settings or inventing a HUD.
 if not await open_category("transport"):
  return false
 if not await click_control(game.drawer_box.get_child(-1) as Control, "transport drawer close"):
  return false
 move(Vector2(110, 435))
 await settle()
 return check(not game.drawer.visible and game.mode == "select" and not game.transit_view.underground
  and not game.show_zoning_tiles() and game.road_drawer.anchors.is_empty() and game.road_drawer.pending.is_empty(),
  "capture uses ordinary ground view with no drawer, ghost, drag, grid or pending warning")

func world_visible(p: Vector2) -> bool:
 var pixel := screen(p)
 return root.get_visible_rect().grow(-24).has_point(pixel) and not game.dock.get_global_rect().grow(8).has_point(pixel)

func road_in_frame(road: Dictionary) -> bool:
 var a: Vector2 = road.points[0]
 var b: Vector2 = road.points[-1]
 var right := (b-a).normalized().orthogonal()
 # Include end caps and the full width, not just the centerline.
 var along := (b-a).normalized()
 var margin := float(road.width)/2.0 + 0.35
 return (world_visible(a-along*margin+right*margin) and world_visible(a-along*margin-right*margin)
  and world_visible(b+along*margin+right*margin) and world_visible(b+along*margin-right*margin))

func point_in(shapes: Array, point: Vector2) -> bool:
 return shapes.any(func(poly): return Geometry2D.is_point_in_polygon(point, poly))

func check_retained_stripes(bands: Array, end_x: float) -> bool:
 # Read the retained shapes consumed by the real Roads canvas in the current
 # renderer, even in rehearsal. The framebuffer has its own later color test.
 var emitted: Array = game.world_renderer.road_shapes.filter(func(shape): return shape[1] == Color("e4bd5f"))
 var marks: Array = game.city.road_branch_edge_marks
 if not check(not marks.is_empty() and emitted.size() == marks.size()
  and emitted.map(func(shape): return shape[0]) == marks.map(func(poly): return game.world_renderer.project(poly)),
  "final branch paint reaches the retained road canvas without replacement or duplication"):
  return false
 var covered_polys := 0
 for band: Vector2 in bands:
  # band.x = road centreline y; band.y = untapered curb offset (m).
  var end := -INF
  for poly: PackedVector2Array in marks:
   if Array(poly).all(func(p): return p.y > band.x + 0.35 and p.y < band.x + 1.2):
    covered_polys += 1
    for p: Vector2 in poly:
     end = maxf(end, p.x)
  if not check(absf(end-end_x) <= EPS, "retained yellow reaches but does not overrun the authored branch end at y=%.2f" % band.x):
   return false
  for x: float in [38.335, 44.135, 45.713]:
   var mid := Vector2(x, band.x + (band.y-0.16)/4.0)
   if not check(marks.filter(func(poly): return Geometry2D.is_point_in_polygon(mid, poly)).size() == 1,
    "exactly one retained yellow stripe immediately inside the branch curb at " + str(mid)):
    return false
 return check(covered_polys == marks.size(), "no retained yellow polygon lies on an inner flank or ordinary road")

func section_probes(y: float, x: float, half_m: float, outside_curb_m: float) -> bool:
 var asphalt: Array = game.city.road_asphalt + game.city.junction_asphalt
 var pavement: Array = game.city.road_pavement + game.city.junction_pavement
 var walk := Vector2(x, y + (half_m+outside_curb_m)/8.0)
 var inner := Vector2(x, y - (half_m-0.20)/4.0)
 var beyond := Vector2(x, y - (half_m+0.20)/4.0)
 var outer := Vector2(x, y + (half_m+0.20)/4.0)
 return (point_in(pavement, walk) and not point_in(asphalt, walk) and point_in(asphalt, inner)
  and not point_in(pavement, beyond) and not point_in(pavement, outer))

func lanes_for(road: Dictionary) -> Array:
 var index := -1
 for i in range(game.city.roads.size()):
  if game.city.roads[i].parcel_id == road.parcel_id:
   index = i
   break
 if index < 0:
  return []
 return game.traffic.network.lanes.filter(func(l): return int(l.road) == index)

func moving_kinds(roads: Array) -> bool:
 if not check(game.traffic.rebuild(game.city.roads), "production traffic builds the exact three sample roads"):
  return false
 var sim = game.traffic.simulation
 var probes: Array[Dictionary] = []
 var assets := ["car-hatch-01", "car-sedan-03", "car-wagon-04"]
 for i in range(roads.size()):
  var lanes := lanes_for(roads[i])
  if not check(lanes.size() == (2 if i == 1 else 1) and lanes.all(func(l): return l.direction == 1 and l.next.is_empty()),
   "strip %d has only authored forward lanes and legal dead ends" % (i+1)):
   return false
  var candidates: Array = game.traffic.catalog.filter(func(asset): return asset.id == assets[i])
  if not check(candidates.size() == 1, "strip uses existing traffic art " + assets[i]):
   return false
  var lane: Dictionary = lanes[0]
  var car: Dictionary = sim.spawn(candidates[0], [lane.id], float(lane.length)*[0.25, 0.49, 0.68][i])
  if not check(not car.is_empty(), "real car spawned on strip %d" % (i+1)):
   return false
  probes.append({"car": car, "lane": lane.id, "start": sim.position(car), "last": sim.position(car), "forward": true})
 # main._process is deliberately not advancing variable time. These are real
 # traffic steps, not synthetic poses or a wall-clock measurement.
 for i in range(54):
  game.traffic.update(1.0/30.0)
  for row in probes:
   var p: Vector2 = sim.position(row.car)
   row.forward = row.forward and p.x >= row.last.x - EPS and sim.heading(row.car).x > 0.99 and row.car.lane == row.lane
   row.last = p
 sim.paused = true
 await settle()
 var all_ok := true
 for row in probes:
  var sprite: Sprite2D = game.world_renderer.cars.get(row.car.id)
  var ready := sprite != null and sprite.is_visible_in_tree() and sprite.texture != null
  if ready:
   var box := sprite.get_global_transform() * sprite.get_rect()
   ready = root.get_visible_rect().grow(-24).encloses(box) and not game.dock.get_global_rect().grow(8).intersects(box)
  all_ok = check(row.forward and row.car.speed > 0.0 and row.last.x - row.start.x > 1.0 and ready,
   "real traffic moved forward and its full retained sprite is visible on lane %d" % row.lane) and all_ok
 return all_ok

func composition_kinds() -> void:
 await replace_city(Vector2(52.25, 45.25), 1.85)
 var roads: Array = []
 for i in range(2):
  var start := Vector2(KINDS_X, KINDS_Y[i])
  var r := branch(start, start+Vector2(34, 0), i == 1)
  if r.is_empty():
   return
  roads.append(r)
 if not await open_category("road") or not check_card_inventory() or not await grid_off():
  return
 var a := Vector2(KINDS_X, KINDS_Y[2])
 var normal := await extend_ui(a, a+Vector2(34,0), 1)
 if normal.is_empty():
  return
 roads.append(normal)
 if not check(game.city.roads.size() == 3 and game.city.junctions.is_empty() and game.city.road_joins.is_empty()
  and game.city.public_facilities.lots.is_empty(), "kinds composition has only three isolated parallel strokes, no facility or junction"):
  return
 if not await idle_view():
  return
 for i in range(3):
  if not check(road_in_frame(roads[i]) and section_probes(KINDS_Y[i], 51.25, 4.0 if i == 1 else 3.0, 3.0 if i == 1 else 2.25),
   "entire strip %d in frame; production asphalt/pavement has only the outside walk" % (i+1)):
   return
 if not check_retained_stripes([Vector2(KINDS_Y[0], 2.25), Vector2(KINDS_Y[1], 3.0)], KINDS_X+34.0) or not await moving_kinds(roads):
  return
 if outputs.has("kinds"):
  var image := await frame()
  if image == null or not check_kinds_stripes(image):
   return
  images["kinds"] = image
 kinds_done = true

func check_taper(branch8: Dictionary, normal8: Dictionary, branch6: Dictionary, normal6: Dictionary) -> bool:
 var taper_count := 0
 for join: Dictionary in game.city.road_joins:
  if join.get("taper", false) and Vector2(join.position).distance_to(branch8.points[-1]) <= EPS:
   taper_count += 1
 if not check(game.city.junctions.is_empty() and game.city.road_joins.size() == 1 and taper_count == 1
  and game.city.road_crosswalks.is_empty() and game.city.road_stop_lines.is_empty(),
  "8→12 widens in one uncontrolled taper; 6→6 is continuous; no zebra, stop line or junction"):
  return false
 if not check(game.traffic.rebuild(game.city.roads), "real lane network accepts both continuations"):
  return false
 var network = game.traffic.network
 var asphalt: Array = game.city.road_asphalt + game.city.junction_asphalt
 var inbound := lanes_for(branch8)
 var outbound := lanes_for(normal8)
 if not check(inbound.size() == 2 and outbound.size() == 2, "two forward approaches and two forward exits, not just two connectors"):
  return false
 var rights8 := [-2.25, 1.25]
 var rights12 := [-1.75, 1.75]
 var seam_m: Vector2 = branch8.points[-1]*4.0
 for first: Dictionary in inbound:
  var choices := outbound.filter(func(l): return l.index == first.index)
  if not check(int(first.index) in [0, 1] and first.direction == 1 and choices.size() == 1 and first.next.size() == 1,
   "one destination per travel-side lane %d" % first.index):
   return false
  var last: Dictionary = choices[0]
  var link: Dictionary = network.lanes[first.next[0]]
  var p: Vector2 = network.sample(first.id, first.length)
  var q: Vector2 = network.sample(last.id, 0.0)
  if not check(last.direction == 1 and last.next.is_empty() and link.get("transition", false) and link.junction < 0
   and link.get("from", -1) == first.id and link.get("to", -1) == last.id and link.next == [last.id]
   and p.x < seam_m.x and q.x > seam_m.x and absf(p.y-seam_m.y-rights8[first.index]) <= 0.001
   and absf(q.y-seam_m.y-rights12[first.index]) <= 0.001
   and p.distance_to(network.sample(link.id, 0.0)) <= 0.001 and q.distance_to(network.sample(link.id, link.length)) <= 0.001,
   "uncontrolled 1:1 taper lane %d preserves exact signed offsets and endpoint joins" % first.index):
   return false
  var samples := maxi(1, ceili(float(link.length)/0.25))
  for i in range(samples+1):
   if not point_in(asphalt, network.sample(link.id, float(link.length)*i/samples)/4.0):
    return check(false, "actual taper lane %d escaped the rendered asphalt at sample %d" % [first.index, i])
  check(true, "taper lane %d stays in the real asphalt union at 0.25m steps" % first.index)
 var six_in := lanes_for(branch6)
 var six_out := lanes_for(normal6)
 return check(six_in.size() == 1 and six_out.size() == 1 and six_in[0].direction == 1 and six_out[0].direction == 1
  and six_in[0].next == [six_out[0].id] and six_out[0].next.is_empty()
  and Vector2(network.sample(six_in[0].id, six_in[0].length)).distance_to(network.sample(six_out[0].id, 0.0)) <= 0.001,
  "6m branch and matching ordinary record have a direct forward lane with no geometric gap")

func place_stop(host: Dictionary) -> Dictionary:
 if not await open_category("transport"):
  return {}
 if game.transport_tab != 0:
  if not await click_control(game.transport_tabs.get_child(0) as Control, "existing bus transport subtab"):
   return {}
 if not await click_control(control("Facility_" + STOP), "existing bus-stop card"):
  return {}
 if not check(game.mode == "public_placement" and game.public_controller.asset_id == STOP and not game.drawer.visible,
  "actual card arms public placement and clears the drawer"):
  return {}
 var before := edit_snapshot()
 var inside := Vector2(STOP_CURB.x, CONT_Y8 - 0.99)
 if not aim(inside):
  return {}
 var rejected: Dictionary = game.public_controller.preview()
 if not check(not rejected.get("ok", false) and rejected.get("code", "") == "sidewalk" and edit_snapshot() == before,
  "branch inner flank has no bus-stop host in real pointer preview"):
  return {}
 if not aim(STOP_CURB):
  return {}
 var preview: Dictionary = game.public_controller.preview()
 if not check(preview.get("ok", false) and preview.record.front_road_id == host.parcel_id and preview.record.road_direction == 1
  and Vector2(preview.record.position).distance_to(STOP_CURB) <= EPS and edit_snapshot() == before,
  "outside curb preview binds the exact eight-metre road, direction and curb point: " + str(preview.get("reason", ""))):
  return {}
 var funds: int = game.city.funds
 var id: int = game.city.next_id
 var revision: int = game.city.road_topology_revision
 if not await click_map(STOP_CURB):
  return {}
 if not check(game.city.public_facilities.lots.size() == 1 and game.public_controller.last_result.get("ok", false), "viewport click commits exactly one bus stop"):
  return {}
 var lot: Dictionary = game.city.public_facilities.lots[0]
 if not check(lot.id == id and game.city.next_id == id + 1 and lot.public_asset_id == STOP and lot.front_road_id == host.parcel_id
  and lot.road_direction == 1 and Vector2(lot.curb_point).distance_to(STOP_CURB) <= EPS and lot.front_direction == Vector2.UP
  and game.city.funds == funds-int(preview.cost) and game.city.road_topology_revision == revision,
  "real stop charges exactly once, faces its host and does not change road topology"):
  return {}
 return lot.duplicate(true)

func stop_in_frame(lot: Dictionary) -> bool:
 var sprite: Sprite2D = game.world_renderer.buildings.get(lot.id)
 if not check(sprite != null, "production renderer owns a stop sprite"):
  return false
 if DisplayServer.get_name() == "headless":
  return check(Array(lot.polygon).all(func(p): return world_visible(p)), "stop footprint is fully in frame (texture check is native-only)")
 # Imported directional views are queued by BuildingViews. Bounded frame wait
 # for the real texture, not a fallback or extra framebuffer read by this test.
 for i in range(90):
  if sprite.texture != null:
   break
  await process_frame
 if not check(sprite.texture != null and sprite.is_visible_in_tree(), "the single bus stop has its real rendered art"):
  return false
 var box := sprite.get_global_transform() * sprite.get_rect()
 return check(root.get_visible_rect().grow(-24).encloses(box) and not game.dock.get_global_rect().grow(8).intersects(box), "stop art is entirely in the exact composition")

func composition_continue() -> void:
 await replace_city(Vector2(53.25, 46.75), 1.76)
 var a8 := Vector2(32.25, CONT_Y8)
 var seam8 := Vector2(48.25, CONT_Y8)
 var end8 := Vector2(73.25, CONT_Y8)
 var a6 := Vector2(32.25, CONT_Y6)
 var seam6 := Vector2(48.25, CONT_Y6)
 var end6 := Vector2(73.25, CONT_Y6)
 var branch8 := branch(a8, seam8, true)
 var branch6 := branch(a6, seam6, false)
 if branch8.is_empty() or branch6.is_empty():
  return
 if not await open_category("road") or not check_card_inventory() or not await grid_off():
  return
 # 25 cells = 100 m: valid 4 m continuation increments but NOT 8 m new-stroke
 # increments. All endpoints have quarter-cell components; no rounded oracle.
 var normal8 := await extend_ui(seam8, end8, 2)
 if normal8.is_empty():
  return
 var normal6 := await extend_ui(seam6, end6, 1)
 if normal6.is_empty() or not check_taper(branch8, normal8, branch6, normal6):
  return
 if not check(not Profile.allows_roadside_parking(branch8, 1) and not Profile.allows_roadside_parking(branch6, 1)
  and Profile.allows_roadside_parking(normal8, 1) and Profile.allows_roadside_parking(normal6, 1),
  "both normal continuations use their own parking rule, never the hidden branch prohibition"):
  return
 if not check_retained_stripes([Vector2(CONT_Y8, 3.0), Vector2(CONT_Y6, 2.25)], seam8.x):
  return
 # Network validation owns a live traffic instance; the continuation brief
 # requests a clean taper and one stop, not a second set of traffic assets.
 game.traffic.stop()
 var lot := await place_stop(branch8)
 if lot.is_empty() or not await idle_view():
  return
 var frame_ok: bool = game.city.roads.size() == 4 and game.city.public_facilities.lots.size() == 1
 for r: Dictionary in [branch8, normal8, branch6, normal6]:
  frame_ok = frame_ok and road_in_frame(r)
 if not check(frame_ok, "continue composition contains only both full continuations and the single placed stop") or not await stop_in_frame(lot):
  return
 if outputs.has("continue"):
  var image := await frame()
  if image == null or not check_continue_stripes(image):
   return
  images["continue"] = image
 continue_done = true
 await demolition(branch8, normal8, branch6, normal6, lot)

func cut_matches(cut: Dictionary, id: int, a: Vector2, b: Vector2) -> bool:
 return cut.get("id", -1) == id and points_match(cut.get("points", PackedVector2Array()), a, b)

func demolition(branch8: Dictionary, normal8: Dictionary, branch6: Dictionary, normal6: Dictionary, stop: Dictionary) -> void:
 if not await click_control(game.bulldozer, "existing bulldozer") or not check(game.mode == "demolish", "HUD arms real demolition mode"):
  return
 var hit := Vector2(43.55, CONT_Y8)
 var drag := hit + Vector2(0.8, 0)
 var cut_end := hit + Vector2(2, 0)
 if not aim(hit) or not check(game.demolition_hover.get("id", -1) == branch8.parcel_id, "viewport resolves eight-metre branch ID"):
  return
 if not check(world_visible(drag), "drag release fits the actual viewport and dock"):
  return
 var before := edit_snapshot()
 var next_id: int = game.city.next_road_id
 var revision: int = game.city.road_topology_revision
 var start_px := screen(hit)
 var end_px := screen(drag)
 button(start_px, true)
 move(end_px, MOUSE_BUTTON_MASK_LEFT)
 var cuts: Array = game.demolition_hover.get("selection", {}).get("cuts", [])
 var preview_ok := check(cuts.size() == 1 and cut_matches(cuts[0], branch8.parcel_id, hit, cut_end) and before == edit_snapshot(),
  "held 3.2m viewport drag previews exactly 8m on the eight-metre branch, with no mutation")
 button(end_px, false)
 await settle()
 if not preview_ok:
  return
 var left := road_by_id(branch8.parcel_id)
 var right := road_by_id(next_id)
 if not check(game.city.roads.size() == 5 and game.city.next_road_id == next_id + 1 and game.city.road_topology_revision == revision + 1
  and road_is(left, EIGHT, 2, 8.0, branch8.points[0], hit) and road_is(right, EIGHT, 2, 8.0, cut_end, branch8.points[-1])
  and int(left.get("zoning_source_id", -1)) == branch8.parcel_id and int(right.get("zoning_source_id", -1)) == branch8.parcel_id
  and road_by_id(normal8.parcel_id) == normal8 and road_by_id(branch6.parcel_id) == branch6 and road_by_id(normal6.parcel_id) == normal6
  and game.city.public_facilities.lots.size() == 1 and game.city.public_facilities.lots[0] == stop,
  "release splits only branch 8, preserves variant/direction/lineage on both fragments and keeps the stop"):
  return
 var hit6 := Vector2(39.25, CONT_Y6)
 if not aim(hit6) or not check(game.demolition_hover.get("id", -1) == branch6.parcel_id, "viewport resolves six-metre branch ID"):
  return
 before = edit_snapshot()
 revision = game.city.road_topology_revision
 var px := screen(hit6)
 button(px, true)
 cuts = game.demolition_hover.get("selection", {}).get("cuts", [])
 # Normal bulldozer clicks traverse collinear two-arm joins, including this
 # 6→6 seam. Do not silently expect only the branch to disappear.
 var click_ok := check(cuts.size() == 2 and before == edit_snapshot()
  and cuts.any(func(c): return cut_matches(c, branch6.parcel_id, branch6.points[0], branch6.points[-1]))
  and cuts.any(func(c): return cut_matches(c, normal6.parcel_id, normal6.points[0], normal6.points[-1])),
  "six-metre press selects the existing continuous span, and deletes nothing until release")
 button(px, false)
 await settle()
 demolition_done = check(click_ok and game.city.roads.size() == 3 and game.city.road_topology_revision == revision + 1
  and road_by_id(branch6.parcel_id).is_empty() and road_by_id(normal6.parcel_id).is_empty()
  and road_by_id(left.parcel_id) == left and road_by_id(right.parcel_id) == right and road_by_id(normal8.parcel_id) == normal8
  and game.city.public_facilities.lots.size() == 1 and game.city.public_facilities.lots[0] == stop and game.message.is_empty(),
  "click release only removes the selected six-metre corridor; both 8m survivors, taper approach and stop are unchanged")

func warning() -> void:
 # Clear bulldozer via the real HUD before replacing the model.
 if not await click_control(game.bulldozer, "leave bulldozer"):
  return
 await replace_city(Vector2(54.25, 47.25), 1.35)
 var a := Vector2(32.25, 46.25)
 var seam := Vector2(48.25, 46.25)
 var end := Vector2(73.25, 46.25)
 var original := branch(a, seam, true)
 if original.is_empty():
  return
 var support: Dictionary = game.city.add_road(PackedVector2Array([Vector2(49,50.5), Vector2(78,50.5)]))
 if not check(support.get("ok", false) and game.city.roads.size() == 2, "Warning B has legal independent building frontage"):
  return
 var frontage: Dictionary = game.city.roads[-1].duplicate(true)
 var affected: Dictionary = game.city.add_building(54, 47)
 var untouched: Dictionary = game.city.add_building(54, 52)
 if not check(affected.get("ok", false) and untouched.get("ok", false), "real model legally places one affected private lot and one outside control"):
  return
 var affected_id: int = affected.building.id
 var untouched_id: int = untouched.building.id
 var untouched_copy: Dictionary = untouched.building.duplicate(true)
 game.refresh()
 await settle()
 if not await open_category("road") or not await grid_off():
  return
 var ids := [affected_id]
 for phase: String in ["Cancel", "Stale", "Confirm"]:
  if not await choose_one_way(2):
   return
  var plan := await start_preview(seam, end, 2)
  if plan.is_empty() or not check(plan.get("warning", false) and Array(plan.get("demolish_ids", [])) == ids
   and game.road_drawer.preview_colors(true, true).outline == Color("e6c442"),
   "ordinary continuation warning names exactly the affected private lots before " + phase):
   return
  var before := edit_snapshot()
  if not await click_map(end):
   return
  var panel := control("RoadDemolitionWarning")
  if not check(panel != null and panel.is_visible_in_tree() and edit_snapshot() == before,
   "real Warning B blocks mutation until action: " + phase):
   return
  var badge := panel.find_child("DemolitionCount", true, false) as Label
  if not check(badge != null and badge.text == str(ids.size()), "visible warning badge matches the exact ID set"):
   return
  if phase == "Stale":
   # Simulate a valid world edit while the management warning is open, not an
   # injected bad plan: the same street can now hit a second real zoned lot.
   var extra: Dictionary = game.city.add_building(62, 47)
   if not check(extra.get("ok", false), "a new real intersecting lot invalidates the offered approval"):
    return
   ids.append(extra.building.id)
   ids.sort()
   before = edit_snapshot()
  if not await click_control(panel.find_child("Cancel" if phase == "Cancel" else "Confirm", true, false) as Control, "Warning B " + phase):
   return
  if not check(control("RoadDemolitionWarning") == null and game.road_drawer.pending.is_empty(), "real Warning B closes after " + phase):
   return
  if phase != "Confirm":
   if not check(edit_snapshot() == before, "cancel or stale confirmation leaves roads, IDs, buildings and funds unchanged: " + phase):
    return
  else:
   var all_removed: bool = ids.all(func(id): return game.city.find_building(id).is_empty())
   warning_done = check(all_removed and game.city.buildings.size() == 1 and game.city.find_building(untouched_id) == untouched_copy
    and game.city.roads.size() == 3 and road_by_id(original.parcel_id) == original and road_by_id(frontage.parcel_id) == frontage
    and road_is(game.city.roads[-1], "", 2, 12.0, seam, end) and game.message.is_empty(),
    "fresh confirm removes only the accepted IDs and builds the exact ordinary 12m continuation")

func yellow_near(image: Image, world: Vector2) -> bool:
 var center := screen(world)
 var pixel := Vector2i(center.floor())
 if not Rect2i(Vector2i.ZERO, image.get_size()).grow(-1).has_point(pixel):
  return false
 for y in range(pixel.y-1, pixel.y+2):
  for x in range(pixel.x-1, pixel.x+2):
   var c := image.get_pixel(x, y)
   # Chroma rejects the existing white shoulder/arrow paint and gray pavement;
   # accept the retained yellow family, including its antialiased edge.
   if c.r > 0.50 and c.r > c.g + 0.025 and c.g > c.b + 0.075:
    return true
 return false

func ink_samples(image: Image, first: float, y: float, edge_m: float, side: int) -> int:
 var count := 0
 for i in range(12):
  for inset_m: float in [0.04, 0.15, 0.26, 0.37, 0.48]:
   var point := Vector2(first + i*0.20, y + (edge_m - inset_m)*side/4.0)
   if yellow_near(image, point):
    count += 1
    break
 return count

func check_kinds_stripes(image: Image) -> bool:
 var ok := true
 for i in range(3):
  # Two windows avoid the car on each road. Probe only the actual road-edge
  # bands, so a UI pixel, existing white shoulder or centre arrow cannot pass.
  var outside := [ink_samples(image, 38.0, KINDS_Y[i], 3.0 if i == 1 else 2.25, 1),
   ink_samples(image, 63.0, KINDS_Y[i], 3.0 if i == 1 else 2.25, 1)]
  var inside := [ink_samples(image, 38.0, KINDS_Y[i], 4.0 if i == 1 else 3.0, -1),
   ink_samples(image, 63.0, KINDS_Y[i], 4.0 if i == 1 else 3.0, -1)]
  var expected := outside.all(func(n): return n >= 10) if i < 2 else outside == [0, 0]
  ok = check(expected and inside == [0, 0], "actual framebuffer shows yellow only beside the branch outside curbs: strip %d" % (i+1)) and ok
 return ok

func check_continue_stripes(image: Image) -> bool:
 # Sample safely away from the single stop, the seam itself, and end caps.
 return check(ink_samples(image, 44.0, CONT_Y8, 3.0, 1) >= 10 and ink_samples(image, 53.0, CONT_Y8, 5.25, 1) == 0
  and ink_samples(image, 44.0, CONT_Y6, 2.25, 1) >= 10 and ink_samples(image, 53.0, CONT_Y6, 2.25, 1) == 0,
  "actual framebuffer shows branch-side yellow and no yellow bleed onto either ordinary extension")

func frame() -> Image:
 await RenderingServer.frame_post_draw
 var img := root.get_texture().get_image()
 if not check(img != null and img.get_size() == VIEW, "raw actual viewport image is exactly 1920×1080"):
  return null
 return img

func fresh(path: String) -> bool:
 # Restrict by basename, explicit absolute path and an already-present parent;
 # never manufacture a parent or overwrite an earlier evidence file.
 return (path.is_absolute_path() and not path.begins_with("res://") and not path.begins_with("user://")
  and DirAccess.dir_exists_absolute(path.get_base_dir()) and not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path))

func configure_outputs() -> bool:
 var args := OS.get_cmdline_user_args()
 var rehearsal := "--fixture-check" in args
 for arg in args:
  if arg == "--fixture-check":
   continue
  var matched := false
  for name_value: String in CAPTURES:
   var prefix := "--e4b-%s-capture=" % name_value
   if not arg.begins_with(prefix):
    continue
   matched = true
   if rehearsal:
    break # even if capture arguments were accidentally repeated
   var path := arg.trim_prefix(prefix)
   if not check(not outputs.has(name_value) and path.get_file() == CAPTURES[name_value] and fresh(path), "fresh absolute path for " + CAPTURES[name_value]):
    return false
   outputs[name_value] = path
  if not check(matched, "recognized E4b capture option"):
   return false
 if outputs.is_empty():
  return true
 return check(outputs.size() == CAPTURES.size() and DisplayServer.get_name() != "headless"
  and RenderingServer.get_current_rendering_method() == "gl_compatibility" and RenderingServer.get_current_rendering_driver_name() == "opengl3"
  and root.size == VIEW and DisplayServer.window_get_size() == VIEW, "both captures require the same real 1920×1080 GL Compatibility/OpenGL3 process")

func save_outputs() -> void:
 for name_value: String in CAPTURES:
  var image: Image = images.get(name_value)
  if not check(image != null and image.get_size() == VIEW and fresh(outputs[name_value]), "verified frame and still-fresh target: " + str(outputs[name_value])):
   return
 for name_value: String in CAPTURES:
  var image: Image = images[name_value]
  if not check(image.save_png(outputs[name_value]) == OK, "saved requested raw framebuffer: " + str(outputs[name_value])):
   return

func run() -> void:
 if DisplayServer.get_name() == "headless":
  root.size = VIEW
 if not configure_outputs() or not check(root.size == VIEW and root.get_visible_rect().size == Vector2(VIEW), "fixture viewport is exactly 1920×1080"):
  finish()
  return
 game = MAIN.instantiate()
 game.city = make_city()
 game.paused = true
 root.add_child(game)
 current_scene = game
 # Preserve real _input/_unhandled_input, children, retained draws and GUI.
 # Only autonomous clock/traffic delta is stopped for a reproducible fixture.
 game.set_process(false)
 await settle(8)
 await composition_kinds()
 if failed == 0 and kinds_done:
  await composition_continue()
 if failed == 0 and continue_done and demolition_done:
  await warning()
 check(kinds_done and continue_done and demolition_done and warning_done,
  "completed both exact compositions, release-driven demolition and all three Warning B decisions")
 if failed == 0 and not outputs.is_empty():
  save_outputs()
 finish()

func finish() -> void:
 if is_instance_valid(game):
  game.free()
 game = null
 print("RESULT %d/%d branch one-way actual-viewport UI checks passed" % [passed, passed+failed])
 quit(1 if failed else 0)
