extends Node2D
const Renderer=preload("res://core/road_renderer.gd")
var city
func project(p:Vector2)->Vector2:return Vector2(570,550)+(p-Vector2(50,50))*18
func _draw():
	draw_rect(Rect2(0,0,1140,1100),Color("748b6e"))
	if city!=null:Renderer.draw_roads(self,city.roads,project,1.8,city.road_network.junctions,city.road_network.ports)
