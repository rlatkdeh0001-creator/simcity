extends SceneTree

const City = preload("res://core/city_model.gd")
const Geometry = preload("res://core/road_geometry.gd")
const Topology = preload("res://core/road_junctions.gd")
const Parcels = preload("res://core/road_parcels.gd")
const FLEET_SIZE := 4800
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])

func covers(polygons: Array, p: Vector2) -> bool:
	return polygons.any(func(poly): return Geometry2D.is_point_in_polygon(p, poly))

func section(polygons: Array, x: float, y: float, edges_m: Vector2) -> bool:
	return covers(polygons, Vector2(x, y+edges_m.x/4+.001)) and covers(polygons, Vector2(x, y+edges_m.y/4-.001)) and not covers(polygons, Vector2(x, y+edges_m.x/4-.001)) and not covers(polygons, Vector2(x, y+edges_m.y/4+.001))

func add(city, a: Vector2, b: Vector2, lanes: int, travel: int = 1) -> bool:
	return city.add_road(path(a, b), "local", true, lanes, false, false, 1, {}, travel).ok

func shape_key(shapes: Array) -> Array:
	var keys := []
	for polygon in shapes:
		var vertices := []
		for p: Vector2 in polygon: vertices.append(str((p*1000).round()))
		vertices.sort()
		keys.append(str(vertices))
	keys.sort()
	return keys

func contained(shapes: Array, surfaces: Array) -> bool:
	return not shapes.is_empty() and shapes.all(func(poly):
		return Array(poly).all(func(p): return covers(surfaces, p)))

func render_geometry() -> void:
	var asphalt := [Vector2(-3,2.25), Vector2(-5.25,5.25), Vector2(-5.25,5.25), Vector2(-8.75,8.75)]
	var half := [3.0,6.0,6.0,10.0]
	for lanes in range(1,5):
		var city := City.new(110,100)
		verify(add(city,Vector2(10,40),Vector2(90,40),lanes),"construct directed profile %d" % lanes)
		verify(section(city.road_asphalt,45,40,asphalt[lanes-1]),"rendered signed asphalt edges %d" % lanes)
		verify(section(city.road_pavement,45,40,Vector2(-half[lanes-1],half[lanes-1])),"rendered full footprint %d" % lanes)
		verify(city.road_medians.is_empty() and not city.road_lane_marks.is_empty(),"white shoulder/lane paint, no median %d" % lanes)
	var reversed := City.new(110,100)
	verify(add(reversed,Vector2(90,40),Vector2(10,40),1) and section(reversed.road_asphalt,45,40,Vector2(-2.25,3)),"reversing one-lane stroke mirrors sidewalk edge")
	var curve := City.new(110,100)
	var bend := PackedVector2Array([Vector2(12,40),Vector2(47,40),Vector2(47,75)])
	verify(curve.add_road(bend,"local",true,1,false,false,1,{},1).ok,"construct one-lane curve with uncurbed outside edge")
	var spill := 0.0
	for shape in curve.road_asphalt:
		for piece in Geometry2D.clip_polygons(shape,curve.road_pavement[0]): spill+=Parcels.area(piece)
	verify(spill<.0001 and covers(curve.road_asphalt,Vector2(47.34,39.64)),"curved no-sidewalk asphalt shares the outer pavement edge without spilling (%.6f cells² outside)" % spill)
	for left_first in [true,false]:
		var city := City.new(110,100)
		var parts := [[Vector2(10,40),Vector2(41,40),1], [Vector2(41,40),Vector2(90,40),2]]
		if not left_first: parts.reverse()
		for part in parts: verify(add(city,part[0],part[1],part[2]),"construct directed taper arm")
		verify(city.road_joins.size()==1 and city.road_crosswalks.is_empty() and city.road_medians.is_empty(),"directed taper has no median or zebra")
		verify(section(city.road_asphalt,30,40,asphalt[0]) and covers(city.junction_asphalt,Vector2(39.05,39.251)) and not covers(city.junction_asphalt,Vector2(39.05,40.58)),"signed asphalt meets the narrow taper mouth")
		if city.get("road_direction_arrows")!=null:
			verify(city.road_direction_arrows.size()==6 and covers(city.road_direction_arrows,Vector2(42,40)),"one 64m phase crosses the taper without extra seam-end arrows")
		var mixed := City.new(110,100)
		var mixed_parts := [[Vector2(10,40),Vector2(39,40),0],[Vector2(39,40),Vector2(90,40),1]]
		if not left_first: mixed_parts.reverse()
		for part in mixed_parts: verify(add(mixed,part[0],part[1],2,part[2]),"construct same-width mixed-flow seam")
		verify(not mixed.road_medians.is_empty() and mixed.road_medians.all(func(line):return line[0].x<=39.001 and line[-1].x<=39.001),"mixed-flow median stops at the authored seam")

