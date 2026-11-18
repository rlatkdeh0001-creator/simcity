extends RefCounted
## Display-only metres above rail datum; world XY remains in four-metre cells.
const Height=preload("res://core/road_height.gd")
const POLE:=Color("6f7579")
const BRACKET:=Color("9aa1a4")
const WIRE:=Color("2a2e30")
static func line(kind:String,a:Vector2,b:Vector2,ha:float,hb:float,color:Color,footprint:PackedVector2Array)->Dictionary:
 return {"kind":kind,"a":a,"b":b,"a_height":ha,"b_height":hb,"color":color,"footprint":footprint}
static func normal_at(points:PackedVector2Array,index:int)->Vector2:
 var last:=points.size()-1
 var before:Vector2=(points[index]-points[index-1]).normalized() if index>0 else (points[1]-points[0]).normalized()
 var after:Vector2=(points[index+1]-points[index]).normalized() if index<last else before
 if points[0].distance_to(points[-1])<.0001 and index in [0,last]:
  before=(points[0]-points[-2]).normalized();after=(points[1]-points[0]).normalized()
 var tangent:Vector2=(before+after).normalized()
 return Vector2(-tangent.y,tangent.x)
static func sample(points:PackedVector2Array,distance:float)->Dictionary:
 var remaining:=distance
 for i in range(1,points.size()):
  var length:=points[i-1].distance_to(points[i])
  if remaining<=length or i==points.size()-1:
   var tangent:=(points[i]-points[i-1]).normalized()
   return {"point":points[i-1]+tangent*remaining,"normal":normal_at(points,i-1).lerp(normal_at(points,i),clampf(remaining/length,0,1)).normalized()}
  remaining-=length
 return {}
static func length_of(points:PackedVector2Array)->float:
 var result:=0.0
 for i in range(1,points.size()):result+=points[i-1].distance_to(points[i])
 return result
static func wire_anchor(at:Dictionary,side:float,portals:Array,route_id:int)->Vector2:
 for portal:Dictionary in portals:
  if portal.allowed and portal.centres.has(route_id) and at.point.distance_to(portal.centres[route_id])<.0001:
   return portal.tracks[route_id][0 if side<0 else 1]
 return at.point+at.normal*.5*side
static func append_span(output:Array,points:PackedVector2Array,start:float,finish:float,portals:Array=[],route_id:int=-1):
 var first:=sample(points,start);var last:=sample(points,finish)
 # A fixed wire is a chord between supports, not a texture bent around the track.
 for side:float in [-1.0,1.0]:
  var a:Vector2=wire_anchor(first,side,portals,route_id)
  var b:Vector2=wire_anchor(last,side,portals,route_id)
  append_wire_pair(output,a,b)
static func append_wire_pair(output:Array,a:Vector2,b:Vector2):
 var count:=maxi(2,ceili(a.distance_to(b)/2)*2)
 for i in range(count):
  var t0:=float(i)/count;var t1:=float(i+1)/count
  var p:=a.lerp(b,t0);var q:=a.lerp(b,t1)
  var n:Vector2=(b-a).normalized().orthogonal()*.45
  var footprint:=PackedVector2Array([p-n,q-n,q+n,p+n])
  output.append(line("contact",p,q,3.8,3.8,WIRE,footprint))
  output.append(line("messenger",p,q,4.8-2*t0*(1-t0),4.8-2*t1*(1-t1),WIRE,footprint))
static func crossover_supports(x:Dictionary,city=null)->PackedVector2Array:
 # The station-side support shares the required 1m lot setback support. The far
 # support moves 1m inside the fixed 32m host only when its poles would break
 # another station lot's 1m setback (ports facing at exactly 32m: 30m span).
 var far:Vector2=x.end
 if city!=null and far_end_at_station(x,city):far-=x.axis
 return PackedVector2Array([(x.start+x.axis)/4.0,far/4.0])
