extends "res://tests/test_road_grade_flow.gd"

const Profile=preload("res://core/road_profile.gd")
const VIEWPORT_SIZE:=Vector2i(1920,1080)
const FIRST_T:=Vector2(40,40)

func fixture(corner:bool,same_side:bool):
 var city=City.new(100,100)
 if corner:
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(40,40)]))
  city.add_road(PackedVector2Array([Vector2(40,40),Vector2(40,80)]))
  city.add_road(PackedVector2Array([Vector2(40,48),Vector2(60,48)]))
 elif same_side:
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(80,40)]))
  city.add_road(PackedVector2Array([FIRST_T,Vector2(40,60)]))
 else:
  city.add_road(PackedVector2Array([Vector2(10,40),Vector2(41,40)]))
  city.add_road(PackedVector2Array([Vector2(41,40),Vector2(80,40)]))
  city.add_road(PackedVector2Array([FIRST_T,Vector2(40,20)]))
 return city

func polygon_area(polygon:PackedVector2Array)->float:
 var twice_area:=0.0
 for i in range(1,polygon.size()-1):twice_area+=(polygon[i]-polygon[0]).cross(polygon[i+1]-polygon[0])
 return absf(twice_area)*.5

# Use positive area, with only a subpixel numerical tolerance. No bounding-box/centreline proxies.
func overlap_count(first:Array,second:Array,self_pairs:bool=false)->int:
 var count:=0
 for i in range(first.size()):
  for j in range(i if self_pairs else second.size()):
   var area:=0.0
   for p in Geometry2D.intersect_polygons(first[i],second[j]):area+=polygon_area(p)
   if area>.0001:count+=1
 return count

func polygon_hash(polygons:Array)->String:
 var shapes:Array[String]=[]
 for polygon in polygons:
  var vertices:Array[String]=[]
  for p:Vector2 in polygon:vertices.append("%.5f,%.5f"%[p.x,p.y])
  vertices.sort();shapes.append(";".join(vertices))
 shapes.sort()
 return "\n".join(shapes).sha256_text()

