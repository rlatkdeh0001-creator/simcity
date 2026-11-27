extends SceneTree
## Review fix 2 (MAJOR): a train's picture follows only the structure of the route it actually runs
## on (route id from the operating plan leg), never another line's tunnel or viaduct nearby.
const City=preload("res://core/city_model.gd")
const Height=preload("res://core/road_height.gd")
const Renderer=preload("res://core/cached_world_renderer.gd")
const Fixture=preload("res://tests/transit_operations_fixture.gd")
const Operations=preload("res://core/transit_operations.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
func path(values:Array)->PackedVector2Array:
 var r:=PackedVector2Array()
 for v in values:r.append(v)
 return r
func levels(values:Array)->PackedFloat64Array:
 var r:=PackedFloat64Array()
 for v in values:r.append(float(v))
 return r
func renderer_for(c):
 var r=Renderer.new();r.view={"city":c,"transit_view":{"generation":0}}
 return r
func lift(r,pose:Dictionary)->float:
 var deck:Dictionary=r.rail_deck_at(pose)
 return Height.height_at(deck,pose.position/4) if not deck.is_empty() else 0.0
func run():
 for spec in [[-10.0,5.0],[-10.0,15.0],[10.0,19.0],[10.0,20.0],[10.0,21.0]]:crossing(spec[0],spec[1])
 checks_per_call()
 pose_routes(false)
 pose_routes(true)
 print("REVIEW_FIX_LIFT checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func crossing(level:float,degrees:float):
 var c=City.new(220,90);c.funds=100000000
 var d:=Vector2.from_angle(deg_to_rad(degrees));var centre:=Vector2(130,40)
 var g:Dictionary=c.add_transit_route(path([centre-d*60,centre+d*60]),"rail",true)
 var s:Dictionary=c.add_transit_route(path([Vector2(10,40),Vector2(82,40),Vector2(190,40)]),"rail",true,levels([0,level,level]))
 var label:="%s %d deg"%["tunnel" if level<0 else "viaduct",int(degrees)]
 check(g.ok and s.ok,label+" fixture: "+str(g.get("reason",""))+" "+str(s.get("reason","")))
 if not (g.ok and s.ok):return
 var ground:int=g.route.id;var structure:int=s.route.id
 var r=renderer_for(c)
 var off:=0;var total:=0
 for k in [-2.0,2.0]:
  for t in range(-100,101,4):
   total+=1
   if absf(lift(r,{"position":centre*4+d*float(t)+d.orthogonal()*k,"heading":d,"route_id":ground}))>.0001:off+=1
 check(off==0,label+": a ground train within 100m of the crossing stays on the ground: %d/%d lifted"%[off,total])
 var own:Array=[]
 for x in [100.0,140.0,180.0]:own.append(lift(r,{"position":Vector2(x,40.5)*4,"heading":Vector2.RIGHT,"route_id":structure}))
 check(own.all(func(h):return is_equal_approx(h,level)),label+": the structure's own train is at the structure height: "+str(own))
 if is_equal_approx(degrees,15.0) or is_equal_approx(degrees,20.0):
  # Old 0.75-cell heuristic boundary: neither side of it may decide the height any more.
  for gap in [0.74,0.76]:
   var point:=Vector2(150,40+gap)*4
   check(lift(r,{"position":point,"heading":Vector2.RIGHT,"route_id":ground})==0.0,label+": ground route pose %.2f cells beside the structure stays on the ground"%gap)
   check(is_equal_approx(lift(r,{"position":point,"heading":Vector2.RIGHT,"route_id":structure}),level),label+": own pose %.2f cells off the centreline keeps the structure height"%gap)
  check(lift(r,{"position":Vector2(150,40)*4,"heading":Vector2.RIGHT})==0.0,label+": a pose without a route id is drawn at 0m")
 r.free()
func checks_per_call():
 # Each call looks at exactly one structure (its own route), however many routes exist.
 var counts:Array=[]
 for extra in [0,6]:
  var c=City.new(220,90);c.funds=100000000
  var s:Dictionary=c.add_transit_route(path([Vector2(10,40),Vector2(82,40),Vector2(190,40)]),"rail",true,levels([0,10,10]))
  for i in range(extra):c.add_transit_route(path([Vector2(10,60+i*4),Vector2(60,60+i*4)]),"rail",true,levels([0,0]))
  var r=renderer_for(c)
  var before:Variant=r.get("rail_deck_checks")
  if before==null:
   check(false,"renderer exposes a structure-check counter");r.free();return
  for i in range(40):lift(r,{"position":Vector2(100+i,40)*4,"heading":Vector2.RIGHT,"route_id":s.route.id})
  counts.append(int(r.get("rail_deck_checks"))-int(before))
  r.free()
 check(counts.size()==2 and counts[0]==40 and counts[1]==40,"structure checks per call are constant (1) with 2 or 8 routes: "+str(counts))
func distance_to(points:PackedVector2Array,point:Vector2)->float:
 var best:=INF
 for i in range(1,points.size()):best=minf(best,Geometry2D.get_closest_point_to_segment(point,points[i-1],points[i]).distance_to(point))
 return best
func pose_routes(turnback:bool):
 var city=Fixture.rail_city()
 if turnback:city.remove_transit_route(city.transit_routes[-1].id)
 var label:="turnback line" if turnback else "loop line"
 var created:Dictionary=city.create_transit_line("rail",city.public_facilities.lots.map(func(lot):return lot.id),{"dwell_seconds":1.0,"headway_seconds":1.0})
 check(created.ok and created.line.get("turnback",false)==turnback,label+" fixture")
 var operation=Operations.new()
 var on_route:=true;var seen:Dictionary={};var mixed:=false;var samples:=0;var worst:=0.0
 for i in range(300):
  operation.advance(city,1.0)
  var consist:Dictionary={}
  for pose:Dictionary in city.transit_state.get("visible",[]):
   if pose.get("cargo",false):continue
   samples+=1
   var id:int=int(pose.get("route_id",-1))
   var route:Dictionary=city.get_transit_route(id)
   var gap:float=INF if route.is_empty() else distance_to(route.points,pose.position/4)
   worst=maxf(worst,gap)
   if gap>.6:on_route=false
   seen[id]=true;consist[id]=true
  if consist.size()>1:mixed=true
 check(samples>0 and on_route,label+": every car carries the route it actually runs on (worst %.3f cells)"%worst)
 check(seen.size()>=2 and mixed,label+": one consist spans several routes and each car follows its own: %s"%str(seen.keys()))
