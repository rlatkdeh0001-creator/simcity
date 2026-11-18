extends SceneTree
## Untimed, bounded geometry contract. No traffic benchmark or native worker.
const View=preload("res://core/transit_view.gd")
const Routes=preload("res://core/transit_routes.gd")
class City extends RefCounted:
 var width:=120
 var height:=120
 var transit_routes:Array=[]
 var road_pavement:Array=[]
 var junction_pavement:Array=[]
 var public_facilities={"lots":[]}
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS "+label)
 else:failures+=1;printerr("FAIL "+label)
func route(points:PackedVector2Array,id:int=1,kind:String="rail")->Dictionary:
 var r:=Routes.profile(kind);r.points=points;r.id=id;return r
func _initialize():run.call_deferred()
func run():
 var city:=City.new()
 city.transit_routes=[route(PackedVector2Array([Vector2(0,20),Vector2(25,20)]))]
 var before:=var_to_bytes(city.transit_routes)
 var geometry:=View.build_geometry(city)
 check(geometry.has("catenary"),"build_geometry emits catenary into actual retained geometry contract")
 if geometry.has("catenary"):
  var poles:Array=geometry.catenary.filter(func(p):return p.kind=="pole")
  var contacts:Array=geometry.catenary.filter(func(p):return p.kind=="contact")
  check(poles.size()==8,"100m boundary-to-blocked-end line: 96m electrified in three equal spans, paired poles")
  check(not contacts.is_empty(),"contact lines exist")
  var valid:=true
  for p in poles:
   valid=valid and is_equal_approx(p.b_height,5.3) and p.color==Color("6f7579") and is_equal_approx(absf(p.a.y-20)*4,4)
  check(valid,"pole height 5.3m, lateral 4m, exact galvanized colour")
  valid=true
  for p in contacts:valid=valid and p.a_height==3.8 and p.b_height==3.8 and p.color==Color("2a2e30")
  check(valid,"contact height 3.8m and exact wire colour")
  check(var_to_bytes(city.transit_routes)==before,"display geometry never mutates routes")
  geometry_cases(city)
 print("CATENARY_GEOMETRY checks=%d failed=%d"%[checks,failures]);quit(1 if failures else 0)