func inspect_markings(second:Vector2,baseline:bool):
 var city=game.city
 var renderer=game.world_renderer
 var gap_m:float=(second.x-FIRST_T.x)*4
 var label:="%.2fm"%gap_m
 var all_zebras:Array=[];var all_stops:Array=[]
 for polygon in city.road_crosswalks:all_zebras.append(renderer.project(polygon))
 for polygon in city.road_stop_lines:all_stops.append(renderer.project(polygon))
 verify(all_zebras+all_stops==renderer.stripes and not all_zebras.is_empty() and not all_stops.is_empty(),label+" actual retained stripe commands match the final asphalt-clipped paint")
 verify(renderer.line_mesh.get_surface_count()==1,label+" retained median/lane mesh exists")
 if failures:return
 var mesh:Array=renderer.line_mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=mesh[Mesh.ARRAY_VERTEX]
 var uv:PackedVector2Array=mesh[Mesh.ARRAY_TEX_UV]
 var colors:PackedColorArray=mesh[Mesh.ARRAY_COLOR]
 var zoom:float=renderer.line_material.get_shader_parameter("zoom")
 var medians:Array=[];var lanes:Array=[];var solid_medians:Array=[];var solid_lanes:Array=[]
 # Decode the actual shader's butt-ended quads, with and without its one-screen-pixel AA fringe.
 var half_width:=maxf(.6,zoom)*.5
 for i in range(0,vertices.size(),6):
  var quad:=PackedVector2Array();var solid:=PackedVector2Array()
  for j in [i,i+1,i+2,i+5]:
   var p:=Vector2(vertices[j].x,vertices[j].y);var normal:=Vector2.from_angle(uv[j].x)*uv[j].y/zoom
   quad.append(p+normal*(half_width+1));solid.append(p+normal*half_width)
  if colors[i].is_equal_approx(Color("e4bd5f")):medians.append(quad);solid_medians.append(solid)
  else:lanes.append(quad);solid_lanes.append(solid)
 verify(not medians.is_empty() and not lanes.is_empty() and is_equal_approx(zoom,game.map_zoom),label+" decoded opaque and AA quads from the actual mesh at the fixture zoom")
 var counts:={
  "zebra_zebra":overlap_count(all_zebras,all_zebras,true),
  "zebra_stop":overlap_count(all_zebras,all_stops),
  "stop_stop":overlap_count(all_stops,all_stops,true),
  "median_zebra_aa":overlap_count(medians,all_zebras),
  "lane_zebra_aa":overlap_count(lanes,all_zebras),
  "median_stop_opaque":overlap_count(solid_medians,all_stops),
  "lane_stop_opaque":overlap_count(solid_lanes,all_stops),
  "median_stop_aa":overlap_count(medians,all_stops),
  "lane_stop_aa":overlap_count(lanes,all_stops)
 }
 # This exact opaque-core test also runs against main in the scratch project.
 verify(counts.median_stop_opaque==0 and counts.lane_stop_opaque==0,label+" opaque median/shoulder strokes have zero positive-area overlap with stop bars")
 if not baseline or gap_m==16:
  verify(counts.zebra_zebra==0 and counts.median_zebra_aa==0 and counts.lane_zebra_aa==0,label+" no duplicate zebra paint or median/lane paint (including AA) on zebra")
 if not baseline and gap_m<16:
  verify(counts.zebra_stop==0 and counts.stop_stop==0,label+" merged markings do not overlap stop bars")
  var facing:=0
  for stripe in city.road_crosswalks:
   var x0:=INF;var x1:=-INF
   for p in stripe:x0=minf(x0,p.x);x1=maxf(x1,p.x)
   if x0<=FIRST_T.x+1.5 or x1>=second.x-1.5:continue
   facing+=1
   verify(absf((x0+x1)*.5-(FIRST_T.x+second.x)*.5)<.001 and absf(x1-x0-.44)<.001,label+" retained facing stripe is full depth at the exact midpoint")
  var half:=Profile.asphalt_width(city.roads[0])*.5
  var offset:=-half+.12;var expected:=0
  while offset<half-.12:offset+=.28;expected+=1
  verify(facing==expected,label+" exactly one complete crossing")
 counts["gap_m"]=gap_m
 if gap_m==16:
  counts["zebra_sha256"]=polygon_hash(city.road_crosswalks)
  counts["stop_sha256"]=polygon_hash(city.road_stop_lines)
  counts["median_sha256"]=polygon_hash(city.road_medians)
  counts["white_sha256"]=polygon_hash(city.road_lane_marks)
 print("MARKING_GEOMETRY "+JSON.stringify(counts))

func finish_fixture(second:Vector2,baseline:bool,output:String):
 var positions:Array=[]
 for node in game.city.junctions:
  if node.arms.size()==3 and node.arms.all(func(arm):return arm.lanes==2):positions.append(node.position)
 verify(game.city.junctions.size()==2 and positions.size()==2 and positions.has(FIRST_T) and positions.has(second),"two distinct two-lane T junctions at exactly %.2fm"%((second.x-FIRST_T.x)*4))
 if failures:return
 game.road_drawer.cancel();game.mode="select";game.refresh()
 game.map_zoom=4;game.origin=Vector2.ZERO;game.origin=Vector2(1050,385)-game.screen((FIRST_T+second)*.5)
 game.queue_redraw();await settle()
 verify(root.size==VIEWPORT_SIZE,"fixture uses a 1920x1080 viewport")
 inspect_markings(second,baseline)
 if not output.is_empty() and failures==0:
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  verify(image!=null and image.get_size()==VIEWPORT_SIZE and not FileAccess.file_exists(output) and image.save_png(output)==OK,"saved actual 1920x1080 framebuffer without overwriting")
  if failures==0:print("NATIVE_SPACING_CAPTURE "+output)