static func far_end_at_station(x:Dictionary,city)->bool:
 var end:Vector2=x.end/4.0
 var side:=Vector2(-x.axis.y,x.axis.x)
 for lot:Dictionary in city.public_facilities.lots:
  if lot.get("public_asset_id","")!="train-station-01" or lot.id==x.station_id:continue
  # Same 1m lot mask and pole bases (+/-4m) as the ordinary support check.
  var masks:Array=Geometry2D.offset_polygon(lot.polygon,.25,Geometry2D.JOIN_MITER)
  for sign_value:float in [-1.0,1.0]:
   if not base_allowed(end+side*sign_value,masks):return true
 return false
static func ground_crossover(x:Dictionary,city)->bool:
 var axis:Vector2=x.axis
 var origin:Vector2=x.start/4.0
 for route:Dictionary in city.transit_routes:
  if route.kind!="rail":continue
  for i in range(1,route.points.size()):
   var a:Vector2=route.points[i-1]-origin;var b:Vector2=route.points[i]-origin
   if absf(a.cross(axis))>.0005 or absf(b.cross(axis))>.0005:continue
   if maxf(a.dot(axis),b.dot(axis))<=.0005 or minf(a.dot(axis),b.dot(axis))>=7.9995:continue
   if route.get("covered",false) or route.get("underground",false) or not is_zero_approx(float(route.rail_top_z_m)) or hidden_segment(route,i-1):return false
 return true
static func append_crossover(output:Array,x:Dictionary,city,masks:Array):
 if not ground_crossover(x,city):return
 var points:=crossover_supports(x,city)
 var length:=length_of(points)
 if not support_allowed(points,0,masks) or not support_allowed(points,length,masks):return
 var normal:=normal_at(points,0)*.5
 var start:=output.size()
 for side:float in [-1.0,1.0]:append_wire_pair(output,points[0]+normal*side,points[1]-normal*side)
 for i in range(start,output.size()):
  output[i].crossover_key=x.key
  output[i].route_id=-1
static func append_poles(output:Array,points:PackedVector2Array,distance:float):
 var at:=sample(points,distance)
 for side:float in [-1.0,1.0]:
  var base:Vector2=at.point+at.normal*side
  var track:Vector2=at.point+at.normal*.5*side
  var footprint:=PackedVector2Array([base,track])
  output.append(line("pole",base,base,0,5.3,POLE,PackedVector2Array([base])))
  output.append(line("cap",base-at.normal*.075,base+at.normal*.075,5.3,5.3,POLE,PackedVector2Array([base])))
  output.append(line("horizontal",base,track,4.8,4.8,BRACKET,footprint))
  output.append(line("diagonal",base,track,3.9,4.8,BRACKET,footprint))
  output.append(line("pull",track,track,4.8,3.8,BRACKET,footprint))
  for i in range(output.size()-5,output.size()):
   output[i].support=base;output[i].centre=at.point;output[i].near=(base.x+base.y>track.x+track.y)
static func distance_on(points:PackedVector2Array,point:Vector2)->float:
 var travelled:=0.0
 for i in range(1,points.size()):
  var closest:=Geometry2D.get_closest_point_to_segment(point,points[i-1],points[i])
  if closest.distance_to(point)<.0001:return travelled+points[i-1].distance_to(closest)
  travelled+=points[i-1].distance_to(points[i])
 return -INF
static func cross_section(route:Dictionary,origin:Vector2,normal:Vector2,offset:float=0)->Dictionary:
 var points:PackedVector2Array=route.points
 var best:Dictionary={};var nearest:=INF
 for i in range(1,points.size()):
  if hidden_segment(route,i-1):continue
  var a:=points[i-1]+normal_at(points,i-1)*offset
  var b:=points[i]+normal_at(points,i)*offset
  var edge:=b-a;var denominator:=edge.cross(normal)
  if absf(denominator)<.000001:continue
  var t:float=(origin-a).cross(normal)/denominator
  if t<-.00001 or t>1.00001:continue
  var hit:=a+edge*clampf(t,0,1)
  if hit.distance_to(origin)<nearest:
   nearest=hit.distance_to(origin);best={"point":hit,"normal":Vector2(-edge.y,edge.x).normalized()}
 return best
