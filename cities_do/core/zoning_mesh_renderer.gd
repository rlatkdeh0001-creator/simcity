extends Node2D
## Static per-frame chunks; the per-cell colour-table pixel changes independently.
const PALETTE_WIDTH:=256
const MAX_CHUNK_CELLS:=1000
const GAP_WIDTH:=.7
var view
var blocks:Array[Dictionary]=[]
var cell_slots:Dictionary={}
var cell_ids:Array=[]
var palette_image:Image
var palette_texture:ImageTexture
var palette_material:ShaderMaterial
var geometry_generation:=0
var palette_generation:=0
var grid_visible:=true
func setup(owner_view):
 view=owner_view
 palette_material=ShaderMaterial.new();var shader:=Shader.new()
 shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform sampler2D colour_table : filter_nearest, repeat_disable;
uniform int palette_width = 256;
uniform vec4 gap_colour = vec4(0.87,0.94,0.8,0.5);
void fragment(){
 int slot=int(round(UV.x));
 vec4 cell=texelFetch(colour_table,ivec2(slot % palette_width,slot / palette_width),0);
 if(UV.y>0.5){
  float alpha=gap_colour.a+cell.a*(1.0-gap_colour.a);
  cell=vec4((gap_colour.rgb*gap_colour.a+cell.rgb*cell.a*(1.0-gap_colour.a))/alpha,alpha);
 }
 COLOR=cell;
}
"""
 palette_material.shader=shader
func iso(p:Vector2)->Vector2:return Vector2((p.x-p.y)*view.tile.x,(p.x+p.y)*view.tile.y)
func cell_colour(id:String)->Color:
 var designation:String=view.city.zone_designations.get(id,"")
 var colour:Color=view.ZONE_COLORS.get(designation,Color(.82,.89,.72))
 colour.a=.22 if designation.is_empty() else .5
 return colour
func palette_pixel(id:String)->Color:
 var slot:int=cell_slots[id];return palette_image.get_pixel(slot%PALETTE_WIDTH,slot/PALETTE_WIDTH)
func rebuild():
 for child in get_children():child.hide();child.queue_free()
 blocks.clear();cell_slots.clear();cell_ids=view.city.zoning_grid.parcels.keys();cell_ids.sort()
 palette_image=Image.create(PALETTE_WIDTH,maxi(1,ceili(float(cell_ids.size())/PALETTE_WIDTH)),false,Image.FORMAT_RGBAF);palette_image.fill(Color.TRANSPARENT)
 var groups:Dictionary={}
 for i in range(cell_ids.size()):
  var id:String=cell_ids[i];cell_slots[id]=i;palette_image.set_pixel(i%PALETTE_WIDTH,i/PALETTE_WIDTH,cell_colour(id))
  var frame:String=view.city.zoning_grid.parcels[id].frame.id
  if not groups.has(frame):groups[frame]=[]
  groups[frame].append(id)
 palette_texture=ImageTexture.create_from_image(palette_image);palette_material.set_shader_parameter("colour_table",palette_texture);palette_material.set_shader_parameter("palette_width",PALETTE_WIDTH)
 for group in groups.values():
  for first in range(0,group.size(),MAX_CHUNK_CELLS):build_block(group.slice(first,mini(first+MAX_CHUNK_CELLS,group.size())))
 geometry_generation+=1;palette_generation+=1;set_grid_visible(grid_visible,true)
func buffer()->Dictionary:return {"vertices":[],"uv":[],"indices":[]}
func quad(data:Dictionary,points:Array,slot:int,gap:bool):
 var first:int=data.vertices.size()
 for p:Vector2 in points:data.vertices.append(Vector3(p.x,p.y,0));data.uv.append(Vector2(slot,1 if gap else 0))
 data.indices.append_array([first,first+1,first+2,first,first+2,first+3])
func array_mesh(data:Dictionary)->ArrayMesh:
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array(data.vertices);arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array(data.uv);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(data.indices)
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func build_block(ids:Array):
 var origin:Vector2=iso(view.city.zoning_grid.parcels[ids[0]].frame.origin)
 var detailed:=buffer();var plain:=buffer()
 for id in ids:
  var parcel:Dictionary=view.city.zoning_grid.parcels[id];var outer:Array=[]
  for p in parcel.polygon:outer.append(iso(p)-origin)
  var u:Vector2=outer[1]-outer[0];var v:Vector2=outer[3]-outer[0];var area:float=absf(u.cross(v))
  var fu:float=minf(.2,GAP_WIDTH*.5*v.length()/area);var fv:float=minf(.2,GAP_WIDTH*.5*u.length()/area)
  var inner:Array=[outer[0]+u*fu+v*fv,outer[1]-u*fu+v*fv,outer[2]-u*fu-v*fv,outer[3]+u*fu-v*fv]
  var slot:int=cell_slots[id]
  for i in range(4):quad(detailed,[outer[i],outer[(i+1)%4],inner[(i+1)%4],inner[i]],slot,true)
  quad(detailed,inner,slot,false);quad(plain,outer,slot,false)
 var node:=MeshInstance2D.new();node.name="ZoningBlock%d"%blocks.size();node.position=origin;node.material=palette_material;add_child(node)
 blocks.append({"node":node,"detail":array_mesh(detailed),"plain":array_mesh(plain),"cells":ids.duplicate()})
func update_palette():
 var changed:=false
 for id in cell_ids:
  var colour:=cell_colour(id)
  if palette_pixel(id).is_equal_approx(colour):continue
  var slot:int=cell_slots[id];palette_image.set_pixel(slot%PALETTE_WIDTH,slot/PALETTE_WIDTH,colour);changed=true
 if changed:palette_texture.update(palette_image);palette_generation+=1
func set_grid_visible(value:bool,force:bool=false):
 if value==grid_visible and not force:return
 grid_visible=value
 for block in blocks:block.node.mesh=block.detail if value else block.plain
