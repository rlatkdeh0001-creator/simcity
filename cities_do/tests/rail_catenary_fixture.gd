extends Node2D
## Focused normal-viewport renderer fixture; real model edits, no simulation ticks.
const Model=preload("res://core/city_model.gd")
var city=Model.new(120,120,42)
var tile:=Vector2(14,7)
var map_zoom:=1.5
var origin:=Vector2(850,30)
var transit_view
var world_renderer
var traffic
var building_views
var public_controller
var mode:="select"
const ZONE_COLORS:Dictionary={}
func _ready():
 building_views=preload("res://core/building_views.gd").new();add_child(building_views)
 public_controller=preload("res://core/public_placement_controller.gd").new();public_controller.view=self;add_child(public_controller)
 traffic=preload("res://core/traffic_controller.gd").new();add_child(traffic)
 transit_view=preload("res://core/transit_view.gd").new();add_child(transit_view);transit_view.setup(self)
 world_renderer=preload("res://core/cached_world_renderer.gd").new();add_child(world_renderer);world_renderer.setup(self)
func show_zoning_tiles()->bool:return false
func building_draw_order()->Array:return city.public_facilities.lots.duplicate()
func screen(point:Vector2)->Vector2:return origin+transit_view.project_point(point)*map_zoom
func building_depth(record:Dictionary)->float:
 var depth:float=-INF
 for point:Vector2 in city.footprint(record):depth=maxf(depth,point.x+point.y)
 return depth
func stage():
 # Actual construction APIs, original station v2 and original train v3 sprites.
 city=Model.new(120,120,42)
 city.population_enabled=false;city.happiness_enabled=false
 city.add_road(PackedVector2Array([Vector2(5,40),Vector2(80,40)]),"local",true,4)
 var placed:Dictionary=city.public_facilities.place("train-station-01",Vector2(30,33),0,true)
 assert(placed.ok,str(placed))
 var ends:PackedVector2Array=city.public_facilities.lots[0].internal_points
 var left:Vector2=ends[0] if ends[0].x<ends[1].x else ends[1]
 var right:Vector2=ends[1] if ends[0].x<ends[1].x else ends[0]
 assert(city.add_transit_route(PackedVector2Array([Vector2(10,left.y),left])).ok)
 var path:=PackedVector2Array([right,Vector2(52,right.y)])
 for i in range(1,33):path.append(Vector2(52,right.y+12)+Vector2.from_angle(-PI/2+PI*.5*i/32)*12)
 path.append(Vector2(64,58))
 assert(city.add_transit_route(path).ok)
 assert(city.add_road(PackedVector2Array([Vector2(55,51),Vector2(80,51)]),"local",true,2).ok)
 traffic.network=traffic.Network.new();assert(traffic.network.build(city.roads))
 traffic.simulation=traffic.Simulation.new(traffic.network);traffic.running=true
 var engine:Dictionary=traffic.catalog.filter(func(a):return a.id=="fire-engine-01")[0]
 for lane:Dictionary in traffic.network.lanes:
  if lane.road==1 and lane.direction==1:
   assert(not traffic.simulation.spawn(engine,[lane.id],36,false).is_empty());break
 city.transit_state.visible=[
  {"id":"stage-lead","asset_id":"train-loco-01","position":Vector2(132,(left.y-.5)*4),"heading":Vector2.RIGHT,"height_m":0.0,"kind":"rail","length_m":10.0,"width_m":3.0},
  {"id":"stage-coach1","asset_id":"train-passenger-01","position":Vector2(121.5,(left.y-.5)*4),"heading":Vector2.RIGHT,"height_m":0.0,"kind":"rail","length_m":11.0,"width_m":3.0},
  {"id":"stage-coach2","asset_id":"train-passenger-01","position":Vector2(110.5,(left.y-.5)*4),"heading":Vector2.RIGHT,"height_m":0.0,"kind":"rail","length_m":11.0,"width_m":3.0}]
 map_zoom=1.6;origin=Vector2(800,-380)
 world_renderer.synchronize()
