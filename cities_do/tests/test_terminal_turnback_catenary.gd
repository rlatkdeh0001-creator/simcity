extends SceneTree
## P5 review BLOCK 2: real station ports facing at exactly 32m. The fixed 32m X
## host keeps both X contact wires; both supports move 1m inside (30m span).

const View = preload("res://core/transit_view.gd")
const Catenary = preload("res://core/rail_catenary.gd")
var checks := 0
var failures := 0

func _initialize():
 run.call_deferred()

func check(ok: bool, label: String):
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL "+label)

func finish():
 print("TERMINAL_TURNBACK_CATENARY checks=%d failed=%d" % [checks, failures])
 quit(1 if failures else 0)

static func lot_distance(point: Vector2, polygon: PackedVector2Array) -> float:
 if Geometry2D.is_point_in_polygon(point, polygon):return 0.0
 var best := INF
 for i in range(polygon.size()):
  best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, polygon[i], polygon[(i+1)%polygon.size()])))
 return best

func run():
 var city = load("res://core/city_model.gd").new(120,120,42)
 city.population_enabled=false;city.happiness_enabled=false
 city.add_road(PackedVector2Array([Vector2(2,40),Vector2(110,40)]),"local",true,4)
 for x: float in [30.0, 46.0]:
  check(city.public_facilities.place("train-station-01",Vector2(x,33.0),0,true).ok,"real station placed at x=%s" % x)
 if city.public_facilities.lots.size()!=2:
  finish();return
 var lots: Array = city.public_facilities.lots.duplicate()
 lots.sort_custom(func(a,b):return a.position.x<b.position.x)
 var a: PackedVector2Array = lots[0].internal_points.duplicate()
 var b: PackedVector2Array = lots[1].internal_points.duplicate()
 if a[0].x>a[-1].x:a.reverse()
 if b[0].x>b[-1].x:b.reverse()
 check(absf(a[-1].distance_to(b[0])*4.0-32.0)<0.0005,"facing station ports exactly 32m apart")
 check(city.add_transit_route(PackedVector2Array([a[-1],b[0]]),"rail").ok,"exact 32m straight double track joins the facing ports")
 var line: Dictionary = city.create_transit_line("rail",[lots[0].id,lots[1].id])
 check(line.ok and line.line.get("turnback",false),"exact 32m host accepted for terminal turnback")
 if not line.ok:
  finish();return
 var switches: Dictionary = city.terminal_crossovers()
 check(switches.size()==2,"both terminal X crossovers owned on the shared 32m host")
 var geometry: Dictionary = View.build_geometry(city)
 check(geometry.crossovers.size()==2,"both X crossovers drawn")
 for x: Dictionary in switches.values():
  test_crossover(city, geometry.catenary, x, lots)
 finish()

func test_crossover(city, ground: Array, x: Dictionary, lots: Array):
 var axis: Vector2 = x.axis
 var side := Vector2(-axis.y, axis.x)
 var supports: PackedVector2Array = Catenary.crossover_supports(x, city)
 var near_m: float = (supports[0]*4.0-x.start).dot(axis)
 var far_m: float = (supports[1]*4.0-x.start).dot(axis)
 check(Catenary.far_end_at_station(x, city),"far X end meets the other station's 1m setback "+x.key)
 check(absf(near_m-1.0)<0.0005 and absf(far_m-31.0)<0.0005,"both supports 1m inside the 32m host "+x.key)
 check(absf(far_m-near_m-30.0)<0.0005,"X span is 30m "+x.key)
 var poles := true
 var setback := true
 for support: Vector2 in supports:
  for sign_value: float in [-1.0, 1.0]:
   var base: Vector2 = support+side*sign_value
   if not ground.any(func(c):return c.kind=="pole" and c.a.distance_to(base)<0.0005):poles=false
   for lot: Dictionary in lots:
    if lot_distance(base, lot.polygon)*4.0<1.0-0.0005:setback=false
 check(poles,"pole pairs stand at both X supports "+x.key)
 check(setback,"every X support pole is at least 1m from both station lots "+x.key)
 var wires: Dictionary = {}
 for c: Dictionary in ground:
  if c.kind!="contact" or c.get("crossover_key","")!=x.key:continue
  var key := signf((c.b-c.a).cross(axis))
  if not wires.has(key):wires[key]=[]
  wires[key].append(c)
 check(wires.size()==2,"two X contact wires "+x.key)
 var attached := wires.size()==2
 var deviation := 0.0
 for key: float in wires:
  var pieces: Array = wires[key]
  pieces.sort_custom(func(p,q):return p.a.dot(axis)<q.a.dot(axis))
  var start: Vector2 = pieces[0].a
  var end: Vector2 = pieces[-1].b
  var start_side: float = (start-supports[0]).dot(side)
  var end_side: float = (end-supports[1]).dot(side)
  # Straight chord from one support track (+/-2m) to the opposite one.
  attached = attached and absf((start-supports[0]).dot(axis))<0.0005 and absf((end-supports[1]).dot(axis))<0.0005
  attached = attached and absf(absf(start_side)-0.5)<0.0005 and absf(start_side+end_side)<0.0005
  for c: Dictionary in pieces:
   for p: Vector2 in [c.a, c.b]:
    attached = attached and Geometry2D.get_closest_point_to_segment(p,start,end).distance_to(p)<0.0005
   attached = attached and c.a_height==3.8 and c.b_height==3.8
  for endpoint: Vector2 in [start, end]:
   attached = attached and ground.any(func(c):return c.kind=="pull" and c.a.distance_to(endpoint)<0.0005)
  for path: PackedVector2Array in x.paths:
   if signf((path[0]-x.start).dot(side))!=signf(start_side):continue
   for point: Vector2 in path:
    if (point-start*4.0).dot(axis)<0.0 or (point-end*4.0).dot(axis)>0.0:continue
    deviation = maxf(deviation, Geometry2D.get_closest_point_to_segment(point/4.0,start,end).distance_to(point/4.0)*4.0)
 check(attached,"X wires are straight chords between support hangers "+x.key)
 check(deviation>0.0 and deviation<=0.62,"X wire within the 0.62m contact half-width of its S path "+x.key)
 print("P5 facing-32m X %s span=%.3fm max_wire_to_S=%.3fm" % [x.key, far_m-near_m, deviation])