func shared_arrows() -> void:
	var city := City.new(110,100)
	verify(add(city,Vector2(10,40),Vector2(90,40),1),"construct long directed arrow fixture")
	var geometry: Variant = Geometry.new()
	if not geometry.has_method("direction_arrows") or city.get("road_direction_arrows") == null:
		verify(false,"preview arrow helper and cached world geometry are both wired")
		return
	var shapes: Array = city.road_direction_arrows
	verify(shape_key(shapes)==shape_key(geometry.direction_arrows(city.roads[0])),"preview and fixed arrow polygons are identical on an isolated stroke")
	verify(contained(shapes,city.road_asphalt),"all arrow vertices lie on the asymmetric asphalt")
	verify(shapes.size()==6 and covers(shapes,Vector2(26,39.6875)) and covers(shapes,Vector2(42,39.6875)),"two approaches plus 64m chainage, with the 80-cell endpoint deduplicated")
	verify(shapes.all(func(poly):return Geometry2D.triangulate_polygon(poly).size()>0),"arrow contours are drawable polygons")
	var reversed_visual: Dictionary = city.roads[0].duplicate(true)
	reversed_visual.points.reverse();reversed_visual.travel_dir=-1
	verify(shape_key(geometry.direction_arrows(reversed_visual))==shape_key(shapes),"reversing the visual points and travel sign preserves exact glyph placement and heading")
	for reverse in [false,true]:
		var split := City.new(110,100)
		var parts := [[Vector2(10,40),Vector2(41,40)], [Vector2(41,40),Vector2(90,40)]]
		if reverse: parts.reverse()
		for part in parts: verify(add(split,part[0],part[1],1),"construct split directed arrow fixture")
		verify(shape_key(split.road_direction_arrows)==shape_key(shapes),"split seam and build order do not restart arrow placement")
	var bend_keys := []
	for reverse in [false,true]:
		var bend := City.new(110,100)
		var parts := [[Vector2(10,40),Vector2(41,40)], [Vector2(41,40),Vector2(72,65)]]
		if reverse: parts.reverse()
		for part in parts: verify(add(bend,part[0],part[1],1),"construct bent directed arrow fixture")
		verify(bend.road_visuals.size()==1 and contained(bend.road_direction_arrows,bend.road_asphalt),"bent one-lane seam uses one arrow chain inside the actual asphalt")
		bend_keys.append(shape_key(bend.road_direction_arrows))
	verify(bend_keys[0]==bend_keys[1],"bent seam has order-independent chainage and direction")
	verify(add(city,Vector2(42,14),Vector2(42,85),2,0),"construct controlled one-way crossing")
	var clear := true
	for region in Topology.lane_mark_regions(city.junctions[0]):
		for arrow in city.road_direction_arrows:
			if not Geometry2D.intersect_polygons(region,arrow).is_empty(): clear = false
	verify(clear and not city.road_direction_arrows.is_empty(),"no flow arrows over controlled junction approaches, zebra or stop paint")
	verify(covers(city.road_direction_arrows,Vector2(39.32,39.6875)) and covers(city.road_direction_arrows,Vector2(44.68,39.6875)),"controlled crossing gets a glyph on each unobstructed approach")

func fleet_fixture(multiplier: int) -> Dictionary:
	var game = load("res://main.tscn").instantiate()
	var city := City.new(265,265)
	# Keep real roadside cells, but don't generate four rows of parcels along
	# every fleet lane's road: this fixture checks retained road/structure work.
	city.config.zoning_depth = 1.0
	game.city=city;game.paused=true
	var ok := true
	# Real off-ground structure records, separate from the vehicle lanes, also double.
	for i in range(multiplier):
		ok = city.add_elevated_road(path(Vector2(230,235+8*i),Vector2(254,235+8*i)),PackedFloat64Array([10,10])).ok and ok
		ok = city.add_elevated_road(path(Vector2(230,245+8*i),Vector2(254,245+8*i)),PackedFloat64Array([-10,-10])).ok and ok
	var first_road := city.roads.size()
	# Load parallel authored strokes together, then run the real road-dirty path.
	for i in range(12*multiplier):
		var row := float(10+9*i)
		city.roads.append({"kind":"local","lanes":4,"width":5.0,"travel_dir":1,"parcel_id":city.next_road_id,"points":path(Vector2(10,row),Vector2(230,row))})
		city.next_road_id+=1
	# A same-flow taper generates real from/to connectors with road = -1.
	if multiplier==2:
		city.roads.append({"kind":"local","lanes":2,"width":3.0,"travel_dir":1,"parcel_id":city.next_road_id,"points":path(Vector2(230,19),Vector2(250,19))})
		city.next_road_id+=1
	ok = add(city,Vector2(230,10),Vector2(250,10),2) and ok
	root.add_child(game)
	game.origin=Vector2(640,85);game.map_zoom=.085
	verify(ok and game.traffic.rebuild(city.roads),"perf: real %dx directed lane network, decks and tunnels" % multiplier)
	var render = game.world_renderer
	var simulation = game.traffic.simulation
	if simulation==null:return {"game":game,"ready":false}
	var lanes: Array = game.traffic.network.lanes.filter(func(lane):return lane.road>=first_road and lane.road<first_road+12*multiplier)
	var asset: Dictionary = game.traffic.catalog.filter(func(item):return item.id=="car-hatch-01")[0]
	var per_lane := int(FLEET_SIZE/float(48*multiplier))
	var fleet: Array[Dictionary] = []
	for lane in lanes:
		# Spawn checks collisions only within the same lane. Batch by lane to
		# avoid quadratic setup unrelated to retained renderer work.
		for i in range(per_lane):
			simulation.spawn(asset,[lane.id],12.0+8.0*i)
		fleet.append_array(simulation.vehicles)
		simulation.vehicles.clear()
	simulation.vehicles.append_array(fleet)
	var connector: Dictionary = {}
	for lane in game.traffic.network.lanes:
		if lane.road<0 and lane.transition:
			connector=lane
			break
	var ready: bool = simulation.vehicles.size()==FLEET_SIZE and not connector.is_empty()
	verify(ready,"perf: %dx fixture spawns exactly 4,800 real vehicles and a lane connector" % multiplier)
	if ready:
		# Place one seeded vehicle mid-transition on an actual valid network route.
		var vehicle: Dictionary = simulation.vehicles[0]
		vehicle.route=[connector.from,connector.id,connector.to];vehicle.route_index=1
		vehicle.lane=connector.id;vehicle.progress=connector.length*.2
	return {"game":game,"ready":ready,"render":render,"simulation":simulation}

