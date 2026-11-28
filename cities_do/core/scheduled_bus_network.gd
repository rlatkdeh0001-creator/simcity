extends "res://core/traffic_network.gd"
## Curb branches share the ordinary lane graph; unshouldered stops occupy their outer running lane.
var stops:Dictionary={}
func build_city(city)->bool:
 stops.clear()
 if not build(city.roads):return false
 for lot:Dictionary in city.public_facilities.lots:
  if lot.get("public_asset_id","")!="bus-stop-01" or int(lot.get("front_road_id",-1))<0:continue
  var road_index:=-1
  for i in range(city.roads.size()):
   if city.roads[i].parcel_id==lot.front_road_id:road_index=i;break
  if road_index<0:continue
  var road:Dictionary=city.roads[road_index];var direction:int=lot.get("road_direction",0)
  if direction not in [-1,1]:continue
  var count:=Profile.direction_count(road,direction)
  if count==0:continue
  var outer:=count-1
  var choice:Dictionary={};var best:=INF;var progress:=0.0
  for lane:Dictionary in lanes:
   if lane.get("road",-1)!=road_index or lane.get("direction",0)!=direction or lane.get("index",-1)!=outer or lane.get("bus_pocket",false):continue
   var p:Vector2=lot.position*4
   var along:float=lane.curve.get_closest_offset(Vector3(p.x,0,p.y))
   var d:float=sample(lane.id,along).distance_to(p)
   if d<best:best=d;choice=lane;progress=along
  if choice.is_empty():continue
  if progress<20 or progress>float(choice.length)-20:continue # No berth/merge inside a junction.
  var stop:Dictionary={"id":lot.id,"lane":choice.id,"progress":progress}
  if Profile.shoulder_width(road,direction)>0:
   stop=add_pocket(choice,progress,lot.position*4+lot.front_direction*1.25,lot.id)
  stops[lot.id]=stop
 search.clear();search.lengths.clear()
 for lane:Dictionary in lanes:search.add_point(lane.id,sample(lane.id,0));search.lengths[lane.id]=lane.length
 for lane:Dictionary in lanes:
  for next:int in lane.next:
   if next!=lane.id:search.connect_points(lane.id,next,false)
 return errors.is_empty()
func points_of(lane:Dictionary)->PackedVector2Array:
 var points:=PackedVector2Array()
 for p:Vector3 in lane.curve.get_baked_points():points.append(Vector2(p.x,p.z))
 return points
func replace_curve(lane:Dictionary,points:PackedVector2Array):
 var curve:=Curve3D.new();curve.bake_interval=.2
 for p:Vector2 in points:curve.add_point(Vector3(p.x,0,p.y))
 lane.curve=curve;lane.length=curve.get_baked_length();lane.closed=false
func derived(points:PackedVector2Array,source:Dictionary)->Dictionary:
 var lane:Dictionary=_add_lane(points);var id:int=lane.id;var curve:Curve3D=lane.curve;var length:float=lane.length
 lane.merge(source.duplicate(),true);lane.id=id;lane.curve=curve;lane.length=length;lane.next=[];lane.closed=false
 return lane
func add_pocket(lane:Dictionary,progress:float,curb:Vector2,id:int)->Dictionary:
 var points:=points_of(lane);var old_next:Array=lane.next.duplicate()
 var lo:float=progress-20;var hi:float=progress+20
 var tail:=derived(Junctions.slice(points,hi,lane.length),lane)
 var through:=derived(Junctions.slice(points,lo,hi),lane)
 var pocket_points:=PackedVector2Array()
 var shift:Vector2=curb-sample(lane.id,progress)
 for i in range(81):
  var along:float=lo+i*.5
  var blend:float=smoothstep(0.0,14.0,minf(along-lo,hi-along))
  pocket_points.append(sample(lane.id,along)+shift*blend)
 var pocket:=derived(pocket_points,lane);pocket.bus_pocket=true
 tail.next=old_next;through.next=[tail.id];pocket.next=[tail.id]
 replace_curve(lane,Junctions.slice(points,0,lo));lane.next=[through.id,pocket.id]
 for next:int in old_next:
  if lanes[next].get("from",-1)==lane.id:lanes[next].from=tail.id
 return {"id":id,"lane":pocket.id,"progress":pocket.curve.get_closest_offset(Vector3(curb.x,0,curb.y))}
func line_plan(ids:Array)->Dictionary:
 var invalid:Dictionary={"ok":false,"code":"unreachable_line","reason":"버스 정류장과 이어진 회차 도로를 확인하세요"}
 if ids.size()<2:return invalid
 for id:Variant in ids:
  if not stops.has(id):return invalid
 var path:Array=[stops[ids[0]].lane];var planned:Array=[stops[ids[0]].duplicate(true)];planned[0].route_index=0
 for i in range(1,ids.size()+1):
  var target:Dictionary=stops[ids[i%ids.size()]]
  var start:int=path[-1];var segment:Array=[]
  if start==target.lane and (i==ids.size() or float(target.progress)<=float(stops[ids[i-1]].progress)):
   for next:int in lanes[start].next:
    var candidate:Array=route(next,target.lane)
    if not candidate.is_empty():segment=[start]+candidate;break
  else:segment=route(start,target.lane)
  if segment.is_empty():return invalid
  for j in range(1,segment.size()):path.append(segment[j])
  if i<ids.size():
   var stop:Dictionary=target.duplicate(true);stop.route_index=path.size()-1;planned.append(stop)
 if path.size()<2 or path[-1]!=path[0]:return invalid
 path.pop_back()
 if not path[0] in lanes[path[-1]].next:return invalid
 return {"ok":true,"route":path,"stops":planned}