func run():
 var output:=""
 var baseline:="--paint-baseline" in OS.get_cmdline_user_args()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--evidence-dir="):output=arg.trim_prefix("--evidence-dir=")
 if not output.is_empty():
  for gap in [14,15]:
   if FileAccess.file_exists(output.path_join("b-junction-%dm-1920.png"%gap)):
    push_error("Refusing to overwrite capture");quit(1);return
 root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN;root.size=VIEWPORT_SIZE
 game=load("res://main.tscn").instantiate();game.city=City.new(100,100);game.paused=true;root.add_child(game);current_scene=game;await settle()
 if baseline:
  for gap in [14,15,16]:
   if game.city.simulation!=null:game.city.simulation.shutdown()
   game.city=fixture(false,true)
   var second:=FIRST_T+Vector2(gap/4.0,0)
   # Main's player policy was 16m. Seed the same authored geometry to compare paint only.
   verify(game.city.add_road(PackedVector2Array([second,second+Vector2(0,20)])).ok,"seed main paint fixture")
   await finish_fixture(second,true,"")
 else:
  var cases:=[
   ["split-record T 13.99m",false,Vector2(40+13.99/4,40),Vector2(40+13.99/4,60),false,false,0],
   ["split-record T 14m",false,Vector2(43.5,40),Vector2(43.5,60),true,false,0],
   ["split-record T 16m",false,Vector2(44,40),Vector2(44,60),true,false,0],
   ["T endpoint attachment 13.99m",false,Vector2(40+13.99/4,60),Vector2(40+13.99/4,40),false,false,0],
   ["T endpoint attachment 14m",false,Vector2(43.5,60),Vector2(43.5,40),true,false,0],
   ["corner T 13.99m",true,Vector2(40,40+13.99/4),Vector2(60,40+13.99/4),false,false,0],
   ["corner T 14m",true,Vector2(40,43.5),Vector2(60,43.5),true,false,0],
   ["grid corner 16m",true,Vector2(40,44),Vector2(60,44),true,true,0],
   ["grid corner 12m",true,Vector2(40,43),Vector2(60,43),false,true,0]
  ]
  for gap in [14,15,16]:
   var second:=FIRST_T+Vector2(gap/4.0,0)
   cases.append(["same-side shared-host T %dm"%gap,false,second,second+Vector2(0,20),true,false,gap])
  for spec in cases:
   game.road_drawer.cancel()
   if game.city.simulation!=null:game.city.simulation.shutdown()
   game.city=fixture(spec[1],spec[6]>0);game.road_grid_enabled=spec[5];game.map_zoom=1;game.origin=Vector2.ZERO;game.origin=Vector2(960,370)-game.screen(Vector2(44,43))
   await select_lanes(2)
   var before:=var_to_bytes(game.city.roads);var count:int=game.city.roads.size()
   await click(game.screen(spec[2]))
   var motion:=InputEventMouseMotion.new();motion.position=game.screen(spec[3]);motion.global_position=motion.position;root.push_input(motion,true);await settle()
   var result:Dictionary=game.road_drawer.preview()
   verify(result.ok==spec[4] and (spec[4] or "14m" in result.get("reason","")) and var_to_bytes(game.city.roads)==before,spec[0]+" actual preview uses the 14m policy without mutation")
   var colors:Dictionary=game.road_drawer.preview_colors(result.ok)
   verify(colors.outline==Color("3ddc84" if spec[4] else "ef5350"),spec[0]+" production preview chooses green/red")
   if not spec[4]:
    var line:PackedVector2Array=result.points
    # Grid ON may shift the free cap to the next width-aligned station; the real T
    # contact and its chainage on the host must nevertheless be exact.
    var end_ok:bool=line.size()>=2 and line[-1].distance_to(spec[3])<.005
    if spec[5] and line.size()>=2:
     end_ok=absf(line[-1].y-spec[3].y)<.005 and absf(line[-1].x-spec[3].x)<=.505
    verify(root.size==VIEWPORT_SIZE and line.size()>=2 and line[0].distance_to(spec[2])<.005 and end_ok,spec[0]+" rejected preview retains the resolved T contact and expected viewport: "+str(line))
   await click(game.screen(spec[3]));await settle()
   verify((game.city.roads.size()==count+1 and var_to_bytes(game.city.roads.slice(0,count))==before) if spec[4] else (var_to_bytes(game.city.roads)==before and not game.road_drawer.last_result.ok),spec[0]+" actual confirmation agrees and preserves original roads")
   if spec[6]>0:
    var capture:=output.path_join("b-junction-%dm-1920.png"%spec[6]) if not output.is_empty() and spec[6]<16 else ""
    await finish_fixture(spec[2],false,capture)
 print("MARKING_FIXTURE renderer=%s driver=%s viewport=%s"%[RenderingServer.get_current_rendering_method(),RenderingServer.get_current_rendering_driver_name(),root.size])
 game.queue_free();await process_frame
 print("RESULT %d/%d native junction spacing and paint checks passed"%[checks-failures,checks]);quit(1 if failures else 0)
