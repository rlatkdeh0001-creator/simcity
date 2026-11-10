extends SceneTree
const Model=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
var failures:=0
var checks:=0
func check(value: bool,label: String):
	checks+=1
	if value:print("PASS ",label)
	else:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func line(a: Vector2,b: Vector2) -> PackedVector2Array:return PackedVector2Array([a,b])
func run():
	var city=Model.new(100,100)
	city.add_road(line(Vector2(10,30),Vector2(60,30)),"local",true,2)
	var before:int=city.road_network.edges.size()
	check(city.add_road(line(Vector2(35,10),Vector2(35,60)),"local",false,5).ok and city.roads.size()==1 and city.road_network.edges.size()==before,"preview leaves roads, junctions and graph unchanged")
	city.add_road(line(Vector2(35,10),Vector2(35,60)),"local",true,5)
	check(city.road_network.junctions.size()==1 and city.road_network.junctions[0].degree==4 and city.road_network.junctions[0].kind=="cross","2x5 crossing creates a four-arm intersection")
	check(city.road_network.edges.size()==4 and city.road_network.nodes.size()==5,"crossing splits both roads into connected graph edges")
	check(city.road_network.junctions[0].position.distance_to(Vector2(35,30))<.0001,"intersection keeps exact continuous crossing point")
	var tee=Model.new(100,100)
	tee.add_road(line(Vector2(10,30),Vector2(60,30)))
	var preview:Dictionary=tee.add_road(line(Vector2(35,10),Vector2(35,28.6)),"local",false,3)
	check(preview.road.points[-1].distance_to(Vector2(35,30))<.0001,"preview snaps touching road cap to existing centreline")
	tee.add_road(line(Vector2(35,10),Vector2(35,28.6)),"local",true,3)
	check(tee.road_network.junctions.size()==1 and tee.road_network.junctions[0].kind=="T" and tee.road_network.edges.size()==3,"snapped endpoint creates a T intersection")
	var joined=Model.new(100,100)
	joined.add_road(line(Vector2(10,10),Vector2(30,10)))
	joined.add_road(line(Vector2(30,10),Vector2(50,10)),"local",true,3)
	check(joined.road_network.junctions.is_empty() and joined.road_network.nodes.size()==3,"two meeting ends form a join, not a false T")
	var separate=Model.new(100,100)
	separate.add_road(line(Vector2(10,10),Vector2(50,10)))
	separate.add_road(line(Vector2(10,14),Vector2(50,14)))
	check(separate.road_network.junctions.is_empty() and separate.road_network.nodes.size()==4,"separated parallel roads stay disconnected")
	var overlap=Model.new(100,100)
	overlap.add_road(line(Vector2(10,10),Vector2(50,10)))
	overlap.add_road(line(Vector2(20,10),Vector2(60,10)),"local",true,4)
	check(overlap.road_network.edges.size()==3 and overlap.road_network.junctions.is_empty(),"collinear overlaps split and deduplicate graph edges")
	var diagonal=Model.new(100,100)
	diagonal.add_road(line(Vector2(10.25,10.25),Vector2(50.25,50.25)))
	diagonal.add_road(line(Vector2(10.25,50.25),Vector2(50.25,10.25)),"local",true,3)
	check(diagonal.road_network.junctions.size()==1 and diagonal.road_network.junctions[0].position.distance_to(Vector2(30.25,30.25))<.0001,"diagonal fractional roads intersect without grid snapping")
	for lanes in [2,3,4,5]:
		var c=Model.new(100,100);c.add_road(line(Vector2(10,20),Vector2(60,20)),"local",true,lanes)
		var r:Dictionary=c.roads[0];var profile:=Geometry.lane_profile(r)
		check(r.width==lanes and profile.forward+profile.backward==lanes,"%d total lanes preserve width and direction allocation"%lanes)
		if lanes in [3,5]:
			check(not Geometry.lane_marks(r).is_empty() and Geometry.direction_arrows(r).size()==lanes,"%d lane separators and direction arrows"%lanes)
			r.reverse_lanes=true
			var reversed:=Geometry.lane_profile(r)
			check(reversed.forward==profile.backward and reversed.backward==profile.forward and is_equal_approx(reversed.median_offset,-profile.median_offset),"%d lane reversal swaps sides and median"%lanes)
	var clipped:=Geometry.clip_marks(Geometry.center_marks(city.roads[0]),city.road_network.junctions)
	var clear:=not clipped.is_empty()
	for l in clipped:
		if ((l[0]+l[1])/2).distance_to(Vector2(35,30))<city.road_network.junctions[0].radius:clear=false
	check(clear and clipped.size()==2,"centre line stops on both sides of an intersection")
	var snapshot:int=tee.roads.size()
	check(not tee.add_road(line(Vector2(35,30),Vector2(35.01,30)),"local",true,3).ok and tee.roads.size()==snapshot,"collapsed snap rejects atomically")
	var arrows_right:=true
	for lanes in [2,3,4,5,8]:
		for reversed in [false,true]:
			var road:Dictionary={"kind":"highway" if lanes!=8 else "local","lanes":lanes,"width":float(lanes),"reverse_lanes":reversed,"points":line(Vector2(10,20),Vector2(60,20))}
			var median:float=Geometry.lane_profile(road).median_offset
			for arrow in Geometry.direction_arrows(road):
				var center:Vector2=(arrow[1]+arrow[3])/2
				var direction:Vector2=arrow[0]-center
				arrows_right=arrows_right and direction.x*(center.y-20-median)>0
	check(arrows_right,"road arrows stay on the right-hand side for every lane count and reversal")
	check(not Geometry.allows_solid_edge_lines({"kind":"ramp"}) and Geometry.allows_solid_edge_lines({"kind":"highway"}),"ramp solid edge lines are forbidden without removing motorway markings")
	print("RESULT ",checks-failures,"/",checks," junction and lane checks passed")
	quit(1 if failures else 0)
