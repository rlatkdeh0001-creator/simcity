"""Original road-edge transit facilities. Blender 4.3.2, metre units.
Use --output-root NEW_EMPTY_FOLDER to reproduce without touching delivered assets.
Dependencies: existing build_vehicle_fleet.py + zstack common (MIT, existing NOTICE).
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_vehicle_fleet as B
C=B.C
ROWS=[('bus-stop-01','버스 정류장',8.,3.,1),('bus-station-01','버스 스테이션',32.,12.,3),('taxi-stand-01','택시 스테이션',24.,8.,4)]
M={}; root=None

def box(name,size,pos,mat,bevel=0):
    return B.box(name,size,pos,M[mat],root,bevel)

def line(name,x,y,l,w=.06,color='paint'):
    return box(name,(l,w,.008),(x,y,.114),color,0)

def text(body,x,y,z,size,mat='paint'):
    curve=bpy.data.curves.new('SignText_'+body,'FONT');curve.body=body;curve.align_x='CENTER';curve.size=size;curve.extrude=.001;curve.resolution_u=2
    font=Path('C:/Windows/Fonts/arial.ttf')
    if font.exists(): curve.font=bpy.data.fonts.load(str(font))
    ob=bpy.data.objects.new('SignText_'+body,curve);C.link(ob)
    ob.location=(x,y,z);ob.rotation_euler.x=math.pi/2;ob.data.materials.append(M[mat]);C.parent_keep(ob,root)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    bpy.ops.object.convert(target='MESH');ob.select_set(False)

def bench(x,y,length=1.8):
    for dy in [-.18,0,.18]: box('BenchSeat',(length,.14,.08),(x,y+dy,.60),'wood',.012)
    for z in [.85,1.05]:box('BenchBack',(length,.07,.15),(x,y+.23,z),'wood')
    for dx in [-length*.34,length*.34]:
        box('BenchBackUpright',(.08,.08,.62),(x+dx,y+.23,.82),'metal')
        box('BenchFoot',(.12,.53,.09),(x+dx,y,.145),'metal')
        box('BenchLeg',(.10,.12,.45),(x+dx,y,.37),'metal')

def canopy(x,y,w,d,h,glazed=False):
    for px in [x-w/2+.18,x+w/2-.18]:
        for py in [y-d/2+.18,y+d/2-.18]:
            box('CanopyColumn',(.13,.13,h-.1),(px,py,(h+.1)/2),'metal')
            box('ColumnFoot',(.24,.24,.08),(px,py,.14),'metal')
    for py in [y-d/2+.10,y+d/2-.10]:box('CanopyFascia',(w,.20,.18),(x,py,h),'accent')
    for px in [x-w/2+.1,x+w/2-.1]:box('CanopySide',(.20,d,.18),(px,y,h),'metal')
    count=max(3,int(w/1.5))
    for i in range(count):
        px=x-w/2+(i+.5)*w/count
        box('CanopyPanel',(w/count-.04,d-.25,.065),(px,y,h+.035),'glass' if glazed else 'roof',.008)
    for i in range(1,count):box('CanopyCrossMember',(.06,d,.11),(x-w/2+i*w/count,y,h-.03),'metal')

def notice_board(x,y,z=1.8):
    box('InformationCase',(.88,.12,1.20),(x,y,z),'metal')
    box('InformationPanel',(.76,.025,1.08),(x,y-.075,z),'cream',0)
    for dz in [-.32,-.12,.08,.28]:
        box('RouteDiagram',(.52,.014,.025),(x,y-.095,z+dz),'accent',0)
    for dx in [-.18,0,.18]:
        box('RouteNode',(.04,.016,.07),(x+dx,y-.096,z+.08),'accent',0)

def marker(x,y,kind,height=3.2):
    box('StopPole',(.12,.12,height-.1),(x,y,(height+.1)/2),'metal')
    box('PoleFoot',(.25,.25,.10),(x,y,.15),'metal')
    box('StopSign',(.88,.16,.66),(x,y,height-.25),'accent')
    text(kind,x,y-.091,height-.40,.30)

def bay(name,x,y,length,width):
    for py in [y-width/2,y+width/2]:line(name+'_Side',x,py,length)
    for px in [x-length/2,x+length/2]:box(name+'_End',(.06,width,.008),(px,y,.114),'paint',0)

def arrows(x,y,reverse=False):
    line('DriveArrowStem',x,y,1.2,.12)
    # Simple planar arrowhead is authored mesh, not an image/decal texture.
    s=-1 if reverse else 1
    B.mesh('DriveArrowHead',[(x+s*.95,y,.119),(x+s*.30,y-.40,.119),(x+s*.30,y+.40,.119)],[(0,1,2)],M['paint'],root)

def shelter():
    box('SidewalkPad',(8,3,.10),(0,1.5,.05),'paving',.01)
    canopy(-.35,1.95,5.8,1.75,2.95,True)
    box('ShelterBackGlass',(5.38,.025,1.90),(-.35,2.72,1.54),'glass',0)
    for px in [-3.05,2.35]:box('ShelterSideGlass',(.025,1.30,1.90),(px,2.05,1.54),'glass',0)
    for px in [-1.75,1.05]:bench(px,2.22,1.65)
    notice_board(-.35,2.67)
    marker(3.4,2.35,'BUS')
    # Independently named, thin mesh. Fully inside the 8x3m sidewalk footprint.
    line('StopZoneYellowDecal',0,.10,7.6,.12,'yellow')
    for px in [-3.75,3.75]:box('StopZoneYellowEndDecal',(.10,.36,.006),(px,.23,.113),'yellow',0)
    for px in [-2,0,2]:
        box('RoofBrace',(.06,1.50,.10),(px,1.95,2.82),'metal')

def bus_station():
    box('StationPaving',(32,12,.10),(0,6,.05),'asphalt',.01)
    box('RearWaitingWalk',(30,1.35,.12),(0,11.325,.16),'paving',.01)
    # Three 12m x 2.8m static bus bays, parallel to road; side aprons remain clear.
    for i,y in enumerate([2.,5.5,9.]):
        bay('BusBay'+str(i+1),0,y,12.,2.8)
        line('BusBaySafetyLine',0,y+1.48,12.5,.10,'yellow')
        for px in [-6.5,6.5]:
            box('BayBollard',(.12,.12,.85),(px,y+1.48,.525),'metal')
            box('BollardReflector',(.14,.14,.10),(px,y+1.48,.78),'yellow')
    canopy(0,11.18,17.,1.45,4.0)
    for x in [-5,0,5]:bench(x,11.15,2.2)
    for x in [-7.4,7.4]:notice_board(x,11.83,1.9)
    marker(-14.4,10.7,'BUS',3.5)
    for x in [-11.5,11.5]:
        for dx in [-3.2,3.2]:box('RoadEntryEdge',(.12,2.2,.008),(x+dx,1.1,.114),'paint',0)
        for k in range(4):box('EntryPavingMark',(.38,.70,.008),(x-1.8+k*1.2,.55,.114),'yellow',0)
    arrows(-11.5,5.5);arrows(11.5,5.5,True)
    # Only rear boundary kerb: no solid obstruction across either front entrance.
    box('RearKerb',(32,.12,.22),(0,11.94,.11),'curb',.01)

def taxi_station():
    box('TaxiPaving',(24,8,.10),(0,4,.05),'asphalt',.01)
    box('TaxiWaitingWalk',(15,1.6,.12),(0,7.1,.16),'paving',.01)
    # Four perpendicular 2.6m x 5.2m bays fit the existing taxi including mirrors.
    for i,x in enumerate([-4.5,-1.5,1.5,4.5]):
        bay('TaxiBay'+str(i+1),x,3.35,2.6,5.2)
        line('TaxiFrontSafety',x,.62,2.45,.10,'yellow')
    canopy(0,7.05,14.8,1.6,3.15)
    for x in [-4,0,4]:bench(x,7.0,1.9)
    box('TaxiSignBoard',(3.4,.18,.65),(0,6.23,2.69),'accent')
    text('TAXI',0,6.125,2.48,.46,'yellow')
    notice_board(6.4,7.60,1.8)
    for x in [-9.5,9.5]:
        for dx in [-2,2]:box('TaxiEntranceEdge',(.08,2.0,.008),(x+dx,1.0,.114),'paint',0)
        for k in range(3):box('TaxiEntryPavingMark',(.32,.60,.008),(x-1.2+k*1.2,.5,.114),'yellow',0)
    marker(-10.8,6.8,'TAXI',3.3)
    for x in [-7,7]:
        box('AccessBollard',(.14,.14,.90),(x,6.1,.55),'metal')
        box('BollardStripe',(.16,.16,.12),(x,6.1,.90),'yellow')
    box('RearKerb',(24,.12,.22),(0,7.94,.11),'curb',.01)

def render(path,w,d,h):
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False
    s.render.resolution_x=800;s.render.resolution_y=680;s.render.resolution_percentage=100;s.render.film_transparent=True
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.view_settings.view_transform='Standard'
    s.world=bpy.data.worlds.new('Studio');s.world.use_nodes=True
    s.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    ld=bpy.data.lights.new('Key','AREA');ld.energy=2200;ld.size=15
    light=bpy.data.objects.new('Key',ld);s.collection.objects.link(light);light.location=(12,-15,22)
    light.rotation_euler=(Vector((0,d/2,1))-light.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);s.collection.objects.link(cam);s.camera=cam
    target=Vector((0,d/2,h*.32));cam.location=target+Vector((30,-30,math.sqrt(1800)*math.tan(math.radians(30))))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO'
    cd.ortho_scale=max((w+d)*.707,((w+d)*.354+h*.866)*800/680)*1.16
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    return {'resolution':[800,680],'pixels_per_metre':800/cd.ortho_scale,'camera_elevation_deg':30}

def main():
    global M,root
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.output_root;entries=[]
    for ident,name,w,d,capacity in ROWS:
        folder=out/'assets/facilities'/ident
        if folder.exists():raise RuntimeError('Protected source exists: '+str(folder))
        C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
        root=C.empty('RoadEdgeFacilityRoot');root['asset_id']=ident;root['placement']='road_edge';root['frontGltf']=[0.,0.,1.]
        M={k:B.material(k,c) for k,c in {'asphalt':'4c5659','paint':'e8e7dc','yellow':'e4bd5f','paving':'ded6bf','wood':'aa8059','metal':'344b53','curb':'c8cbc3','accent':'507c89','cream':'e2dcc8','roof':'526b70','glass':'91b1b9'}.items()}
        glass=M['glass'];glass.diffuse_color=(*glass.diffuse_color[:3],.32);glass.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.32;glass.surface_render_method='DITHERED'
        {'bus-stop-01':shelter,'bus-station-01':bus_station,'taxi-stand-01':taxi_station}[ident]()
        C.update();meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];tri=C.tri_count(meshes)
        points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices];lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)]
        assert abs(lo[0]+w/2)<.001 and abs(hi[0]-w/2)<.001 and abs(lo[1])<.001 and abs(hi[1]-d)<.001,(ident,lo,hi)
        assert 1500<=tri<=4000,(ident,tri)
        folder.mkdir(parents=True);game=out/'cities_do/assets/facilities';game.mkdir(parents=True,exist_ok=True)
        bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/(ident+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
        info=render(folder/'preview.png',w,d,hi[2]);shutil.copy2(folder/'preview.png',game/(ident+'.png'))
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/'facility.blend'),compress=True)
        spec={'id':ident,'name':name,'kind':'transit_road_edge','width':w/4,'depth':d/4,'metres':[w,d],'storeys':0,'capacity':capacity,'capacity_unit':'static_vehicle_bays','capacity_status':'geometry only, not passenger capacity or transport simulation',
        'placement':'road_edge','road_side':{'blender':'-Y','gltf':'+Z','edge_coordinate_m':0},'origin':'centre of road-contact edge, ground z=0','road_axis_blender':'+X','sidewalk_occupied_width_m':d if ident=='bus-stop-01' else 0,'inward_depth_m':d,'required_sidewalk_width_m':3.0 if ident=='bus-stop-01' else 0,
        'frame_blender':{'front':'-Y','up':'+Z'},'frame_gltf':{'front':'+Z','up':'+Y'},'height_m':round(hi[2],4),'length_m':d,'width_m':w,'triangles':tri,'model':'res://assets/facilities/'+ident+'.glb','preview':'res://assets/facilities/'+ident+'.png','source':'assets/facilities/'+ident+'/facility.blend','render':info,'status':'inspection_only','road_attachment_implemented':False,'not_validated':['live road placement','vehicle turning swept path','passenger simulation']}
        if ident=='bus-stop-01':spec['separate_decal_mesh']='StopZoneYellowDecal';spec['review_bus_blender']=[0,-1.65,0]
        if ident=='bus-station-01':spec.update({'entry_exit_centres_blender':[[-11.5,0,0],[11.5,0,0]],'review_bus_centres_blender':[[0,2,.1],[0,5.5,.1],[0,9,.1]],'bay_dimensions_m':[12,2.8]})
        if ident=='taxi-stand-01':spec.update({'entry_exit_centres_blender':[[-9.5,0,0],[9.5,0,0]],'review_taxi_centres_blender':[[x,3.35,.1] for x in [-4.5,-1.5,1.5,4.5]],'bay_dimensions_m':[2.6,5.2]})
        B.write_json(folder/'spec.json',spec)
        (folder/'build.py').write_text('"""Reproduce all three facilities into a new empty output workspace."""\nimport runpy\nfrom pathlib import Path\nroot=Path(__file__).resolve().parents[3]\nrunpy.run_path(str(root/"tools/build_transit_roadside.py"),run_name="__main__")\n',encoding='utf-8')
        entries.append(spec);print('ROADSIDE_BUILT',ident,w,d,hi[2],tri,flush=True)
    path=out/'cities_do/assets/facilities/catalog.json';doc=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'facilities':[]}
    ids={e['id'] for e in doc['facilities']};assert not ids.intersection(e['id'] for e in entries)
    doc['facilities'].extend(entries);B.write_json(path,doc)
if __name__=='__main__':main()
