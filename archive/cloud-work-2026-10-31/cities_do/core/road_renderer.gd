extends RefCounted
const Ramp=preload("res://core/ramp_geometry.gd")
const Geometry=preload("res://core/road_geometry.gd")
static func project_poly(points: PackedVector2Array,project: Callable) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for p in points:result.append(project.call(p))
	return result
static func fill(canvas:CanvasItem,points:PackedVector2Array,width:float,color:Color,project:Callable):
	for poly in Geometry.ribbons(points,width):canvas.draw_colored_polygon(project_poly(poly,project),color)
static func draw_roads(canvas: CanvasItem,roads: Array,project: Callable,zoom: float,junctions: Array,ports: Array = []):
	# Surface roads, transition ramps, then elevated motorway decks.
	for kind in ["local","ramp","highway"]:
		var group:Array=[]
		for road in roads:
			if road.get("kind","local")==kind:group.append(road)
		if kind=="highway":
			for road in group:fill(canvas,road.points,road.width+.65,Color(0.07,.12,.14,.55),project)
		for asphalt in [false,true]:
			for road in group:
				var width:float=Geometry.carriageway_width(road) if asphalt else road.width
				var curb:=Color("c8cbc3") if kind=="local" else Color("a8b4b6")
				if road.get("smooth_join",false):
					var polygon:=Ramp.ribbon(road,width/road.width)
					if polygon.size()>2:canvas.draw_colored_polygon(project_poly(polygon,project),Color("4c5659") if asphalt else curb)
				else:fill(canvas,road.points,width,Color("4c5659") if asphalt else curb,project)
		# Open a short mouth at the outside edge; never paint across the median.
		for port in ports:
			var parent:Dictionary=roads[port.road]
			if parent.get("kind","local")!=kind:continue
			if roads[port.ramp].get("smooth_join",false):
				canvas.draw_colored_polygon(project_poly(Ramp.mouth(roads[port.ramp],port,parent),project),Color("4c5659"))
				continue
			var inside:Vector2=port.anchor+port.normal*(Geometry.carriageway_width(parent)/2-.12)
			fill(canvas,PackedVector2Array([inside,port.position]),Geometry.carriageway_width(roads[port.ramp]),Color("4c5659"),project)
		for road in group:
			var relevant:Array=[]
			for j in junctions:
				if kind=="ramp" or absf(j.get("layer",0)-road.get("layer",1 if kind=="highway" else 0))<.001:relevant.append(j)
			for line in Geometry.clip_marks(Geometry.center_marks(road),relevant):
				canvas.draw_line(project.call(line[0]),project.call(line[1]),Color("e4bd5f"),maxf(.6,zoom),true)
			for line in Geometry.clip_marks(Geometry.lane_marks(road),relevant):
				canvas.draw_line(project.call(line[0]),project.call(line[1]),Color("e8e7dc"),maxf(.6,zoom),true)
			if kind=="highway":
				var median:=Geometry.offset_line(road.points,Geometry.lane_profile(road).median_offset)
				fill(canvas,median,.18,Color("bec6b4"),project)
			if kind in ["highway","ramp"] and Geometry.allows_solid_edge_lines(road):
				for side in [-1,1]:
					var edge:=Ramp.edge(road,side,Geometry.carriageway_width(road)/road.width*.96) if road.get("smooth_join",false) else Geometry.offset_line(road.points,side*Geometry.carriageway_width(road)/2*.96)
					var edge_segments:Array[PackedVector2Array]=[]
					for i in range(edge.size()-1):edge_segments.append(PackedVector2Array([edge[i],edge[i+1]]))
					var openings:Array=relevant.duplicate()
					if road.get("smooth_join",false):
						for port in [road.start_attachment,road.end_attachment]:
							var visible:Array[PackedVector2Array]=[]
							for segment in edge_segments:
								if ((segment[0]+segment[1])/2-port.position).dot(port.normal)>.015:visible.append(segment)
							edge_segments=visible
					for port in ports:
						if port.road==roads.find(road) and port.side==side:
							if roads[port.ramp].get("smooth_join",false):
								var ramp:Dictionary=roads[port.ramp];var from_start:bool=port.road==ramp.start_attachment.road and port.position.distance_to(ramp.start_attachment.position)<.0001
								for k in range(int(ramp.points.size()*.4)):
									var index:int=k if from_start else ramp.points.size()-1-k
									openings.append({"position":ramp.points[index],"radius":ramp.width/2+.15})
							else:openings.append(port)
					for segment in Geometry.clip_marks(edge_segments,openings):canvas.draw_line(project.call(segment[0]),project.call(segment[1]),Color("e5ebdf"),maxf(.6,zoom),true)
			for arrow in Geometry.direction_arrows(road):
				var clear:=true
				for j in relevant:
					if arrow[0].distance_to(j.position)<j.radius+.5:clear=false
				if clear:canvas.draw_colored_polygon(project_poly(arrow,project),Color("e8e7dc"))