static func plan_portals(commands:Array,routes:Array,masks:Array=[])->Array:
 var eligible:Array=routes.filter(func(r):return r.kind=="rail" and not r.get("covered",false) and not r.get("underground",false) and is_zero_approx(float(r.rail_top_z_m)))
 # Stable longer-route priority, independent of insertion order.
 eligible.sort_custom(func(a,b):return length_of(a.points)>length_of(b.points) if not is_equal_approx(length_of(a.points),length_of(b.points)) else a.id<b.id)
 var portals:Array=[]
 for command:Dictionary in commands:
  if command.kind!="pole":continue
  var own:Dictionary={}
  for r:Dictionary in eligible:
   if r.id==command.route_id:own=r;break
  if own.is_empty():continue
  for other:Dictionary in eligible:
   if other.id==own.id:continue
   var intrudes:=false
   for i in range(1,other.points.size()):
    if not hidden_segment(other,i-1) and Geometry2D.get_closest_point_to_segment(command.a,other.points[i-1],other.points[i]).distance_to(command.a)<.95:intrudes=true
   if not intrudes:continue
   var main:Dictionary=own if eligible.find(own)<eligible.find(other) else other
   var branch:Dictionary=other if main.id==own.id else own
   var at:=sample(main.points,maxf(0,distance_on(main.points,command.centre)))
   # Find the main tangent nearest this support (branch supports are off-main).
   var nearest:=INF
   for i in range(1,main.points.size()):
    var p:=Geometry2D.get_closest_point_to_segment(command.centre,main.points[i-1],main.points[i])
    if p.distance_to(command.centre)<nearest:
     nearest=p.distance_to(command.centre);var tangent:Vector2=(main.points[i]-main.points[i-1]).normalized();at.normal=Vector2(-tangent.y,tangent.x)
   var normal:Vector2=at.normal
   var m:=cross_section(main,command.centre,normal);var b:=cross_section(branch,command.centre,normal)
   if m.is_empty() or b.is_empty():continue
   var separation:float=(b.point-m.point).dot(normal)
   if absf(separation)<.0001 or absf(separation)>=1.95:continue
   if portals.any(func(p):return p.main_id==main.id and p.branch_id==branch.id and p.centres[main.id].distance_to(m.point)<.0001):continue
   var centres:Dictionary={main.id:m.point,branch.id:b.point};var tracks:Dictionary={}
   var valid:=true
   for r:Dictionary in [main,branch]:
    tracks[r.id]=[]
    for side:float in [-.5,.5]:
     var track:=cross_section(r,command.centre,normal,side)
     if track.is_empty():valid=false;break
     tracks[r.id].append(track.point)
   if not valid:continue
   var low:Vector2=m.point+normal*(minf(0,separation)-1)
   var high:Vector2=m.point+normal*(maxf(0,separation)+1)
   # Keep rejected sections in the plan too: neither route may retain a wire
   # anchor or an ordinary inner pole where the complete portal is prohibited.
   portals.append({"main_id":main.id,"branch_id":branch.id,"centres":centres,"tracks":tracks,"a":low,"b":high,"allowed":base_allowed(low,masks) and base_allowed(high,masks)})
 return portals
static func apply_portals(commands:Array,portals:Array)->Array:
 var result:Array=[]
 for command:Dictionary in commands:
  var replaced:=false
  if command.has("centre"):
   for portal:Dictionary in portals:
    if portal.centres.has(command.route_id) and command.centre.distance_to(portal.centres[command.route_id])<.0001:replaced=true;break
  if not replaced:result.append(command)
 for portal:Dictionary in portals:
  if not portal.allowed:continue
  var normal:Vector2=(portal.b-portal.a).normalized()
  var footprint:=PackedVector2Array([portal.a,portal.b])
  var beam:=line("portal",portal.a,portal.b,5.3,5.3,POLE,footprint)
  beam.portal_id=portal.a;beam.route_id=portal.main_id
  beam.support=portal.a if portal.a.dot(Vector2.ONE)>portal.b.dot(Vector2.ONE) else portal.b
  beam.near=true;result.append(beam)
  for base:Vector2 in [portal.a,portal.b]:
   for item:Dictionary in [line("pole",base,base,0,5.3,POLE,PackedVector2Array([base])),line("cap",base-normal*.075,base+normal*.075,5.3,5.3,POLE,PackedVector2Array([base]))]:
    item.route_id=portal.main_id;item.support=base;item.near=base.x+base.y>(portal.a+portal.b).dot(Vector2.ONE)/2;result.append(item)
  for id in portal.tracks:
   for track:Vector2 in portal.tracks[id]:
    for item:Dictionary in [line("portal_tube",track,track,5.3,4.8,BRACKET,PackedVector2Array([track])),line("pull",track,track,4.8,3.8,BRACKET,PackedVector2Array([track]))]:
     item.route_id=id;item.portal_id=portal.a;item.support=beam.support;item.near=true;result.append(item)
 return result