func fleet_counts() -> void:
	var observed := []
	for multiplier in [1,2]:
		var fixture := fleet_fixture(multiplier)
		var game = fixture.game
		if not fixture.ready:
			game.free()
			continue
		var render = fixture.render
		var simulation = fixture.simulation
		if render.get("vehicle_road_lookups")==null or render.get("structure_generation")==null or render.get("direction_arrows")==null:
			verify(false,"perf: retained renderer reports real work and direction commands")
			game.free()
			continue
		var road_before: int = render.road_generation
		var structures_before: int = render.structure_generation
		var mesh: ArrayMesh = render.line_mesh
		var arrows: Array = render.direction_arrows
		verify(not arrows.is_empty() and arrows==game.city.road_direction_arrows.map(render.project),"perf: fixed draw layer projects the shared cached polygons exactly")
		render.synchronize();render._process(0)
		var lookups: int = render.vehicle_road_lookups
		var visible: int = render.cars.values().filter(func(sprite):return sprite.visible).size()
		var connector_sprite: Sprite2D = render.cars.get(simulation.vehicles[0].id)
		verify(visible==FLEET_SIZE and lookups==FLEET_SIZE and connector_sprite!=null and connector_sprite.get_meta("road_height_m")==0.0,"perf: %dx all 4,800 sprites, one actual owner lookup apiece including connector (%d visible, %d lookups)" % [multiplier,visible,lookups])
		verify(render.road_generation==road_before and render.structure_generation==structures_before,"perf: %dx steady sync performs zero fixed/structure rebuilds" % multiplier)
		var first_sprite: Sprite2D = render.cars[simulation.vehicles[1].id]
		var old_position := first_sprite.position
		var stable := true
		for frame in range(60):
			# Pose-only motion at safe in-lane spacings; no timing or FPS sampling.
			for vehicle in simulation.vehicles:
				vehicle.progress+=.01
			render._process(0)
			stable=stable and render.vehicle_road_lookups==FLEET_SIZE and render.road_generation==road_before and render.structure_generation==structures_before
		verify(stable and first_sprite.position!=old_position and render.line_mesh==mesh and is_same(render.direction_arrows,arrows),"perf: %dx 60 moving vehicle-only frames reuse fixed draw commands with zero fixed/structure rebuilds" % multiplier)
		verify(add(game.city,Vector2(10,240),Vector2(60,240),1),"perf: %dx positive road-dirty edit succeeds" % multiplier)
		render.synchronize()
		verify(render.road_generation==road_before+1 and render.structure_generation==structures_before+1 and render.direction_arrows.size()>0,"perf: %dx road edit triggers one real fixed and structure rebuild" % multiplier)
		observed.append([lookups,game.city.roads.size()-1,render.elevated.decks.size()])
		game.free()
	verify(observed.size()==2 and observed[0][0]==observed[1][0] and observed[1][1]==2*observed[0][1] and observed[0][2]>0 and observed[1][2]==2*observed[0][2],"perf: doubled roads and retained deck pieces leave owner lookup work unchanged: %s" % str(observed))

func run() -> void:
	root.size = Vector2i(1280,820)
	render_geometry()
	shared_arrows()
	if not "--geometry-only" in OS.get_cmdline_user_args(): fleet_counts()
	print("RESULT %d/%d one-way retained render checks passed" % [checks-failures,checks])
	quit(1 if failures else 0)
