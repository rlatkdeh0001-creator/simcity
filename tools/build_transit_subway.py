"""Original subway entrance + deliberately low-detail underground silhouette.
Blender4.3.2. Existing sources protected; --output-root NEW_EMPTY_WORKSPACE for replay.
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_roadside as R
import build_transit_vehicles as T
B=R.B;C=R.C
ROWS=[('subway-entrance-01','지하철역 입구',8.,8.),('subway-platform-silhouette-01','지하철 승강장 실루엣',64.,12.)]


def rail(name,x,y0,z0,y1,z1,mat='metal',radius=.035):
    T.tube(name,[(x,y0,z0),(x,y1,z1)],radius,R.M[mat],R.root,segments=8)


def escalator_side(name,x):
    y0,y1=-2.45,2.18;z0,z1=0.,-2.52
    vertices=[(x+dx,y,z+h) for dx in [-.035,.035] for y,z in [(y0,z0),(y1,z1)] for h in [.10,.78]]
    B.mesh(name,vertices,[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)],R.M['glass'],R.root)
    rail(name+'_Handrail',x,y0,z0+.80,y1,z1+.80,'metal',.045)


def entrance():
    # Four closed pavement strips leave a real finite stair opening, not a black image.
    for x in [-3.3,3.3]:R.box('SidePaving',(1.4,8.,.12),(x,0,-.06),'paving',.01)
    for y in [-3.3,3.3]:R.box('EndPaving',(5.2,1.4,.12),(0,y,-.06),'paving',.01)
    R.box('WellBottom',(5.2,5.2,.18),(0,0,-2.79),'concrete')
    for x in [-2.64,2.64]:R.box('WellSideWall',(.16,5.2,2.70),(x,0,-1.35),'concrete')
    R.box('WellEndWall',(5.2,.16,2.70),(0,2.64,-1.35),'concrete')
    R.box('WellFrontRetaining',(5.2,.12,2.52),(0,-2.64,-1.44),'concrete')
    for i in range(14):
        y=-2.6+(i+.5)*.34;top=-i*.18;bottom=-2.70
        R.box('DescendingStairTread',(2.15,.34,top-bottom),(-1.35,y,(top+bottom)/2),'concrete',.008)
        R.box('StairNosing',(2.10,.035,.018),(-1.35,y-.14,top+.009),'metal')
    R.box('FiniteBottomLanding',(5.04,.50,.12),(0,2.35,-2.58),'paving')
    # Sculpted escalator treads and side balustrades; no animated operation claimed.
    for i in range(18):
        y=-2.45+(i+.5)*4.63/18;top=-i*2.52/18
        R.box('EscalatorTread',(1.50,4.63/18,top+2.70),(1.25,y,(top-2.70)/2),'metal',.005)
        for dx in [-.47,0,.47]:R.box('EscalatorTreadGroove',(.025,4.63/18-.02,.012),(1.25+dx,y,top+.006),'dark')
    escalator_side('EscalatorGlassLeft',.43);escalator_side('EscalatorGlassRight',2.07)
    rail('StairWallHandrail',-2.39,-2.46,.83,2.17,-1.69)
    for x in [-2.8,2.8]:
        for y in [-1.9,-.2,1.5,2.6]:R.box('OpeningGuardPost',(.07,.07,.92),(x,y,.46),'metal')
        rail('OpeningGuardTop',x,-2.45,.95,2.75,.95)
        rail('OpeningGuardMid',x,-2.45,.55,2.75,.55)
    R.box('RearOpeningGuard',(5.6,.07,.10),(0,2.80,.95),'metal')
    R.canopy(0,0,5.8,5.8,2.60,True)
    # Fictional circular M beacon, converted system-font geometry, no real logo.
    R.box('MetroPylon',(.13,.13,3.15),(3.25,-2.70,1.575),'metal')
    R.box('MetroPylonFoot',(.32,.32,.12),(3.25,-2.70,.06),'metal')
    B.cylinder('MetroRoundel',.46,.16,(3.25,-2.70,3.25),R.M['accent'],R.root,axis='Y',segments=24)
    R.text('M',3.25,-2.793,3.02,.58)
    R.box('VentilationPlinth',(1.12,1.25,.13),(-3.3,2.85,.065),'concrete')
    R.box('VentilationUnit',(1.0,1.12,.85),(-3.3,2.85,.555),'metal',.02)
    for i in range(8):R.box('VentLouvre',(.92,.045,.035),(-3.3,2.275,.25+i*.08),'cream')


def silhouette():
    # Eight simple closed boxes, one material, no rails/sleepers/benches/people.
    R.box('UndergroundFloor',(64,12,.30),(0,0,-12.85),'silhouette')
    R.box('IslandPlatform',(64,5.,.70),(0,0,-12.35),'silhouette')
    for y in [-5.9,5.9]:R.box('OuterTrackEdge',(64,.20,.70),(0,y,-12.35),'silhouette')
    for x in [-31.9,31.9]:R.box('TrackEndCap',(.20,12.,.70),(x,0,-12.35),'silhouette')
    R.box('EntranceCorridorMass',(3.2,4.,2.6),(0,-4.,-9.8),'silhouette')
    R.box('PlatformAccessMass',(3.2,2.2,3.5),(0,-1.5,-10.25),'silhouette')


def studio(path,lo,hi):
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False
    s.render.resolution_x=800;s.render.resolution_y=680;s.render.resolution_percentage=100;s.render.film_transparent=True
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.view_settings.view_transform='Standard'
    s.world=bpy.data.worlds.new('Studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    center=Vector([(a+b)/2 for a,b in zip(lo,hi)]);w,d,h=[b-a for a,b in zip(lo,hi)]
    ld=bpy.data.lights.new('Key','AREA');ld.energy=2200;ld.size=15
    light=bpy.data.objects.new('Key',ld);s.collection.objects.link(light);light.location=center+Vector((12,-15,22));light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);s.collection.objects.link(cam);s.camera=cam;cd.type='ORTHO'
    cam.location=center+Vector((30,-30,math.sqrt(1800)*math.tan(math.radians(30))))
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cd.ortho_scale=max((w+d)*.707,((w+d)*.354+h*.866)*800/680)*1.16
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    return {'resolution':[800,680],'camera_elevation_deg':30,'pixels_per_metre':800/cd.ortho_scale}


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.output_root;entries=[]
    for ident,name,w,d in ROWS:
        folder=out/'assets/facilities'/ident
        if folder.exists():raise RuntimeError('Protected source exists: '+str(folder))
        C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
        R.root=C.empty('SubwayFacilityRoot');R.root['asset_id']=ident;R.root['frontGltf']=[0.,0.,1.];is_silhouette=ident.endswith('silhouette-01')
        R.M={k:B.material(k,c) for k,c in {'paint':'e8e7dc','paving':'ded6bf','concrete':'bdc5c1','metal':'344b53','dark':'30383b','cream':'e2dcc8','accent':'507c89','roof':'526b70','glass':'91b1b9','silhouette':'688d98'}.items()}
        R.M['glass'].diffuse_color=(*R.M['glass'].diffuse_color[:3],.28);R.M['glass'].node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.28;R.M['glass'].surface_render_method='DITHERED'
        (silhouette if is_silhouette else entrance)();C.update();tri,lo,hi=T.measure()
        assert abs(hi[0]-lo[0]-w)<.001 and abs(hi[1]-lo[1]-d)<.001,(ident,lo,hi)
        if is_silhouette:
            used={mat.name for o in bpy.context.scene.objects if o.type=='MESH' for mat in o.data.materials};assert used=={'silhouette'} and tri<200,(used,tri)
        else:assert 1500<=tri<=4000,(ident,tri)
        folder.mkdir(parents=True);game=out/'cities_do/assets/facilities';game.mkdir(parents=True,exist_ok=True)
        bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/(ident+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
        info=studio(folder/'preview.png',lo,hi);shutil.copy2(folder/'preview.png',game/(ident+'.png'))
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/'facility.blend'),compress=True)
        spec={'id':ident,'name':name,'kind':'subway_underground_silhouette' if is_silhouette else 'subway_entrance','width':int(w/4),'depth':int(d/4),'metres':[w,d],'storeys':0,'capacity':None,'capacity_status':'not a passenger throughput proposal',
            'model':'res://assets/facilities/'+ident+'.glb','preview':'res://assets/facilities/'+ident+'.png','source':'assets/facilities/'+ident+'/facility.blend','render':info,'triangles':tri,'height_m':round(hi[2]-lo[2],4),'width_m':w,'length_m':d,'bounds_blender_m':{'min':[round(v,4) for v in lo],'max':[round(v,4) for v in hi]},
            'frame_blender':{'front':'-Y','up':'+Z'},'frame_gltf':{'front':'+Z','up':'+Y'},'origin':'lot centre at ground datum','status':'inspection_only','map_placement_implemented':False}
        if is_silhouette:spec.update({'visibility':'underground_only','platform_surface_blender_z_m':-12,'depth_below_ground_m':12,'material_count':1,'detail_level':'eight closed mass boxes only; no track detail','track_groove_floor_blender_z_m':-12.7,'entrance_corridor_top_blender_z_m':-8.5})
        else:spec.update({'above_ground_height_m':round(hi[2],4),'opening_size_m':[5.2,5.2],'opening_bottom_blender_z_m':-2.7,'landing_surface_blender_z_m':-2.52,'requires_ground_cutout':True,'ground_cutout_rect_blender_m':[-2.6,-2.6,5.2,5.2],'not_validated':['game terrain cutout integration','passenger pathing','escalator animation']})
        B.write_json(folder/'spec.json',spec)
        (folder/'build.py').write_text('import runpy\nfrom pathlib import Path\nroot=Path(__file__).resolve().parents[3]\nrunpy.run_path(str(root/"tools/build_transit_subway.py"),run_name="__main__")\n',encoding='utf-8')
        entries.append(spec);print('SUBWAY_BUILT',ident,[w,d],lo,hi,'TRIANGLES',tri,flush=True)
    path=out/'cities_do/assets/facilities/catalog.json';doc=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'facilities':[]};ids={e['id'] for e in doc['facilities']};assert not ids.intersection(e['id'] for e in entries);doc['facilities'].extend(entries);B.write_json(path,doc)
if __name__=='__main__':main()