static func combine_inner_poles(commands:Array)->Array:
 var poles:Array=commands.filter(func(c):return c.kind=="pole" and c.has("centre"))
 var merged:Dictionary={}
 for i in range(poles.size()):
  var a:Dictionary=poles[i];var key:Variant=[a.route_id,a.support]
  if merged.has(key):continue
  for j in range(i+1,poles.size()):
   var b:Dictionary=poles[j];var other:Variant=[b.route_id,b.support]
   if a.route_id==b.route_id or merged.has(other) or a.a.distance_to(b.a)>.15001:continue
   if (b.centre-a.centre).dot(a.a-a.centre)<=0 or (a.centre-b.centre).dot(b.a-b.centre)<=0:continue
   var common:Vector2=(a.a+b.a)/2
   merged[key]=common;merged[other]=common;break
 for command:Dictionary in commands:
  if not command.has("support"):continue
  var key:Variant=[command.route_id,command.support]
  if not merged.has(key):continue
  var base:Vector2=merged[key];var delta:Vector2=base-command.support
  if command.kind in ["pole","cap"]:command.a+=delta;command.b+=delta;command.footprint=PackedVector2Array([base])
  elif command.kind in ["horizontal","diagonal"]:command.a=base;command.footprint=PackedVector2Array([base,command.b])
  elif command.kind=="pull":command.footprint=PackedVector2Array([base,command.b])
  command.support=base
 return commands
static func spacing_m(radius_m:float)->float:
 if radius_m>=512:return 32.0
 return maxf(8.0,floor(sqrt(2*radius_m)/4)*4)
static func radius_at(points:PackedVector2Array,index:int)->float:
 if index<=0 or index>=points.size()-1:return INF
 var a:=points[index]-points[index-1];var b:=points[index+1]-points[index]
 var cross:=absf(a.cross(b))
 if cross<.0000001:return INF
 return a.length()*b.length()*(a+b).length()/cross*2.0
static func hidden_segment(route:Dictionary,index:int)->bool:
 # Optional display-only segment masks: zero-based edges of route.points.
 # There is no tunnel/grade editor in this stage; never rewrite the route schema.
 return index in route.get("covered_segments",[]) or index in route.get("underground_segments",[])
static func forbidden_intervals(points:PackedVector2Array,masks:Array)->Array:
 var intervals:Array=[];var travelled:=0.0
 for i in range(1,points.size()):
  var a:=points[i-1];var b:=points[i];var length:=a.distance_to(b)
  var normal:=(b-a).normalized().orthogonal()
  for side:float in [-1.0,1.0]:
   var p:=a+normal*side;var q:=b+normal*side
   for mask:PackedVector2Array in masks:
    var cuts:Array[float]=[0.0,1.0]
    for j in range(mask.size()):
     var hit:Variant=Geometry2D.segment_intersects_segment(p,q,mask[j],mask[(j+1)%mask.size()])
     if hit!=null:cuts.append(clampf(p.distance_to(hit)/length,0,1))
    cuts.sort()
    for j in range(1,cuts.size()):
     if cuts[j]-cuts[j-1]<.000001:continue
     if Geometry2D.is_point_in_polygon(p.lerp(q,(cuts[j-1]+cuts[j])/2),mask):
      intervals.append(Vector2(travelled+cuts[j-1]*length,travelled+cuts[j]*length))
  travelled+=length
 intervals.sort_custom(func(a,b):return a.x<b.x)
 var merged:Array=[]
 for interval:Vector2 in intervals:
  if not merged.is_empty() and interval.x<=merged[-1].y+.00001:merged[-1].y=maxf(merged[-1].y,interval.y)
  else:merged.append(interval)
 return merged