func geometry_cases(city):
 var C=load("res://core/rail_catenary.gd")
 check(C.has_method("spacing_m"),"curvature spacing policy exists")
 if C.has_method("spacing_m"):
  for pair in [[34,8],[71,8],[72,12],[127,12],[128,16],[199,16],[200,20],[287,20],[288,24],[391,24],[392,28],[511,28],[512,32],[INF,32]]:
   check(C.spacing_m(pair[0])==pair[1],"radius %s uses %sm pitch"%pair)
 var r:=route(PackedVector2Array([Vector2(10,20),Vector2(30,20),Vector2(50,20)]))
 for flag in ["covered","underground"]:
  var hidden:=r.duplicate(true);hidden[flag]=true;city.transit_routes=[hidden]
  check(View.build_geometry(city).catenary.is_empty(),flag+" route has no overhead geometry")
 city.transit_routes=[route(r.points,1,"metro")]
 check(View.build_geometry(city).catenary.is_empty(),"metro has no catenary")
 var below:=r.duplicate(true);below.rail_top_z_m=-12.7;city.transit_routes=[below]
 check(View.build_geometry(city).catenary.is_empty(),"negative rail datum has no ground-stage catenary")
 for flag in ["covered_segments","underground_segments"]:
  var mixed:=r.duplicate(true);mixed[flag]=PackedInt32Array([1]);city.transit_routes=[mixed]
  var lines:Array=View.build_geometry(city).catenary
  check(not lines.is_empty() and lines.all(func(p):return p.a.x<=30.0001 and p.b.x<=30.0001),flag+" stops exactly at portal")
  var last:=0.0
  for p in lines:
   if p.kind=="pole":last=maxf(last,p.a.x)
  check(last>=29 and last<=30,"last portal pole within 4m on open side")
 city.transit_routes=[route(PackedVector2Array([Vector2(0,20),Vector2(25,20)]))]
 var lines:Array=View.build_geometry(city).catenary
 var brackets:Array=lines.filter(func(p):return p.kind=="horizontal")
 check(brackets.all(func(p):return p.a_height==4.8 and p.b_height==4.8 and p.color==Color("9aa1a4") and is_equal_approx(p.a.distance_to(p.b)*4,2)),"horizontal bracket exact 2m height and colour")
 check(lines.filter(func(p):return p.kind=="diagonal").all(func(p):return p.a_height==3.9 and p.b_height==4.8),"diagonal 3.9 to 4.8m")
 check(lines.filter(func(p):return p.kind=="pull").all(func(p):return p.a_height==4.8 and p.b_height==3.8),"pull 4.8 to 3.8m")
 var lowest:=INF
 for p in lines:
  if p.kind=="messenger":lowest=minf(lowest,minf(p.a_height,p.b_height))
 check(is_equal_approx(lowest,4.3),"messenger parabola midspan sag exactly 0.5m")
 var arc:=PackedVector2Array()
 for i in range(65):arc.append(Vector2(40,40)+Vector2.from_angle(PI*.5*i/64)*8.5)
 city.transit_routes=[route(arc)]
 lines=View.build_geometry(city).catenary
 var pole_count:int=lines.filter(func(p):return p.kind=="pole").size()
 check(pole_count>=14,"34m curve uses no greater than 8m spans")
 # Crossing: mask includes sidewalks, plus the required one-metre setback.
 city.transit_routes=[route(PackedVector2Array([Vector2(0,20),Vector2(40,20)]))]
 city.road_pavement=[PackedVector2Array([Vector2(15,0),Vector2(25,0),Vector2(25,40),Vector2(15,40)])]
 lines=View.build_geometry(city).catenary
 var poles:Array=lines.filter(func(p):return p.kind=="pole")
 check(poles.all(func(p):return p.a.x<=14.75001 or p.a.x>=25.24999),"no poles on full sidewalk-inclusive road plus 1m")
 check(lines.any(func(p):return p.kind=="contact" and p.a.x<=20 and p.b.x>=20),"contact continues above 40m crossing at 3.8m")
 city.road_pavement.clear()
 var internal:=route(PackedVector2Array([Vector2(20,20),Vector2(28,20)]));internal.owner_lot_id=9
 city.transit_routes=[internal]
 city.public_facilities.lots=[{"id":9,"public_asset_id":"train-station-01","internal_points":internal.points,"polygon":PackedVector2Array([Vector2(20,13),Vector2(28,13),Vector2(28,22),Vector2(20,22)])}]
 lines=View.build_geometry(city).catenary;poles=lines.filter(func(p):return p.kind=="pole")
 check(poles.size()==4 and poles.all(func(p):return is_equal_approx(p.a.x,19.75) or is_equal_approx(p.a.x,28.25)),"station paired poles exactly 1m beyond lot ends, 34m span")
 check(lines.any(func(p):return p.kind=="contact" and p.a.x<=24 and p.b.x>=24),"station wires span the empty trackway")
 city.transit_routes.append(route(PackedVector2Array([Vector2(28,20),Vector2(50,20)]),2))
 lines=View.build_geometry(city).catenary;poles=lines.filter(func(p):return p.kind=="pole")
 check(poles.all(func(p):return p.a.x<=19.75001 or p.a.x>=28.24999),"connected station approach has no support on platform-edge endpoint")
 city.public_facilities.lots.clear()
 city.transit_routes=[route(PackedVector2Array([Vector2(0,0),Vector2(20,0)]))]
 lines=View.build_geometry(city).catenary
 check(lines.all(func(p):return p.a.x>=0 and p.a.y>=0 and p.b.x>=0 and p.b.y>=0),"pole bracket and wire geometry clipped at map edge")
 city.transit_routes=[route(PackedVector2Array([Vector2(10,20),Vector2(30,20)])),route(PackedVector2Array([Vector2(30,20),Vector2(50,20)]),2)]
 lines=View.build_geometry(city).catenary;poles=lines.filter(func(p):return p.kind=="pole")
 var unique:Dictionary={}
 for pole in poles:unique[pole.a]=true
 check(unique.size()==poles.size(),"connected route seam shares supports rather than double-drawing poles")
 city.transit_routes=[route(PackedVector2Array([Vector2(5,30),Vector2(70,30)])),route(PackedVector2Array([Vector2(20,28),Vector2(40,30)]),2)]
 lines=View.build_geometry(city).catenary;poles=lines.filter(func(p):return p.kind=="pole")
 var outside:=true
 for pole in poles:
  for other:Dictionary in city.transit_routes:
   if other.id==pole.route_id:continue
   for i in range(1,other.points.size()):
    if Geometry2D.get_closest_point_to_segment(pole.a,other.points[i-1],other.points[i]).distance_to(pole.a)<.9499:outside=false
 check(outside,"branch/merge portal poles stay outside both ballast ribbons")
 var beams:Array=lines.filter(func(p):return p.kind=="portal")
 check(not beams.is_empty(),"shallow merge uses portal beams instead of relocating supports")
 var portal_ok:=not beams.is_empty();var hangers_ok:=not beams.is_empty()
 for beam:Dictionary in beams:
  portal_ok=portal_ok and is_equal_approx(beam.a.x,beam.b.x) and beam.a_height==5.3 and beam.b_height==5.3 and beam.color==Color("6f7579")
  var branch_y:float=28+(beam.a.x-20)*.1
  portal_ok=portal_ok and is_equal_approx(minf(beam.a.y,beam.b.y),branch_y-1) and is_equal_approx(maxf(beam.a.y,beam.b.y),31)
  portal_ok=portal_ok and is_equal_approx(beam.a.distance_to(beam.b)*4,8+(30-branch_y)*4)
  var tubes:Array=lines.filter(func(p):return p.kind=="portal_tube" and p.get("portal_id",Vector2.INF)==beam.get("portal_id",Vector2.ZERO))
  hangers_ok=hangers_ok and tubes.size()==4
  for tube:Dictionary in tubes:
   hangers_ok=hangers_ok and tube.a==tube.b and tube.a_height==5.3 and tube.b_height==4.8 and tube.color==Color("9aa1a4")
   hangers_ok=hangers_ok and lines.any(func(p):return p.kind=="pull" and p.a.is_equal_approx(tube.a) and p.b==p.a and p.a_height==4.8 and p.b_height==3.8)
 check(portal_ok,"portal perpendicular to longer main: outer 4m poles, 5.3m beam, length 8m plus separation")
 check(hangers_ok,"each of four tracks has vertical 5.3-to-4.8 tube and 4.8-to-3.8 pull")
 var span_m:=0.0;var longest_span_m:=0.0
 for wire:Dictionary in lines:
  if wire.kind!="messenger":continue
  if is_equal_approx(wire.a_height,4.8):span_m=0.0
  span_m+=wire.a.distance_to(wire.b)*4
  if is_equal_approx(wire.b_height,4.8):longest_span_m=maxf(longest_span_m,span_m)
 check(longest_span_m<=32.0001,"branch/merge retains standard <=32m straight spacing, no 48m exception (longest %.3fm)"%longest_span_m)
 var anchored:=true;var rigid:=true
 for tube:Dictionary in lines.filter(func(p):return p.kind=="portal_tube"):
  anchored=anchored and lines.any(func(p):return p.kind=="messenger" and ((p.a.is_equal_approx(tube.a) and is_equal_approx(p.a_height,4.8)) or (p.b.is_equal_approx(tube.a) and is_equal_approx(p.b_height,4.8))))
  rigid=rigid and not lines.any(func(p):return p.kind in ["horizontal","diagonal"] and p.b.is_equal_approx(tube.a))
 check(anchored,"portal tubes actually terminate messenger spans at 4.8m on every track")
 check(rigid,"portal tracks have no movable horizontal or diagonal brackets")
 var original_routes:=var_to_bytes(city.transit_routes)
 var original_beams:Array=beams.map(func(p):return [p.a,p.b])
 city.transit_routes.reverse()
 var reversed_beams:Array=View.build_geometry(city).catenary.filter(func(p):return p.kind=="portal").map(func(p):return [p.a,p.b])
 check(original_beams.size()==reversed_beams.size() and original_beams.all(func(p):return reversed_beams.has(p)),"portal geometry independent of route insertion order")
 city.transit_routes.reverse()
 check(var_to_bytes(city.transit_routes)==original_routes,"portal planning leaves route bytes unchanged")
 for gap:float in [.1,.15,.151]:
  city.transit_routes=[route(PackedVector2Array([Vector2(5,30),Vector2(70,30)])),route(PackedVector2Array([Vector2(5,32+gap),Vector2(70,32+gap)]),2)]
  lines=View.build_geometry(city).catenary;poles=lines.filter(func(p):return p.kind=="pole")
  var merged:Array=poles.filter(func(p):return absf(p.a.y-(31+gap/2))<.0001)
  check((not merged.is_empty()) if gap<=.15 else merged.is_empty(),"inner poles merge only within inclusive 0.6m: gap %.3fm"%(gap*4))
  if gap<=.15:
   check(merged.all(func(p):return lines.filter(func(b):return b.kind=="horizontal" and b.a.is_equal_approx(p.a)).size()==2),"combined inner pole carries both track brackets")
 for variant:int in [0,1,2]:
  var main_points:=PackedVector2Array([Vector2(5,30),Vector2(70,30)])
  var branch_points:=PackedVector2Array([Vector2(20,28),Vector2(40,30)])
  for points:PackedVector2Array in [main_points,branch_points]:
   for i in range(points.size()):
    if variant==0:points[i]=Vector2(points[i].y,points[i].x)
    elif variant==1:points[i].y=60-points[i].y
    else:points[i].y-=29
  city.transit_routes=[route(main_points),route(branch_points,2)]
  lines=View.build_geometry(city).catenary
  var transformed:Array=lines.filter(func(p):return p.kind=="portal")
  check(not transformed.is_empty() and transformed.all(func(p):return absf((p.b-p.a).dot((main_points[-1]-main_points[0]).normalized()))<.0001),"portal perpendicular for rotated/mirrored/boundary fixture %d"%variant)
  check(lines.all(func(p):return p.a.x>=0 and p.a.y>=0 and p.b.x>=0 and p.b.y>=0),"portal geometry clipped at map boundary fixture %d"%variant)
 portal_exclusion_cases(city)
 var closed:=PackedVector2Array()
 for i in range(97):closed.append(Vector2(50,50)+Vector2.from_angle(TAU*i/96)*12)
 closed[-1]=closed[0];city.transit_routes=[route(closed)]
 lines=View.build_geometry(city).catenary;poles=lines.filter(func(p):return p.kind=="pole");unique.clear()
 for pole in poles:unique[Vector2(snappedf(pole.a.x,.001),snappedf(pole.a.y,.001))]=true
 check(unique.size()==poles.size(),"closed route seam has no duplicate supports")
 check(lines.filter(func(p):return p.kind=="contact").all(func(p):return p.a.distance_to(p.b)<=1.0001),"retained overhead pieces never exceed 4 metres")
