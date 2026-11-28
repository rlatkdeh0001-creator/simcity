extends SceneTree

const City=preload("res://core/city_model.gd")
const Height=preload("res://core/road_height.gd")
const Profile=preload("res://core/road_profile.gd")
const Network=preload("res://core/traffic_network.gd")
const Junctions=preload("res://core/road_junctions.gd")
const Geometry=preload("res://core/road_geometry.gd")
const Construction=preload("res://core/road_construction.gd")
const Parcels=preload("res://core/road_parcels.gd")

var checks:=0
var failures:=0

func _initialize():
 run.call_deferred()

func check(ok:bool,label:String):
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL ",label)

func flyover(city,points:PackedVector2Array,levels:PackedFloat64Array,commit:bool=true,count:int=4,confirmed:bool=false,approved:Variant=null)->Dictionary:
 if not city.has_method("add_center_flyover"):return {"ok":false,"reason":"Central flyover model entry point is absent"}
 return city.call("add_center_flyover",points,levels,commit,count,confirmed,1,{},approved)

func run():
 for count:int in [4,6,8]:
  var city=City.new(160,160)
  var points:=PackedVector2Array([Vector2(30,75),Vector2(78,75)])
  var heights:=PackedFloat64Array([0,10])
  var revision:int=city.road_topology_revision
  var next_id:int=city.next_road_id
  var preview:=flyover(city,points,heights,false,count)
  check(preview.ok,"%d-lane height stroke produces a preview: %s"%[count,preview.reason])
  check(city.roads.is_empty() and city.next_road_id==next_id and city.road_topology_revision==revision,"preview leaves roads, IDs and revision intact")
  var made:=flyover(city,points,heights,true,count)
  check(made.ok,"%d-lane height stroke commits: %s"%[count,made.reason])
  if not made.ok:continue
  check(city.roads.size()==3 and made.new_roads==city.roads,"three committed members in one edit")
  if city.roads.size()!=3:continue
  check(city.road_topology_revision==revision+1 and city.next_road_id==next_id+3,"one revision and three consumed IDs")
  var deck:Dictionary=city.roads[0]
  var separators:Array[float]=Profile.separators(deck)
  check(separators==([] if count==4 else [-1.0,1.0]) and (Geometry.lane_marks(deck).is_empty()==(count==4)),"raised deck uses typed separators and paints both 16m deck dashes, not one-lane deck dashes")
  var widths:Array=({4:[8,6],6:[16,6],8:[16,8]})[count]
  check(deck.width==widths[0]/4.0 and Profile.width_for_record(deck)==deck.width,"narrow deck width survives profile rebuild")
  check(deck.parcel_id==next_id and city.roads[1].parcel_id==next_id+1 and city.roads[2].parcel_id==next_id+2,"stable consecutive IDs in commit order")
  for branch:Dictionary in city.roads.slice(1):
   check(branch.width==widths[1]/4.0 and Profile.travel_direction(branch)==1 and not Height.off_ground(branch),"outer road retains ground branch profile")
   check(Height.length_cells(branch.points)==48.0,"outer road spans the full stroke")
  check(Height.height_at(deck,Vector2(34,75))==0 and Height.height_at(deck,Vector2(50,75))==5 and Height.height_at(deck,Vector2(66,75))==10,"16m ground split then 128m to +10m with exact +5m cut")
  check(Height.height_at(deck,Vector2(78,75))==10,"remaining deck is flat")
  check(city.junctions.is_empty() and city.road_crosswalks.is_empty(),"family creates no automatic junction or crosswalk")
  for x in range(30,79):
   var near_y:=INF;var far_y:=-INF
   for branch:Dictionary in city.roads.slice(1):
    var y:float=branch.points[0].y
    near_y=minf(near_y,y-branch.width/2);far_y=maxf(far_y,y+branch.width/2)
   var full:=Profile.width_for("local",count)
   check(absf(near_y-(75-full/2))*4<=.001 and absf(far_y-(75+full/2))*4<=.001,"unchanged outside envelope at %dm"%((x-30)*4))
 var city=City.new(160,160)
 var short:=flyover(city,PackedVector2Array([Vector2(30,75),Vector2(65,75)]),PackedFloat64Array([0,10]))
 check(not short.ok and city.roads.is_empty() and city.road_topology_revision==0,"sub-144m rise cannot leave a partial family")
 test_portals()
 test_curved_seams()
 print("E4C_MODEL checks=%d failed=%d"%[checks,failures])
 quit(1 if failures else 0)