static func support_allowed(points:PackedVector2Array,distance:float,masks:Array)->bool:
 var at:=sample(points,distance)
 for side:float in [-1.0,1.0]:
  if not base_allowed(at.point+at.normal*side,masks):return false
 return true
static func base_allowed(point:Vector2,masks:Array)->bool:
 for mask:PackedVector2Array in masks:
  if not Geometry2D.is_point_in_polygon(point,mask):continue
  var edge_distance:=INF
  for i in range(mask.size()):edge_distance=minf(edge_distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,mask[i],mask[(i+1)%mask.size()])))
  if edge_distance>.00001:return false
 return true
static func append_run(output:Array,points:PackedVector2Array,start:float,finish:float,masks:Array,portals:Array=[],route_id:int=-1,crossovers:Array=[],city=null):
 if finish<=start:return
 # Group equal local pitch sections, then divide each into equal legal spans.
 var sections:Array=[];var distance:=0.0
 for i in range(1,points.size()):
  var next:=distance+points[i-1].distance_to(points[i])
  var pitch:=spacing_m(minf(radius_at(points,i-1),radius_at(points,i)))/4
  var lo:=maxf(start,distance);var hi:=minf(finish,next)
  if hi>lo:
   if not sections.is_empty() and is_equal_approx(sections[-1].z,pitch):sections[-1].y=hi
   else:sections.append(Vector3(lo,hi,pitch))
  distance=next
 # Include extrapolated 1m station ends in the same straight span.
 if not sections.is_empty():sections[0].x=start;sections[-1].y=finish
 var positions:Array[float]=[]
 for section:Vector3 in sections:
  var count:=maxi(1,ceili((section.y-section.x)/section.z))
  for i in range(count+1):positions.append(lerpf(section.x,section.y,float(i)/count))
 var blocked:=forbidden_intervals(points,masks)
 for interval:Vector2 in blocked:
  positions=positions.filter(func(d):return d<=interval.x+.00001 or d>=interval.y-.00001)
  if interval.x>=start and interval.x<=finish:positions.append(interval.x)
  if interval.y>=start and interval.y<=finish:positions.append(interval.y)
 for x:Dictionary in crossovers:
  var supports:=crossover_supports(x,city)
  var origin:Vector2=x.start/4.0;var axis:Vector2=x.axis
  if not support_allowed(supports,0,masks) or not support_allowed(supports,length_of(supports),masks):continue
  positions=positions.filter(func(d):
   var at:=sample(points,d)
   var relative:Vector2=at.point-origin
   var axial:=relative.dot(axis)
   return absf(relative.cross(axis))>.0005 or axial<-.0005 or axial>8.0005)
  for point:Vector2 in supports:
   var distance_on_run:=distance_on(points,point)
   if distance_on_run>=start-.0001 and distance_on_run<=finish+.0001:positions.append(distance_on_run)
 # Resolve the shared section after ordinary-pole exclusions. Valid outer
 # bases replace the inner pair; rejected sections omit support, never wire.
 var portal_positions:Dictionary={}
 for portal:Dictionary in portals:
  if not portal.centres.has(route_id):continue
  var projected:=distance_on(points,portal.centres[route_id])
  if projected<start-.00001 or projected>finish+.00001:continue
  portal_positions[projected]=portal.allowed
  positions.append(projected)
 positions.sort()
 var unique:Array[float]=[]
 for d:float in positions:
  var allowed:=support_allowed(points,d,masks)
  for projected:float in portal_positions:
   if absf(d-projected)<.0001:allowed=portal_positions[projected];break
  if not allowed:continue
  if unique.is_empty() or d-unique[-1]>.0001:unique.append(d)
 # Wires still reach a boundary/portal even when its support is prohibited.
 var wires:Array[float]=unique.duplicate()
 if wires.is_empty() or wires[0]>start+.0001:wires.push_front(start)
 if wires[-1]<finish-.0001:wires.append(finish)
 for d:float in unique:append_poles(output,points,d)
 for i in range(1,wires.size()):append_span(output,points,wires[i-1],wires[i],portals,route_id)
