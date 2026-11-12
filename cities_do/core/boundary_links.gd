extends RefCounted
## Display-only connection marks. Eligibility reuses real regional terminals/utility adjacency.
const Regional=preload("res://core/regional_exchange.gd")
const Paths=preload("res://core/road_junctions.gd")
const INWARD:={"x_min":Vector2.RIGHT,"x_max":Vector2.LEFT,"y_min":Vector2.DOWN,"y_max":Vector2.UP}
const PAINT:=Color(1,1,1,.76)
static func road_links(city) -> Array:
 var result:=[]
 var seen:={}
 for road in city.roads:
  if Regional.path_error(road.points,city.width,city.height)!="":continue
  for end in [0,1]:
   var path: PackedVector2Array=road.points.duplicate()
   if end==1:path.reverse()
   var cursor:=1
   while cursor<path.size() and path[cursor].distance_to(path[0])<=Regional.EDGE_EPSILON:cursor+=1
   if cursor==path.size():continue
   var edge:=Regional.endpoint_edge(path[0],path[cursor],city.width,city.height)
   if edge.is_empty() or seen.has(Paths.key(path[0])):continue
   seen[Paths.key(path[0])]=true
   var length:=Paths.length_of(path)
   var inset:=minf(2.2,length*.5)
   var direction: Vector2=(Paths.sample(path,maxf(0,inset-.1))-Paths.sample(path,minf(length,inset+.1))).normalized()
   result.append({"position":Paths.sample(path,inset),"direction":direction,"edge":edge,"terminal":path[0],"width":minf(float(road.width),length*.8),"span":minf(minf(float(road.width)*.65,1.8),length*.6)})
 return result
static func utility_links(grid,tab_open: bool) -> Array:
 var result:=[]
 if not tab_open:return result
 grid.rebuild()
 for port in grid.ports:
  var node: int=grid._find_node(port.position)
  if grid.adjacency.get(node,[]).is_empty():continue
  var inward: Vector2=INWARD[port.edge]
  result.append({"position":port.position/4.0+inward*2.2,"direction":-inward,"edge":port.edge,"terminal":port.position/4.0,"width":1.5,"span":1.3})
 return result
static func arrow_shapes(link: Dictionary) -> Array:
 var result:=[]
 var axis: Vector2=link.direction
 var side:=Vector2(-axis.y,axis.x)
 for sign_value in [1,-1]:
  var direction: Vector2=axis*sign_value
  var normal:=Vector2(-direction.y,direction.x)
  var center: Vector2=link.position+side*float(link.width)*.15*sign_value
  var half: float=link.span/2
  var neck: float=half-float(link.span)*.32
  var head: float=link.width*.075
  var shaft: float=head*.42
  result.append(PackedVector2Array([center-direction*half-normal*shaft,center+direction*neck-normal*shaft,center+direction*neck-normal*head,center+direction*half,center+direction*neck+normal*head,center+direction*neck+normal*shaft,center-direction*half+normal*shaft]))
 return result
static func draw_links(canvas: CanvasItem,view,links: Array):
 var bounds:=PackedVector2Array([Vector2.ZERO,Vector2(view.city.width,0),Vector2(view.city.width,view.city.height),Vector2(0,view.city.height)])
 for link in links:
  for shape in arrow_shapes(link):
   for clipped in Geometry2D.intersect_polygons(shape,bounds):
    var projected:=PackedVector2Array()
    for p in clipped:projected.append(view.screen(p))
    if projected.size()>=3:canvas.draw_colored_polygon(projected,PAINT)
