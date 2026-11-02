extends RefCounted
## Display-only. Never modifies power, consumers, meters or funds.
static func markers(state: Dictionary, seconds: float, speed: float = 64.0, interval: float = 1.5) -> Array:
 var output := []
 var routes: Array=state.get("routes",[])
 if routes.is_empty() or speed<=0 or interval<=0: return output
 var max_life := 0.0
 for route in routes: max_life=maxf(max_life,route.length/speed)
 var last := floori(seconds/interval)
 var first := maxi(0,floori((seconds-max_life)/interval))
 for emission in range(first,last+1):
  var route: Dictionary=routes[emission%routes.size()]
  var age := seconds-emission*interval
  var life: float=route.length/speed
  if age<0 or age>=life: continue
  output.append({"position":preload("res://core/power_grid.gd").sample(route.points,age*speed),"alpha":minf(1,(life-age)/.25)})
 return output
