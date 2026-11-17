extends RefCounted
## Authoritative worker-only neighbor planning; no Nodes, money, render or per-frame queries.
const Neighbor=preload("res://core/neighbor_commuting.gd")
const Regional=preload("res://core/regional_exchange.gd")
var planner=Neighbor.new()
var last_plan:Dictionary={}
var last_apply:Dictionary={}
var _stamp:=-1
func advance(city):
 if not city.population._labor_enabled:return
 var stats:Dictionary=city.population.stats()
 var exchange:Dictionary=city.regional_exchange()
 planner.refresh_day(city.clock.day(),int(stats.population),exchange)
 var commuters:Dictionary=city.population.core.GetNeighborCommuters()
 var stamp:int=hash([city.clock.day(),stats,city._commuting_generation,commuters])
 if stamp==_stamp:return
 var connected:bool=exchange.neighbors.any(func(n):return n.channels.road.connected)
 if not connected:
  last_apply=city.population.apply_labor_commuting_plan([],[])
  last_plan={"day":city.clock.day(),"inbound":0,"outbound":0,"flows":[]}
 else:
  var context:Dictionary=city.population.labor_commuting_context()
  var routes:Array=_proven_routes(city,exchange,context)
  last_plan=planner.plan(exchange,context,routes)
  last_apply=city.population.apply_labor_commuting_plan(last_plan.inbound_reservations,last_plan.outbound_assignments)
 _stamp=hash([city.clock.day(),city.population.stats(),city._commuting_generation,city.population.core.GetNeighborCommuters()])
func status()->Dictionary:
 return {"day":int(last_plan.get("day",-1)),"inbound":int(last_apply.get("inbound",0)),"outbound":int(last_apply.get("outbound",0)),"rejected_inbound":int(last_apply.get("rejected_inbound",0)),"rejected_outbound":int(last_apply.get("rejected_outbound",0)),"neighbor_count":planner.snapshot().neighbors.size()}
func _proven_routes(city,exchange:Dictionary,context:Dictionary)->Array:
 var routes:Array=[]
 var homes:Dictionary={}
 for row:Dictionary in context.unemployed+context.outbound:
  if int(row.home_id)>=0:homes[row.home_id]=true
 for road:Dictionary in city.roads:
  var points:PackedVector2Array=road.points
  for pair:Array in [[0,1],[points.size()-1,points.size()-2]]:
   var point:Vector2=points[pair[0]]
   var cursor:int=pair[1];var step:int=1 if pair[0]==0 else -1
   while cursor>=0 and cursor<points.size() and points[cursor].is_equal_approx(point):cursor+=step
   if cursor<0 or cursor>=points.size():continue
   var edge:String=Regional.endpoint_edge(point,points[cursor],city.width,city.height)
   if edge.is_empty():continue
   var distances:Dictionary=city.population.core.GetLaborBoundaryDistances(road.parcel_id,point)
   for town:Dictionary in exchange.neighbors:
    if town.edge!=edge or not town.channels.road.connected:continue
    for workplace:Dictionary in context.workplaces:
     var id:Variant=workplace.workplace_id
     if distances.has(id):routes.append(_route(town.id,id,"inbound",distances[id],point,road.parcel_id,pair[0]))
    for id:Variant in homes:
     if distances.has(id):routes.append(_route(town.id,id,"outbound",distances[id],point,road.parcel_id,pair[0]))
 return routes
func _route(neighbor_id:Variant,id:Variant,direction:String,distance:float,boundary:Vector2,road_id:int,end:int)->Dictionary:
 return {"neighbor_id":str(neighbor_id),"local_id":id,"direction":direction,"mode":"road","reachable":true,"distance_m":distance,"route_id":"%s/%s/%s/%s/%s"%[neighbor_id,road_id,end,direction,id],"boundary":boundary,"road_id":road_id}