func portal_exclusion_cases(city):
 for obstacle:String in ["road","station"]:
  for mirror:bool in [false,true]:
   var main:=PackedVector2Array([Vector2(5,30),Vector2(70,30)])
   var branch:=PackedVector2Array([Vector2(20,28),Vector2(40,30)])
   var polygon:=PackedVector2Array([Vector2(26,30.8),Vector2(28,30.8),Vector2(28,32),Vector2(26,32)])
   if mirror:
    for points:PackedVector2Array in [main,branch,polygon]:
     for i in range(points.size()):points[i].y=60-points[i].y
   city.transit_routes=[route(main),route(branch,2)]
   if obstacle=="road":city.road_pavement=[polygon]
   else:city.public_facilities.lots=[{"id":9,"public_asset_id":"train-station-01","polygon":polygon}]
   var lines:Array=View.build_geometry(city).catenary
   var label:="%s opposite portal base mirror=%s"%[obstacle,mirror]
   var masks:Array=Array(Geometry2D.offset_polygon(polygon,.25,Geometry2D.JOIN_MITER))
   var clearance:=true;var anchored:=true;var supported:=true
   var longest:=0.0;var span:=0.0
   for item:Dictionary in lines:
    if item.kind=="pole":
     for mask:PackedVector2Array in masks:
      if not Geometry2D.is_point_in_polygon(item.a,mask):continue
      var distance:=INF
      for i in range(mask.size()):distance=minf(distance,item.a.distance_to(Geometry2D.get_closest_point_to_segment(item.a,mask[i],mask[(i+1)%mask.size()])))
      if distance>.00001:clearance=false
    if item.kind=="portal_tube":
     anchored=anchored and lines.any(func(p):return p.kind=="messenger" and p.route_id==item.route_id and ((p.a.is_equal_approx(item.a) and is_equal_approx(p.a_height,4.8)) or (p.b.is_equal_approx(item.a) and is_equal_approx(p.b_height,4.8))))
    if item.kind=="messenger":
     if is_equal_approx(item.a_height,4.8):span=0
     span+=item.a.distance_to(item.b)*4
     if is_equal_approx(item.b_height,4.8):longest=maxf(longest,span)
     for endpoint:Vector2 in ([item.a] if is_equal_approx(item.a_height,4.8) else [])+([item.b] if is_equal_approx(item.b_height,4.8) else []):
      supported=supported and lines.any(func(p):return p.kind=="pull" and p.a.is_equal_approx(endpoint))
   check(lines.any(func(p):return p.kind=="portal"),label+" exercises actual portal branch")
   check(clearance,label+" BOTH final bases outside existing 1m exclusions")
   check(anchored,label+" every hanger matches retained wire anchor")
   check(supported,label+" every wire span endpoint retains physical support")
   check(longest<=48.0001,label+" bounded exclusion span <=48m (%.3fm)"%longest)
   # Sum projected chords per track: subdivision/anchor shifts cannot hide deleted wires.
   var complete:=true
   for r:Dictionary in city.transit_routes:
    var tangent:Vector2=(r.points[-1]-r.points[0]).normalized()
    var covered:=0.0
    for item:Dictionary in lines:
     if item.kind=="contact" and item.route_id==r.id:covered+=(item.b-item.a).dot(tangent)
    var expected:float=(r.points[0].distance_to(r.points[-1])-1.0-(1.0 if r.id==1 else 0.0))*2
    complete=complete and absf(covered-expected)<.0001
   check(complete,label+" both full branch/main wire tracks retained")
   city.road_pavement.clear();city.public_facilities.lots.clear()
