extends SceneTree
const Model=preload("res://core/city_model.gd")
const Geometry=preload("res://core/road_geometry.gd")
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(value:bool,text:String):
	checks+=1
	if value:print("PASS ",text)
	else:failures+=1;push_error(text)
func line(a:Vector2,b:Vector2)->PackedVector2Array:return PackedVector2Array([a,b])
func network_reachable(city)->bool:
	var visited:={0:true};var pending:Array=[0]
	while not pending.is_empty():
		var node:int=pending.pop_back()
		for ei in city.road_network.nodes[node].edges:
			var edge:Dictionary=city.road_network.edges[ei]
			var other:int=edge.to if edge.from==node else edge.from
			if not visited.has(other):visited[other]=true;pending.append(other)
	return visited.size()==city.road_network.nodes.size()
func run():
	var ordinary=Model.new(100,100)
	check(ordinary.add_road(line(Vector2(5,50),Vector2(95,50)),"local",true,8).ok,"8-lane ordinary road accepted")
	var road:Dictionary=ordinary.roads[0]
	var profile:=Geometry.lane_profile(road)
	check(road.width==8 and profile.forward==4 and profile.backward==4,"8 lanes occupy 8 cells and split 4+4")
	check(road.speed_limit_kmh==80 and ordinary.road_network.edges[0].speed_limit_kmh==80,"ordinary road and edge carry 80 km/h")
	check(not Geometry.lane_marks(road).is_empty() and Geometry.direction_arrows(road).size()==8,"8-lane visual markings and directions")
	for lanes in [2,3,4,5]:
		var city=Model.new(100,100)
		check(city.add_road(line(Vector2(5,50),Vector2(95,50)),"highway",true,lanes).ok,"highway %d lanes accepted"%lanes)
		check(city.roads[0].speed_limit_kmh==160 and city.roads[0].layer==1 and city.roads[0].width==lanes,"highway %d speed, layer and width"%lanes)
		check(city.zoning_grid.count()==0 and not city.add_building(20,43).ok,"highway %d grants no zoning or building access"%lanes)
		check(is_equal_approx(city.road_network.edges[0].free_flow_seconds*2,ordinary.road_network.edges[0].free_flow_seconds),"160 km/h halves free-flow time versus 80")
	check(not ordinary.add_road(line(Vector2(5,20),Vector2(95,20)),"highway",true,8).ok,"unsupported 8-lane highway rejected")
	var city=Model.new(100,100)
	city.add_road(line(Vector2(50,5),Vector2(50,95)),"local",true,4)
	city.add_road(line(Vector2(5,50),Vector2(95,50)),"highway",true,4)
	check(city.road_network.junctions.is_empty() and city.road_network.edges.size()==2 and not network_reachable(city),"grade-separated crossing remains disconnected")
	var count:int=city.zoning_grid.count()
	var preview:Dictionary=city.add_interchange_at(Vector2(50,50),false)
	check(preview.ok and preview.ramps.size()==4 and city.roads.size()==2 and city.interchanges.is_empty() and city.zoning_grid.count()==count,"interchange preview does not mutate city")
	check(city.add_interchange_at(Vector2(50,50)).ok and city.roads.size()==6 and city.interchanges.size()==1,"interchange commits four ramps atomically")
	check(network_reachable(city),"ramps connect motorway and ordinary-road networks")
	var entry:=0;var exit:=0;var directed:=true
	for ramp in city.roads:
		if ramp.kind!="ramp":continue
		if ramp.role=="entry":entry+=1
		else:exit+=1
		var rp:=Geometry.lane_profile(ramp)
		directed=directed and rp.forward==1 and rp.backward==0 and ramp.start_layer!=ramp.end_layer
	check(entry==2 and exit==2 and directed,"two one-way entries and two exits connect different layers")
	var centre_node:=false
	for node in city.road_network.nodes:
		if node.position.distance_to(Vector2(50,50))<.01:centre_node=true
	check(not centre_node,"overpass centre never becomes a false junction")
	check(not city.add_interchange_at(Vector2(50,50)).ok and city.roads.size()==6,"duplicate interchange rejected without mutation")
	check(not city.add_interchange_at(Vector2(5,5)).ok,"click far from crossing rejected")
	var small=Model.new(100,100)
	small.add_road(line(Vector2(50,45),Vector2(50,60)),"local",true,4)
	small.add_road(line(Vector2(5,50),Vector2(95,50)),"highway",true,4)
	check(not small.add_interchange_at(Vector2(50,50)).ok and small.roads.size()==2,"insufficient ramp space rejects atomically")
	var blocked=Model.new(100,100)
	blocked.add_road(line(Vector2(50,5),Vector2(50,95)),"local",true,4)
	blocked.add_road(line(Vector2(5,50),Vector2(95,50)),"highway",true,4)
	blocked.buildings.append({"id":99,"x":42,"y":42,"size":4,"zone":"residential","level":1})
	check(not blocked.add_interchange_at(Vector2(50,50)).ok and blocked.roads.size()==2,"building collision rejects entire interchange")
	var sampled=Model.new(100,100)
	var hp:=PackedVector2Array();var lp:=PackedVector2Array()
	for i in range(5,96,2):hp.append(Vector2(i,50));lp.append(Vector2(50,i))
	sampled.add_road(lp,"local",true,4);sampled.add_road(hp,"highway",true,4)
	check(sampled.add_interchange_at(Vector2(50,50)).ok and network_reachable(sampled),"densely sampled freehand roads support connected interchange")
	var reversed=Model.new(100,100)
	reversed.add_road(line(Vector2(50,95),Vector2(50,5)),"local",true,4)
	reversed.add_road(line(Vector2(5,50),Vector2(95,50)),"highway",true,4)
	var reversed_result:Dictionary=reversed.add_interchange_at(Vector2(50,50))
	var exits_correct:bool=reversed_result.ok
	if exits_correct:
		for ramp in reversed_result.ramps:
			if ramp.role=="exit":exits_correct=exits_correct and (ramp.points[0].x-50)*(ramp.points[-1].y-50)<0
	check(exits_correct,"reversing local drawing direction preserves right-side exit orientation")
	check(city.road_network.ports.size()==8 and city.road_network.junctions.is_empty(),"eight side ports create no false centreline intersections")
	var side_ports:=true;var directional_ports:=true
	for port in city.road_network.ports:
		var parent:Dictionary=city.roads[port.road]
		side_ports=side_ports and port.position.distance_to(port.anchor)>Geometry.carriageway_width(parent)/2
	for edge in city.road_network.edges:
		if edge.kind=="ramp_port":directional_ports=directional_ports and edge.forward_lanes==1 and edge.backward_lanes==0 and edge.carriageway in ["forward","backward"]
	check(side_ports and directional_ports,"visible ramp ends attach outside carriageway with directed logical side connections")
	check(Geometry.clip_marks(Geometry.center_marks(city.roads[1]),city.road_network.junctions).size()==1,"motorway median stays continuous through ramp joins")
	for lanes in [2,3,5]:
		var side_city=Model.new(100,100)
		side_city.add_road(line(Vector2(50,5),Vector2(50,95)),"local",true,3)
		side_city.add_road(line(Vector2(5,50),Vector2(95,50)),"highway",true,lanes,true)
		var joined:Dictionary=side_city.add_interchange_at(Vector2(50,50))
		var outside:bool=joined.ok and network_reachable(side_city)
		if joined.ok:
			for port in side_city.road_network.ports:
				outside=outside and port.position.distance_to(port.anchor)>Geometry.carriageway_width(side_city.roads[port.road])/2
		check(outside,"%d-lane motorway with reversed allocation preserves side joins and connectivity"%lanes)
	var scene=load("res://main.tscn").instantiate();root.add_child(scene);await process_frame
	var choice=scene.find_child("RoadKind",true,false)
	var lanes_choice=scene.find_child("RoadLanes",true,false)
	lanes_choice.select(4);lanes_choice.item_selected.emit(4)
	check(scene.road_lanes==8,"UI selects ordinary 8 lanes")
	choice.select(1);choice.item_selected.emit(1)
	check(scene.road_kind=="highway" and scene.road_lanes==4 and lanes_choice.is_item_disabled(4),"highway UI removes unsupported 8 lanes safely")
	scene.stroke=line(Vector2(5,50),Vector2(95,50));scene.drawing=true;scene.finish_road()
	check(scene.city.roads[0].kind=="highway" and scene.city.roads[0].speed_limit_kmh==160,"UI commits selected highway with correct speed")
	scene.city.add_road(line(Vector2(50,5),Vector2(50,95)),"local",true,4)
	scene.mode="interchange"
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=scene.screen(Vector2(50,50))
	scene._unhandled_input(click)
	check(scene.city.interchanges.size()==1 and scene.city.roads.size()==6,"map click installs interchange through construction tool")
	scene.queue_free();await process_frame
	print("RESULT ",checks-failures,"/",checks," highway checks passed")
	quit(1 if failures else 0)
