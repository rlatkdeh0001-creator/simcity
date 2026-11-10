extends Node3D
## Comparison adapter. Source game geometry stays in cells; upstream uses meters.
const Ramp=preload("res://core/ramp_geometry.gd")
const Geometry=preload("res://core/road_geometry.gd")
var containers:Array=[]
var merge_points:Array=[]
var surface_finisher
var source_city
func point3(p:Vector2,height:float)->Vector3:return Vector3((p.x-50)*4,height,(p.y-50)*4)
func direction_for(port:Dictionary,roads:Array)->Vector3:
	var road:Dictionary=roads[port.road]
	var best:=INF;var tangent:=Vector2.RIGHT
	for i in range(road.points.size()-1):
		var q:=Geometry2D.get_closest_point_to_segment(port.anchor,road.points[i],road.points[i+1])
		if q.distance_to(port.anchor)<best:best=q.distance_to(port.anchor);tangent=(road.points[i+1]-road.points[i]).normalized()
	if port.carriageway=="backward":tangent=-tangent
	return Vector3(tangent.x,0,tangent.y)
func merge_point(port:Dictionary,roads:Array,at_start:bool)->Dictionary:
	var parent:Dictionary=roads[port.road]
	var lane_width:float=Geometry.lane_profile(parent).lane_width*4
	var position:Vector3=point3(port.anchor,port.layer*8)+Vector3(port.normal.x,0,port.normal.y)*(Geometry.carriageway_width(parent)*2-lane_width/2)
	var heading:=direction_for(port,roads)
	position+=heading*(-20 if at_start else 20)
	return {"position":position,"heading":heading,"lane_width":lane_width,"port":port,"start":at_start}