func test_portals():
 var spine:=PackedVector2Array([Vector2(30,75),Vector2(74,75),Vector2(110,75)])
 var levels:=PackedFloat64Array([0,10,0])
 for count:int in [4,6,8]:
  for trunk_first:bool in [true,false]:
   var city=City.new(160,160)
   var first:=PackedVector2Array([spine[0],Vector2(14,75)]) # Reversed ordinary approach.
   var last:=PackedVector2Array([spine[-1],Vector2(126,75)])
   if trunk_first:
    check(city.add_road(first,"local",true,count,false,true).ok,"preexisting first trunk")
    check(city.add_road(last,"local",true,count,false,true).ok,"preexisting last trunk")
   var added:=flyover(city,spine,levels,true,count)
   check(added.ok,"family meets same-section trunk in either insertion order: %s"%added.reason)
   if not added.ok:continue
   if not trunk_first:
    check(city.add_road(first,"local",true,count,false,true).ok,"first trunk can meet an existing family")
    check(city.add_road(last,"local",true,count,false,true).ok,"last trunk can meet an existing family")
   if city.roads.size()!=5:continue
   var family: Array=added.new_roads
   var first_id:int=city.roads[0 if trunk_first else 3].parcel_id
   var last_id:int=city.roads[1 if trunk_first else 4].parcel_id
   var deck_id:int=family[0].parcel_id
   var restored:Array=bytes_to_var(var_to_bytes(city.roads))
   restored.reverse()
   var net:=Network.new()
   check(net.build(restored) and net.junctions.is_empty() and city.road_joins.is_empty(),"serializable routes rebuild in reversed array order without controlled or generic joins")
   check(Junctions.analyze(restored).get("splits",[]).size()==2,"two distinct stable split/merge seams")
   check(city.road_crosswalks.is_empty() and city.road_stop_lines.is_empty(),"no controls or paint across split/merge")
   var inner:int=Profile.direction_count(family[0],1)
   for from_left:bool in [true,false]:
    for lane_index in range(count/2):
     var source:=lane_id(net,restored,first_id if from_left else last_id,-1,lane_index)
     var target:=lane_id(net,restored,last_id if from_left else first_id,1,lane_index)
     var member:Dictionary=family[0 if lane_index<inner else (1 if from_left else 2)]
     var member_lane:=lane_id(net,restored,member.parcel_id,1 if from_left or lane_index>=inner else -1,lane_index if lane_index<inner else lane_index-inner)
     check(source>=0 and target>=0 and member_lane>=0,"restored graph exposes all stable lane handles")
     if mini(source,mini(target,member_lane))<0:continue
     check(net.route(source,target)==[source,member_lane,target],"only the expected one-to-one lane path is reachable")
     check(net.lanes[source].next.size()==1 and net.lanes[member_lane].next.size()==1,"no lane swaps, U-turns or fallback links")
     check(net.sample(source,net.lanes[source].length).distance_to(net.sample(member_lane,0))<.001,"seam lane endpoints coincide in metres")
     check(net.tangent(source,net.lanes[source].length).dot(net.tangent(member_lane,0))>.9999,"lane shift starts tangent to the ordinary trunk")
   var selection:Dictionary=city.road_demolition_selection(deck_id,Vector2(70,75))
   check(selection.ok and selection.cuts.size()==1 and selection.cuts[0].id==deck_id,"demolition selection stops at the two passive seams")
   check(city.demolish_road_selection(selection).ok,"deck can be demolished independently through the player's model transaction")
   check(city.roads.size()==4 and city.roads.any(func(r):return r.parcel_id==family[1].parcel_id) and city.roads.any(func(r):return r.parcel_id==family[2].parcel_id),"outer IDs survive deck removal")
   check(net.build(city.roads),"survivors rebuild")
   var removed_lane:=lane_id(net,city.roads,first_id,-1,0)
   var surviving_lane:=lane_id(net,city.roads,first_id,-1,inner)
   check(removed_lane>=0 and net.lanes[removed_lane].next.is_empty(),"removed deck lane is a dead end, not remapped")
   check(surviving_lane>=0 and net.lanes[surviving_lane].next.size()==1,"surviving branch remains connected")

func lane_id(net,roads:Array,stable_id:int,direction:int,index:int)->int:
 for lane:Dictionary in net.lanes:
  if lane.road>=0 and roads[lane.road].parcel_id==stable_id and lane.direction==direction and lane.index==index:return lane.id
 return -1

func test_curved_seams():
 var spine:=PackedVector2Array([Vector2(30,75),Vector2(47,75),Vector2(63,77),Vector2(81,82),Vector2(96,92)])
 var heights:=PackedFloat64Array([0,0,0,10,10])
 var city=City.new(160,160)
 var made:=flyover(city,spine,heights,true,8)
 check(made.ok,"curved spine constructs the three members: "+made.reason)
 if not made.ok:return
 for i in range(3):
  for j in range(i+1,3):
   check(Construction.intersections(city.roads[i],city.roads[j]).is_empty(),"curved sibling footprints never overlap in positive area")
 var deck:Dictionary=city.roads[0]
 var full:=Profile.offset_path(deck.points,4.0)
 var left:=Profile.offset_path(deck.points,-4.0)
 var shapes:Array[PackedVector2Array]=[]
 for member:Dictionary in city.roads:shapes.append_array(Geometry.pavement_ribbons(member))
 for i in range(1,deck.points.size()):
  var must_cover:=PackedVector2Array([full[i-1],full[i],left[i],left[i-1]])
  var missing:=0.0
  for remainder in Geometry.outside_regions([must_cover],shapes):missing+=absf(Parcels.area(remainder))
  check(missing<.001,"curved cross-section has no gap or loss of its outer envelope, missing cells²: %f"%missing)