static func append_route(output:Array,route:Dictionary,start_cap:bool,end_cap:bool,city,masks:Array,portals:Array=[],crossovers:Array=[]):
 if route.kind!="rail" or route.get("covered",false) or route.get("underground",false) or not is_zero_approx(float(route.rail_top_z_m)):return
 var generated:Array=[];var points:PackedVector2Array=route.points
 var station:=false
 for lot:Dictionary in city.public_facilities.lots:
  if lot.get("public_asset_id","")=="train-station-01" and lot.get("internal_points",PackedVector2Array())==points:station=true
 var run_start:=0
 for i in range(points.size()):
  if i<points.size()-1 and not hidden_segment(route,i):continue
  if i>run_start:
   var run:PackedVector2Array=points.slice(run_start,i+1)
   var start:=1.0 if run_start==0 and start_cap else 0.0
   var finish:=length_of(run)-(1.0 if i==points.size()-1 and end_cap else 0.0)
   if station:
    run[0]-=(run[1]-run[0]).normalized()*.25
    run[-1]+=(run[-1]-run[-2]).normalized()*.25
    start=0;finish=length_of(run)
   var surface:Array=crossovers.filter(func(x):return ground_crossover(x,city))
   append_level_runs(generated,route,run,start,finish,masks,portals,surface,city)
  run_start=i+1
 for item:Dictionary in generated:
  item.route_id=route.id
  if route.has("heights_m"):
   # E3a: same 3.8/4.8/5.3m layout measured from the deck/ramp rail top.
   var ha:=Height.height_at(route,item.a);var hb:=Height.height_at(route,item.b)
   item.a_height+=ha;item.b_height+=hb
   if maxf(ha,hb)>Height.EPS:item.deck=true
 append_clipped(output,generated,city)
## E3a: poles stand on the structure wherever the track is raised, so ground masks
## (roads, station lots) and ground crossovers apply only to the at-grade parts.
static func append_level_runs(output:Array,route:Dictionary,run:PackedVector2Array,start:float,finish:float,masks:Array,portals:Array,crossovers:Array,city):
 if not Height.raised(route):
  append_run(output,run,start,finish,masks,portals,int(route.id),crossovers,city);return
 var heights:=PackedFloat64Array()
 for point:Vector2 in run:heights.append(Height.height_at(route,point))
 var carrier:={"points":run,"heights_m":heights}
 for raised_part:bool in [false,true]:
  for piece:Dictionary in (Height.pieces_between(carrier,.005,INF) if raised_part else Height.pieces_between(carrier,-INF,.005)):
   var offset:=distance_on(run,piece.points[0])
   if not is_finite(offset):continue
   var first:=maxf(0.0,start-offset);var last:=minf(length_of(piece.points),finish-offset)
   if last<=first:continue
   append_run(output,piece.points,first,last,[] if raised_part else masks,portals,int(route.id),[] if raised_part else crossovers,city)
static func append_clipped(output:Array,generated:Array,city):
 for item:Dictionary in generated:
  # Liang-Barsky clipping keeps XY, height and actual line endpoints consistent.
  var a:Vector2=item.a;var delta:Vector2=item.b-a
  var lo:=0.0;var hi:=1.0;var valid:=true
  for axis:int in [0,1]:
   var maximum:float=city.width if axis==0 else city.height
   if absf(delta[axis])<.000001:
    if a[axis]<0 or a[axis]>maximum:valid=false
   else:
    var t0:float=-a[axis]/delta[axis];var t1:float=(maximum-a[axis])/delta[axis]
    lo=maxf(lo,minf(t0,t1));hi=minf(hi,maxf(t0,t1))
  if not valid or hi<lo:continue
  item.a=a+delta*lo;item.b=a+delta*hi
  var ha:float=item.a_height;var hb:float=item.b_height
  item.a_height=lerpf(ha,hb,lo);item.b_height=lerpf(ha,hb,hi)
  output.append(item)
