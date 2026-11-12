extends SceneTree
const City=preload("res://core/city_model.gd")
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func verify(value: bool,label: String):
 checks+=1
 if value:print("PASS "+label)
 else:failures+=1;push_error("FAIL "+label)
func town(gap: float=8.0,second: bool=true,angle: float=0.0,reverse: bool=false,half: bool=false):
 var city:=City.new(120,120);city.population_enabled=false
 var along:=Vector2.RIGHT.rotated(angle);var outward:=Vector2.DOWN.rotated(angle)
 var start:=Vector2(25,40)
 city.add_road(PackedVector2Array([start,start+along*40]))
 if second:
  var other:=PackedVector2Array([start+outward*(gap+2),start+outward*(gap+2)+along*(4 if half else 40)])
  if reverse:other.reverse()
  city.add_road(other)
 return city
func front_frame(city) -> Dictionary:
 return city.zoning_grid.frames.values().filter(func(f):return f.road_index==0 and f.side==1)[0]
func run():
 for angle in [0.0,PI/6]:
  var single=town(8,false,angle)
  verify(single.config.zoning_depth==4,"default roadside depth is four cells")
  verify(single.zoning_grid.parcels.values().all(func(p):return p.v>=0 and p.v<4),"no road side generates rows four through seven")
  single.config.zoning_depth=8;single._update_zoning_for_road({})
  verify(single.zoning_grid.parcels.values().all(func(p):return p.v<4),"legacy prototype config cannot restore eight-deep strips")
  var f:=front_frame(single)
  verify(not single.parcel_placement_error(f,0,0,8).is_empty(),"one road cannot supply a new 8x8 lot")
  for reverse in [false,true]:
   var city=town(8,true,angle,reverse);f=front_frame(city)
   verify(city.parcel_placement_error(f,0,0,8).is_empty(),"opposed aligned four-deep strips support 8x8 reverse="+str(reverse))
   var shape: PackedVector2Array=city.Parcels.polygon(f,0,0,8)
   verify(city.paint_zones(shape,"residential").changed==64,"eight-wide shared lot paints 32 cells from each road")
   verify(city.zoned_lot_matches(f,0,0,8,"residential"),"uniform zoning resolves real cell IDs across road frames")
   var b: Dictionary=city.advance_development(2)[0]
   for stage in range(2,6):
    b.score=100;var result: Dictionary=city.upgrade_chain(b.id)
    verify(result.ok and b.level==stage and b.size==(8 if stage==5 else 4),"two-road growth expands to 8x8 only at stage five")
   verify(b.id==1 and city.buildings.size()==1,"two-road expansion retains one building and original ID")
 for gap in [7.0,8.25,9.0]:
  var city=town(gap);var f:=front_frame(city)
  verify(not city.parcel_placement_error(f,0,0,8).is_empty(),"non-eight-cell road spacing cannot silently fill a gap: "+str(gap))
 var partial=town(8,true,0,false,true)
 verify(not partial.parcel_placement_error(front_frame(partial),0,0,8).is_empty(),"a four-wide rear strip cannot support an eight-wide lot")
 var shifted=town(8,false)
 shifted.add_road(PackedVector2Array([Vector2(25.5,50),Vector2(65.5,50)]))
 verify(not shifted.parcel_placement_error(front_frame(shifted),0,0,8).is_empty(),"half-cell phase mismatch never counts as an aligned shared lot")
 var skewed=town(8,false)
 skewed.add_road(PackedVector2Array([Vector2(25,50),Vector2(65,50)+Vector2(0,40*tan(deg_to_rad(1)))]))
 verify(not skewed.parcel_placement_error(front_frame(skewed),0,0,8).is_empty(),"one-degree skew cannot bend square cells to force an 8x8")
 var mixed=town();var frame:=front_frame(mixed);mixed.paint_zones(mixed.Parcels.polygon(frame,0,0,8),"residential")
 var rear: Dictionary=mixed.zoning_grid.parcel_at(frame.origin+frame.along*.5+frame.outward*7.5)
 mixed.paint_zones(rear.polygon,"");mixed.paint_zones(rear.polygon,"industrial")
 verify(not mixed.zoned_lot_matches(frame,0,0,8,"residential"),"one rear-road cell of another use blocks 8x8 growth")
 var single=town(8,false);frame=front_frame(single);single.paint_zones(single.Parcels.polygon(frame,0,0,4),"residential")
 var small: Dictionary=single.advance_development(2)[0]
 small.level=4;small.score=100;single.upgrade_chain(small.id)
 verify(small.size==4 and small.level==5,"missing opposite road keeps existing 4x4 at final stage")
 var direct=town(8,false)
 verify(not direct.place_catalog_building("large-8x8-a",25,41).ok,"authored placement cannot bypass two-road 8x8 geometry")
 direct=town()
 verify(direct.place_catalog_building("large-8x8-a",25,41).ok,"authored final-stage 8x8 accepts real opposed strips")
 var legacy=town(8,false)
 var saved_frame:=front_frame(legacy).duplicate(true)
 var saved: Dictionary={"id":99,"x":saved_frame.origin.x,"y":saved_frame.origin.y,"frame":saved_frame,"u":0,"v":0,"size":8,"level":5,"zone":"residential","score":37.0,"asset_id":"large-8x8-a"}
 legacy.buildings.append(saved);var before:=var_to_str(saved);var shape:=legacy.footprint(saved)
 legacy._update_zoning_for_road({})
 verify(legacy.buildings.size()==1 and var_to_str(saved)==before and legacy.footprint(saved)==shape,"rebuilding four-deep zoning preserves stored 8x8 footprint ID stage facade and score")
 # Simulate a restored old in-memory city with cached eight-deep parcels.
 for u in range(8):
  for v in range(4,8):legacy.zoning_grid.add_parcel(saved_frame,u,v)
 legacy.config.zoning_depth=8
 root.size=Vector2i(1920,1080)
 var game=load("res://main.tscn").instantiate();game.city=legacy;game.paused=true;root.add_child(game);await process_frame
 verify(game.city.zoning_grid.parcels.values().all(func(p):return p.v<4) and game.city.footprint(saved)==shape and saved.id==99 and saved.level==5 and saved.size==8 and saved.asset_id=="large-8x8-a" and saved.score==37,"opening cached legacy city rebuilds four-deep tiles without changing existing 8x8 building data")
 game.queue_free();await process_frame
 print("RESULT %d/%d four-cell zoning checks passed" % [checks-failures,checks]);quit(1 if failures else 0)