func build(city):
	source_city=city
	var manager:=RoadManager.new();manager.name="UpstreamRoadGenerator";manager.auto_refresh=false;manager.density=1.0
	manager.underside_thickness=.45
	var underside:=StandardMaterial3D.new();underside.albedo_color=Color("7c8582");manager.material_underside=underside
	add_child(manager)
	for ri in range(city.roads.size()):
		var road:Dictionary=city.roads[ri]
		var samples:Array=[]
		var is_ramp:bool=road.kind=="ramp"
		if is_ramp and road.get("smooth_join",false):
			for at_start in [true,false]:
				var port:Dictionary=road.start_attachment if at_start else road.end_attachment
				var position:Vector3=point3(port.position,port.layer*8)
				merge_points.append({"position":position,"heading":Vector3(port.heading.x,0,port.heading.y),"lane_width":3.52,"port":port,"start":at_start})
			for i in range(0,road.points.size(),3):
				var t:float=float(i)/(road.points.size()-1)
				var d:=Ramp.derivative(road,t)*4
				var grade:float=(road.end_layer-road.start_layer)*8*Ramp.smooth_derivative(t)
				var derivative:=Vector3(d.x,grade,d.y)
				var factor:float=road.width_factors[i]
				samples.append({"position":point3(road.points[i],Ramp.height(road,t)*8),"heading":derivative.normalized(),"derivative":derivative.length(),"t":t,"width_factor":factor,"lane_width":maxf(.0001,3.52*factor)})
		else:
			if is_ramp:
				var start:=merge_point(road.start_attachment,city.roads,true);samples.append(start);merge_points.append(start)
			for i in range(road.points.size()):
				if is_ramp and i not in [0,3,6,9,road.points.size()-1]:continue
				var layer:float=road.get("layer",0)
				if is_ramp:layer=lerpf(road.start_layer,road.end_layer,float(i)/(road.points.size()-1))
				samples.append({"position":point3(road.points[i],layer*8)})
			if is_ramp:
				var end:=merge_point(road.end_attachment,city.roads,false);samples.append(end);merge_points.append(end)
		var container:=RoadContainer.new();container.name="Road_%d_%s"%[ri,road.kind];container._auto_refresh=false
		container.generate_ai_lanes=true;container.create_edge_curves=true;container.flatten_terrain=false
		var profile:=Geometry.lane_profile(road)
		var points:Array=[]
		for i in range(samples.size()):
			var sample:Dictionary=samples[i]
			var point:=RoadPoint.new();point.name="Point_%d"%i
			point.position=sample.position+Vector3.UP*(.03 if is_ramp and not road.get("smooth_join",false) else 0.0)
			var heading:Vector3=sample.get("heading",(samples[mini(i+1,samples.size()-1)].position-samples[maxi(i-1,0)].position).normalized())
			# RoadPoint +Z is its longitudinal axis.
			point.basis=Basis.looking_at(-heading,Vector3.UP)
			var dirs:Array[RoadPoint.LaneDir]=[]
			# Upstream 0.9.5 reverses FORWARD lane curves internally. Map by actual travel.
			for lane in range(int(road.lanes)):dirs.append(RoadPoint.LaneDir.REVERSE if lane<profile.forward else RoadPoint.LaneDir.FORWARD)
			point.traffic_dir=dirs;point.assign_lanes()
			point.lane_width=sample.get("lane_width",3.52 if is_ramp else profile.lane_width*4)
			var shoulder:float=(road.width*4-point.lane_width*road.lanes)/2
			if sample.has("width_factor"):shoulder=1.24*sample.width_factor
			elif sample.has("port"):shoulder=0
			point.shoulder_width_l=maxf(0,shoulder);point.shoulder_width_r=maxf(0,shoulder)
			point.gutter_profile=Vector2.ZERO
			point.flatten_terrain=false
			var length_before:float=sample.position.distance_to(samples[maxi(0,i-1)].position)
			var length_after:float=sample.position.distance_to(samples[mini(samples.size()-1,i+1)].position)
			point.prior_mag=maxf(.1,length_before/3);point.next_mag=maxf(.1,length_after/3)
			if sample.has("derivative"):
				point.prior_mag=maxf(.001,sample.derivative*(sample.t-samples[maxi(0,i-1)].t)/3)
				point.next_mag=maxf(.001,sample.derivative*(samples[mini(samples.size()-1,i+1)].t-sample.t)/3)
			if i>0:point.prior_pt_init=NodePath("../Point_%d"%(i-1))
			if i<samples.size()-1:point.next_pt_init=NodePath("../Point_%d"%(i+1))
			container.add_child(point);points.append(point)
		manager.add_child(container);containers.append(container)
		container.rebuild_segments()
	# Preserve a visible median on the motorway, raised above the generated mesh.
	for road in city.roads:
		if road.kind!="highway":continue
		var median:=Geometry.offset_line(road.points,Geometry.lane_profile(road).median_offset)
		for i in range(median.size()-1):
			var a:=point3(median[i],8.4);var b:=point3(median[i+1],8.4)
			box_between(a,b,.25,.8,Color("bec6b4"))
	for x in [-12,12]:
		for z in [-4.5,4.5]:box_between(Vector3(x,3.75,z-1),Vector3(x,3.75,z+1),1.5,7.5,Color("a3aaa0"))
	surface_finisher=preload("res://core/road_surface_finisher.gd").new()
	surface_finisher.apply(self)
func box_between(a:Vector3,b:Vector3,width:float,height:float,color:Color):
	var instance:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(width,height,a.distance_to(b));instance.mesh=box
	instance.position=(a+b)/2;instance.basis=Basis.looking_at(a-b,Vector3.UP)
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;instance.material_override=mat;add_child(instance)
func stats()->Dictionary:
	var result:Dictionary={"containers":containers.size(),"segments":0,"meshes":0,"lanes":0,"vertices":0,"merge_points":merge_points.size()}
	for container in containers:
		for segment in container.get_segments():
			result.segments+=1
			if is_instance_valid(segment.road_mesh) and segment.road_mesh.mesh!=null:
				result.meshes+=1
				for surface in range(segment.road_mesh.mesh.get_surface_count()):result.vertices+=segment.road_mesh.mesh.surface_get_array_len(surface)
			for child in segment.start_point.get_children():
				if child is RoadLane:result.lanes+=1
	if surface_finisher!=null:result.surface_finish=surface_finisher.report
	return result
