extends SceneTree
const Model = preload("res://core/city_model.gd")
var count := 0
var failures := 0
func check(value: bool, description: String):
	count += 1
	if not value:
		failures += 1
		push_error(description)
	else:
		print("PASS ", description)
func _initialize():
	var city = Model.new(40, 40, 12)
	check(not city.add_building(1, 1).ok, "road access required")
	check(city.add_road(PackedVector2Array([Vector2(0.5, 20.3), Vector2(39, 20.3)])).ok, "continuous non-grid road")
	check(city.add_building(10, 17).ok, "new buildings start 2x2")
	check(not city.add_building(11, 17).ok, "overlap rejected")
	check(not city.add_building(39, 17).ok, "map boundary rejected")
	check(not city.add_building(10, 20).ok, "road width collision rejected")
	check(not city.add_road(PackedVector2Array([Vector2(11, 0), Vector2(11, 39)])).ok, "road cannot cut existing building")
	check(city.add_road(PackedVector2Array([Vector2(1.2, 2.5),Vector2(5.3, 6.7),Vector2(9.2, 5.1)])).ok, "free polyline supports curved strokes")
	var a: Dictionary = city.buildings[0]
	check(not city.upgrade_chain(a.id).ok, "root score threshold enforced")
	city.config.size_weights = {8: 1.0, 4: 0.0, 2: 0.0}
	a.score = 120
	check(city.upgrade_chain(a.id).ok and a.size == 8, "8x8 expansion searches valid free footprint")
	var chain = Model.new()
	chain.add_road(PackedVector2Array([Vector2(0, 20), Vector2(39, 20)]))
	for x in [10, 12, 14, 16]: chain.add_building(x, 17, "residential", 0)
	chain.config.size_weights = {8: 0.0, 4: 0.0, 2: 1.0}
	chain.config.neighbor_chance = 1.0
	chain.config.max_chain = 3
	chain.buildings[0].score = 100
	var result: Dictionary = chain.upgrade_chain(chain.buildings[0].id)
	check(result.events.size() == 3, "cascade cap terminates propagation")
	check(chain.buildings[1].level == 2 and chain.buildings[1].score == 0, "neighbor bypasses score threshold")
	check(chain.buildings[3].level == 1, "cap leaves remaining buildings unchanged")
	check(chain.buildings[0].level == 2, "root grows only once despite neighbor cycles")
	chain.config.neighbor_chance = 0.0
	check(chain.upgrade_chain(chain.buildings[0].id).events.size() == 1, "zero cascade chance respected")
	check(not chain.adjacent({"x":0,"y":0,"size":2},{"x":2,"y":2,"size":2}), "corner contact is not adjacency")
	var highway = Model.new()
	highway.add_road(PackedVector2Array([Vector2(0, 20),Vector2(39, 20)]), "highway")
	check(not highway.add_building(10,17).ok, "highway does not grant zoning access")
	var dist = Model.new()
	var histogram := {8:0,4:0,2:0}
	for i in range(20000): histogram[dist.pick_size()] += 1
	check(abs(histogram[8] / 20000.0 - 0.45) < 0.02 and histogram[8] > histogram[4] and histogram[4] > histogram[2], "seeded weighted distribution prefers 8x8")
	var repeat = Model.new()
	var repeat2 = Model.new()
	var same := true
	for i in range(200):
		if repeat.pick_size() != repeat2.pick_size(): same = false
	check(same, "seeded replay deterministic")
	for b in city.buildings:
		check(city.placement_error(b.x,b.y,b.size,b.id) == "", "post-growth spatial invariants")
	var small = Model.new(3, 6)
	small.add_road(PackedVector2Array([Vector2(0,5),Vector2(3,5)]))
	small.add_building(0,2,"residential",100)
	small.config.size_weights = {8:1.0,4:0.0,2:0.0}
	check(small.upgrade_chain(1).ok and small.buildings[0].size == 2, "blocked large footprint falls back to 2x2 without demolition")
	var medium = Model.new(6,6)
	medium.add_road(PackedVector2Array([Vector2(0,5),Vector2(6,5)]))
	medium.add_building(1,2,"commercial",100)
	medium.config.size_weights = {8:1.0,4:0.0,2:0.0}
	check(medium.upgrade_chain(1).ok and medium.buildings[0].size == 4, "8x8 falls back to valid 4x4 before 2x2")
	var preview_count: int = city.roads.size()
	city.add_road(PackedVector2Array([Vector2(1,1),Vector2(5,1)]), "local", false)
	check(city.roads.size() == preview_count, "road preview does not mutate city")
	var stress = Model.new(80,80,321)
	for y in [10, 30, 50, 70]:
		stress.add_road(PackedVector2Array([Vector2(0,y),Vector2(79,y)]))
		for x in range(2,75,4): stress.add_building(x,y-3,"residential",100)
	for iteration in range(100):
		stress.upgrade_chain(stress.buildings[iteration % stress.buildings.size()].id)
	var invariant := true
	for b in stress.buildings:
		if stress.placement_error(b.x,b.y,b.size,b.id) != "": invariant = false
	check(invariant, "100 seeded upgrades preserve boundaries, access, road and building separation")
	print("RESULT ", count - failures, "/", count, " passed")
	quit(1 if failures else 0)
