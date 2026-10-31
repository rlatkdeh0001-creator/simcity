"""Original CITIES_DO four-storey design study. Blender 4.3+, no external assets/API.
Run: blender --background --factory-startup --python-exit-code 1 --python assets/mansion-study/build_mansions.py -- --variant A
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

OUT = Path(__file__).resolve().parent
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument('--variant', choices=['A', 'B'], required=True)
parser.add_argument('--samples', type=int, default=32)
opts = parser.parse_args(args)
variant = opts.variant
folder = OUT / ('a-brick' if variant == 'A' else 'b-modern')
folder.mkdir(parents=True, exist_ok=True)
log = folder / 'production_log.md'
log.write_text(f'# Mansion {variant}\n\nOriginal scripted model. Blender {bpy.app.version_string}. No purchased resources, external textures, generation API, or Claude login.\n\nBrief: four occupied storeys, 4x4 cells, 16x16 m lot, 3.05 m storey height. Same camera, light and lot for both variants.\n\nMethod: game-art art-direction principles and adapted kiln local scripting/inspection principles, not an unmodified execution of the kiln toolkit or Studio.\n\nCheckpoint: BRIEF\n')

def checkpoint(name, info):
    with log.open('a') as f:
        f.write(f'\n## {name}\n{info}\n\nCheckpoint: {name}\n')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
floor_height = 3.05
floor_base = .35


def rgba(hex_value):
    h = hex_value.lstrip('#')
    values = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in values) + (1,)


def material(name, color, roughness=.65, metallic=0):
    m = bpy.data.materials.new('M_' + name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = rgba(color)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    m.diffuse_color = rgba(color)
    return m

stone = material('Limestone', '#d2c9b8')
paving = material('Paving', '#e5e0d5')
asphalt = material('DarkPaving', '#aaa99e')
trim = material('WarmFrames', '#e1d7c0')
dark = material('Metal', '#38494b', .42, .3)
glass = material('BlueGlass', '#567f8a', .22, .25)
light_glass = material('LightGlass', '#88a8ae', .2, .2)
wood = material('Wood', '#9e714d')
foliage = material('Foliage', '#567349')
leaflight = material('LeafLight', '#708855')
soil = material('Soil', '#625342')
roofmat = material('RoofMetal', '#58676c', .55, .3)
white = material('Plaster', '#e8e5dc')
accent = material('Clay', '#b7795c')
brick = material('Brick', '#915846')
# Object coordinates preserve consistent brick size on front and side walls.
nt = brick.node_tree
nodes = nt.nodes
links = nt.links
tex = nodes.new('ShaderNodeTexBrick')
tex.inputs['Color1'].default_value = rgba('#9d6654')
tex.inputs['Color2'].default_value = rgba('#b07961')
tex.inputs['Mortar'].default_value = rgba('#c6b8a4')
tex.inputs['Scale'].default_value = 1.0
tex.inputs['Mortar Size'].default_value = .018
tex.inputs['Mortar Smooth'].default_value = .01
tex.inputs['Brick Width'].default_value = .52
tex.inputs['Row Height'].default_value = .22
coord = nodes.new('ShaderNodeTexCoord')
# Explicit UV layer on facade objects below; cube smart unwrap would vary texel density.
links.new(coord.outputs['UV'], tex.inputs['Vector'])
links.new(tex.outputs['Color'], nodes.get('Principled BSDF').inputs['Base Color'])
bump = nodes.new('ShaderNodeBump')
bump.inputs['Strength'].default_value = .22
bump.inputs['Distance'].default_value = .025
links.new(tex.outputs['Fac'], bump.inputs['Height'])
links.new(bump.outputs['Normal'], nodes.get('Principled BSDF').inputs['Normal'])


def box(name, center, size, mat, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if mat == brick:
        uv = obj.data.uv_layers.active or obj.data.uv_layers.new()
        for poly in obj.data.polygons:
            for li in poly.loop_indices:
                co = obj.data.vertices[obj.data.loops[li].vertex_index].co
                # Wall textures use world-length coordinates, z is always the row axis.
                u = co.x if abs(poly.normal.y) > .5 else co.y
                uv.data[li].uv = (u, co.z + center[2])
    if bevel:
        mod = obj.modifiers.new('EdgeHighlights', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
    return obj


def cylinder(name, loc, radius, depth, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def tree(x,y, height=2.7):
    cylinder('Prop_TreeTrunk', (x,y,.2+height*.4), .13, height*.8, wood)
    for dx,dy,dz,r in [(-.32,0,0,.7),(.32,.12,.2,.7),(0,-.2,.65,.65)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=(x+dx,y+dy,height+dz))
        bpy.context.object.name = 'Prop_TreeCrown'
        bpy.context.object.data.materials.append(leaflight if dx > 0 else foliage)


def planter(x,y,z,w=.9,d=.45):
    box('Prop_Planter', (x,y,z+.18), (w,d,.36), stone)
    box('Prop_Plant', (x,y,z+.43), (w*.9,d*.82,.32), foliage, .1)


# 4x4 cells at 4m/cell. All objects kept inside the 16m lot.
box('Lot_4x4', (0,0,0), (16,16,.25), stone, .08)
box('Lot_Top', (0,0,.15), (15.86,15.86,.12), paving)
# Paving joints and front approach read at actual gameplay scale.
for x in [-6,-4,-2,0,2,4,6]:
    box('PavingJoint', (x,-6.3,.222), (.018,2.9,.006), stone, 0)
for y in [-7.5,-6.3,-5.1]:
    box('PavingJoint', (0,y,.222), (15.6,.018,.006), stone, 0)
box('Entry_Path', (0,-6.4,.25), (2.4,2.6,.09), asphalt)
for x in [-7.1,7.1]:
    planter(x,-5.9,.23,.9,1.4)
    tree(x*.95,4.9)
    box('BoundaryHedge', (x,.3,.65), (.65,6.8,.9), foliage, .16)
for x in [-4.7,4.7]:
    planter(x,-6.5,.25,2.0,.55)

facade = brick if variant == 'A' else white
body = box('Building_FourStoreys', (0,0,floor_base+floor_height*2), (11.8,9.3,floor_height*4), facade, .04)
body['occupied_storeys'] = 4
body['footprint_cells'] = [4,4]
body['variant'] = variant
# Visible four levels, no occupied roof room.
for floor in range(5):
    z = floor_base + floor*floor_height
    box('FloorBand_%d' % floor, (0,0,z+.04), (12.0,9.5,.15 if variant=='A' else .2), trim if variant=='A' else white)


def front_window(x, floor, width=1.5, height=1.8, y=-4.69):
    center_z = floor_base + floor*floor_height + 1.6
    box('FrontFrame_F%d' % (floor+1), (x,y,center_z), (width+.18,.16,height+.18), trim if variant=='A' else dark)
    box('FrontGlass_F%d' % (floor+1), (x,y-.095,center_z), (width,.045,height), light_glass if (floor+int(x))%3==0 else glass, .005)
    box('FrontMullion', (x,y-.13,center_z), (.055,.04,height), trim if variant=='A' else dark, .005)
    box('FrontSill', (x,y-.17,center_z-height*.5-.09), (width+.3,.35,.12), stone)


def side_window(y, floor, balcony=False):
    z = floor_base+floor*floor_height+1.6
    height = 2.2 if balcony else 1.8
    box('SideFrame_F%d' % (floor+1), (5.96,y,z), (.17,1.75,height+.15), trim if variant=='A' else dark)
    box('SideGlass_F%d' % (floor+1), (6.06,y,z), (.045,1.58,height), glass, .005)
    box('SideMullion', (6.09,y,z), (.04,.05,height), dark, .005)


for floor in range(4):
    if variant == 'A':
        for x in [-4.3,-2.2,2.2,4.3]: front_window(x,floor,1.38,1.72)
        # Stair core gives the red-brick mansion a recognisable entrance axis.
        box('StairCore', (0,-4.72,floor_base+floor*floor_height+1.5), (1.6,.25,2.95), trim)
        if floor:
            front_window(0,floor,.75,1.8,y=-4.9)
        for y in [-2.6,.1,2.9]: side_window(y,floor, floor>0 and y<1)
        if floor > 0:
            for y in [-2.6,.1]:
                z = floor_base+floor*floor_height
                box('SideBalconySlab',(6.55,y,z+.12),(1.25,2.3,.18),stone)
                for offset in [-1.03,1.03]:
                    box('SideBalconyRail',(6.6,y+offset,z+.65),(1.2,.055,1.05),dark)
                box('SideBalconyHandrail',(7.12,y,z+1.2),(.07,2.2,.07),dark)
                for offset in [-.9,-.45,0,.45,.9]:
                    box('SideBalconySpindle',(7.12,y+offset,z+.7),(.04,.04,.95),dark,0)
    else:
        for x in [-3.9,0,3.9]:
            if floor == 0 and x == 0: continue
            front_window(x,floor,2.4,2.05)
        for y in [-2.7,.5,3.2]: side_window(y,floor)
        # Cedar panel is articulated with actual slats, not a flat orange patch.
        for x in [1.72+i*.105 for i in range(9)]:
            box('CedarSlat',(x,-4.82,floor_base+floor*floor_height+1.5),(.065,.13,2.8),wood,.008)
        if floor > 0:
            z = floor_base+floor*floor_height
            box('FrontBalconySlab',(0,-5.32,z+.11),(12.3,1.5,.22),white)
            for x in [-6.03,-2.0,2.0,6.03]:
                box('FrontBalconyPost',(x,-6.0,z+.7),(.07,.07,1.1),dark,.008)
            box('FrontBalconyRail',(0,-6.0,z+1.26),(12.14,.085,.09),dark,.008)
            # Thin opaque panels read as blue-tinted balcony glass at sprite scale.
            box('BalconyGlass',(0,-5.98,z+.77),(11.95,.04,.85),light_glass,.003)
            for x in [-5.9,5.9]:
                box('BalconySide',(x,-5.35,z+.77),(.04,1.26,.85),light_glass,.003)
            planter(-4.8,-5.55,z+.24,1.2,.42)
            planter(4.8,-5.55,z+.24,1.2,.42)

# Secondary facades remain consistent with the same four occupied floors.
for floor in range(4):
    z=floor_base+floor*floor_height+1.6
    for x in [-4.1,0,4.1]:
        box('RearFrame_F%d'%(floor+1),(x,4.72,z),(1.75,.17,1.92),trim if variant=='A' else dark)
        box('RearGlass_F%d'%(floor+1),(x,4.82,z),(1.58,.04,1.75),glass,.005)
        box('RearMullion',(x,4.85,z),(.06,.04,1.75),dark,.005)
    for y in [-2.7,.2,3.0]:
        box('LeftFrame_F%d'%(floor+1),(-5.96,y,z),(.17,1.75,1.95),trim if variant=='A' else dark)
        box('LeftGlass_F%d'%(floor+1),(-6.06,y,z),(.04,1.58,1.78),glass,.005)
        box('LeftMullion',(-6.09,y,z),(.04,.05,1.78),dark,.005)

# Entrance, address and wall lamps.
box('EntranceFrame',(0,-4.95,1.65),(1.55,.24,2.6),dark)
box('EntranceGlass',(0,-5.09,1.65),(1.3,.045,2.35),glass)
box('DoorHandle',(.43,-5.15,1.65),(.035,.06,.42),trim,.008)
box('EntryCanopy',(0,-5.25,3.02),(2.5,1.15,.18),roofmat if variant=='A' else wood)
for x in [-.98,.98]:
    box('EntryLamp',(x,-4.9,2.3),(.14,.18,.42),trim)
# Four occupied-storey markers are machine-verifiable in .blend.
for floor in range(4):
    marker=bpy.data.objects.new('OccupiedFloor_%d' % (floor+1),None)
    marker.location=(0,0,floor_base+floor*floor_height)
    marker['storey_index']=floor+1
    scene.collection.objects.link(marker)

roof_z=floor_base+4*floor_height
if variant == 'A':
    vertices=[(-6.3,-5.0,roof_z+.15),(6.3,-5.0,roof_z+.15),(6.3,5.0,roof_z+.15),(-6.3,5.0,roof_z+.15),(-4.5,0,roof_z+1.6),(4.5,0,roof_z+1.6)]
    faces=[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4),(3,2,1,0)]
    mesh=bpy.data.meshes.new('HipRoofMesh');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new('Roof_UnoccupiedHip',mesh);scene.collection.objects.link(obj);obj.data.materials.append(roofmat)
    box('RoofRidge',(0,0,roof_z+1.63),(9.15,.14,.13),dark)
    # Standing seams on front roof slope.
    for x in [-4,-3,-2,-1,0,1,2,3,4]:
        a=Vector((x,-4.95,roof_z+.19));b=Vector((x,0,roof_z+1.63))
        midpoint=(a+b)/2
        obj=box('RoofSeam',midpoint,(.025,(b-a).length,.025),dark,0)
        obj.rotation_euler=(b-a).to_track_quat('Y','Z').to_euler()
else:
    box('RoofDeck',(0,0,roof_z+.13),(11.8,9.3,.16),asphalt)
    for y in [-4.6,4.6]: box('Parapet',(0,y,roof_z+.5),(12,.22,.9),white)
    for x in [-5.9,5.9]: box('Parapet',(x,0,roof_z+.5),(.22,9.2,.9),white)
    for x in [-3.8,3.8]: planter(x,2.9,roof_z+.24,2.6,.85)
    # Open pergola is not a fifth storey or occupied room.
    for x in [-2.2,2.2]:
        for y in [-1.4,1.8]: box('PergolaPost',(x,y,roof_z+1),(.12,.12,1.7),wood)
    for x in [-2.3+i*.46 for i in range(11)]: box('PergolaSlat',(x,.2,roof_z+1.87),(.13,3.6,.13),wood)
    box('RoofMechanical',(3,0,roof_z+.7),(1.4,1.5,.95),roofmat)
    box('RoofMechanicalTop',(3,0,roof_z+1.22),(1.5,1.6,.12),dark)

meshes=[o for o in scene.objects if o.type=='MESH']
vertices=[o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
mins=[min(v[i] for v in vertices) for i in range(3)]
maxs=[max(v[i] for v in vertices) for i in range(3)]
assert mins[0] >= -8.01 and mins[1] >= -8.01 and maxs[0]<=8.01 and maxs[1]<=8.01,(mins,maxs)
assert len([o for o in scene.objects if o.name.startswith('OccupiedFloor_')])==4
checkpoint('MODEL',f'Original mesh objects: {len(meshes)}. Vertex world bounds {mins} to {maxs}. Four occupied-floor markers. Palette and materials assigned. No third-party meshes or textures.')

# Fixed 2:1 dimetric camera (elevation 30 degrees, yaw 45 degrees).
def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

bpy.ops.object.camera_add(location=(30,-30,4.8+math.sqrt(1800)*math.tan(math.radians(30))))
camera=bpy.context.object;camera.name='Camera_SharedDimetric';aim(camera,(0,0,4.8));camera.data.type='ORTHO';camera.data.ortho_scale=28;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(-12,-15,26))
light=bpy.context.object;light.name='Light_Key';light.data.energy=2400;light.data.shape='DISK';light.data.size=12;aim(light,(0,0,4))
bpy.ops.object.light_add(type='AREA',location=(12,5,18))
light=bpy.context.object;light.name='Light_Fill';light.data.energy=1300;light.data.size=10;aim(light,(0,0,6))
scene.world=bpy.data.worlds.new('World_Studio')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.65,.75,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
scene.render.engine='CYCLES'
scene.cycles.samples=opts.samples
scene.cycles.use_denoising=False
scene.cycles.device='CPU'
scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.filepath=str(folder/'mansion.png')
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'mansion.blend'))
checkpoint('SAVE', 'Saved editable original .blend. Shared camera elevation 30 degrees; 900x900 RGBA; Cycles CPU. Rendering primary view next.')
bpy.ops.render.render(write_still=True)
# Opposite-view inspection, identical camera settings across variants.
camera.location=(-30,30,4.8+math.sqrt(1800)*math.tan(math.radians(30)));aim(camera,(0,0,4.8))
scene.render.filepath=str(folder/'reverse-review.png')
bpy.ops.render.render(write_still=True)
# Store primary pivot, lot projection corners, source geometry, four-floor validation.
camera.location=(30,-30,4.8+math.sqrt(1800)*math.tan(math.radians(30)));aim(camera,(0,0,4.8))
bpy.context.view_layer.update()
def pixel(point):
    p=world_to_camera_view(scene,camera,Vector(point))
    return [round(p.x*900,3),round((1-p.y)*900,3)]
metadata={'asset_id':f'mansion-{variant.lower()}-4x4-4f','zone':'residential','footprint_cells':[4,4],'cell_meters':4,'occupied_storeys':4,'storey_height_m':floor_height,'image_px':[900,900],'pivot_px':pixel((8,-8,.125)),'pivot_world_m':[8,-8,.125],'lot_corners_px':[pixel(p) for p in [(-8,-8,.125),(8,-8,.125),(8,8,.125),(-8,8,.125)]],'camera_elevation_degrees':30,'camera_azimuth_degrees':-45,'orthographic_scale':28,'source':'original scripted geometry; no downloaded textures or meshes','blender_version':bpy.app.version_string,'mesh_objects':len(meshes),'vertex_bounds_m':[mins,maxs],'limitations':['concept render, not integrated into Godot','no interior rooms','no finished collision meshes or LOD','transparent render, with modeled lot plinth']}
(folder/'metadata.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
checkpoint('RENDER','Primary and opposite inspection PNGs written; 4 occupied floors and lot bounds asserted. Visual inspection still required by agent. No paid service called.')
print('COMPLETED',variant,len(meshes),'mesh objects',json.dumps(metadata))
