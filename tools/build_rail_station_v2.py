"""Authorized underpass station; v1 helpers are read-only, never call their main."""
import sys,json,shutil
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_train_station as V
R=V.R;B=V.B;C=V.C;T=V.T;S=V.S
box=R.box

def slab(name,x0,x1,y0,y1,z0,z1,mat='concrete'):
    return box(name,(x1-x0,y1-y0,z1-z0),((x0+x1)/2,(y0+y1)/2,(z0+z1)/2),mat,0)

def platform(y0,y1,rear=False):
    # 1.8m inner width; 2.1m unobstructed strip beside the well.
    a,b=-15.5,-9.1;c,d=(16.05,17.85) if rear else (2.15,3.95)
    for xa,xb,ya,yb in [(-16,a,y0,y1),(b,16,y0,y1),(a,b,y0,c),(a,b,d,y1)]:
        slab('PlatformBody',xa,xb,ya,yb,0,1.04)
        slab('PlatformPaving',xa,xb,ya,yb,1.04,1.1,'paving')
    edge=y0+.22 if rear else y1-.22
    slab('PlatformSafetyEdge',-16,16,edge-.08,edge+.08,1.1,1.112,'yellow')
    slab('WellBottom',a-.15,b+.15,c-.15,d+.15,-3.85,-3.6)
    slab('WellWallOuter',a-.15,b+.15,c-.15,c,-3.6,1.95)
    slab('WellWallInner',a-.15,b+.15,d,d+.15,-3.6,1.95)
    slab('WellWallEntry',a-.15,a,c,d,-3.6,1.1)
    slab('WellWallEnd',b,b+.15,c,d,-3.6,1.95)
    # Two 12-riser flights, one .8m intermediate landing and .8m bottom landing.
    x=a
    for i in range(24):
        if i==12:
            slab('UnderpassIntermediateLanding',x,x+.8,c,d,-3.6,-1.25,'paving');x+=.8
        top=1.1-(i+1)*4.7/24
        if top>-3.6+1e-5:slab('UnderpassStep',x,x+.2,c,d,-3.6,top,'paving')
        x+=.2
    slab('UnderpassLandingFinish',x,b,c,d,-3.62,-3.6,'paving')
    # Canopy same palette, section and height as v1; stays within platform.
    before=set(bpy.context.scene.objects);R.canopy(0,(y0+y1)/2,32,4.2,4.72)
    for ob in set(bpy.context.scene.objects)-before:
        if ob.name.startswith(('CanopyColumn','ColumnFoot')):
            bpy.data.objects.remove(ob,do_unlink=True)
    for x in [-8,-4,0,4,8,12,15.6]:
        for y in [y0+.24,y1-.24]:
            box('PlatformCanopySupport',(.14,.14,3.62),(x,y,2.91),'metal')
    for x in [-6,-1,4,9,13]:
        before=set(bpy.context.scene.objects);R.bench(x,(y0+y1)/2,1.8)
        for ob in set(bpy.context.scene.objects)-before:ob.location.z+=.98
    for x in [-7,14.4]:
        box('PlatformSignPole',(.10,.10,2.8),(x,(y0+y1)/2,2.5),'metal')
        box('PlatformSign',(1.25,.14,.60),(x,(y0+y1)/2,3.65),'accent')
    if rear:
        for x in range(-16,17,2):box('RearRailingPost',(.08,.08,.95),(max(-15.96,min(15.96,x)),17.96,1.575),'metal')
        box('RearHandrail',(32,.08,.08),(0,17.96,2.01),'metal')
    return [[a,c,1.1],[b,d,1.1]]

def main():
    folder=ROOT/'assets/facilities/train-station-01/v2';assert not folder.exists(),'Protected v2 already exists'
    C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    R.M={k:B.material(k,c,.2 if k=='metal' else 0) for k,c in {'paving':'ded6bf','asphalt':'4c5659','paint':'e8e7dc','yellow':'e4bd5f','concrete':'bdc5c1','metal':'344b53','cream':'e2dcc8','accent':'507c89','roof':'526b70','glass':'91b1b9','window':'294453','green':'718c67','wood':'aa8059'}.items()}
    R.M['glass'].diffuse_color=(*R.M['glass'].diffuse_color[:3],.32);R.M['glass'].node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.32;R.M['glass'].surface_render_method='DITHERED'
    R.root=C.empty('StationFront');front=R.root
    V.dropoff();V.wing(-1);V.wing(1);V.atrium()
    bpy.data.objects.remove(bpy.data.objects['WholeLotBase'],do_unlink=True)
    slab('FrontSectionBase',-16,16,-12,8,0,.12,'paving')
    for x in [-7.2,0,7.2]:
        for i in range(4):
            top=.30+(i+1)*.20
            V.box('PlatformAccessStep',(2.3,.20,top-.12),(x,7.2+(i+.5)*.20,(top+.12)/2),'concrete',.01)
    for ob in list(front.children):ob.location.y-=6
    opening1=platform(2,6.2)
    R.root=C.empty('StationRear');rear=R.root;opening2=platform(13.8,18,True)
    C.update();tri,lo,hi=T.measure()
    assert tri<=20000,(tri,lo,hi)
    assert all(abs(a-b)<.002 for a,b in zip(lo,[-16,-18,-3.85])) and all(abs(a-b)<.002 for a,b in zip(hi,[16,18,10.56])),(lo,hi)
    for group,limit,isfront in [(front,6.2,True),(rear,13.8,False)]:
        for ob in group.children:
            if ob.type!='MESH':continue
            ys=[(ob.matrix_world@v.co).y for v in ob.data.vertices]
            assert max(ys)<=limit+.0001 if isfront else min(ys)>=limit-.0001,ob.name
    folder.mkdir(parents=True);game=ROOT/'cities_do/assets/facilities'
    bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/'train-station-01-v2.glb'),export_format='GLB',export_extras=True,export_animations=False)
    info=S.studio(folder/'preview.png',lo,hi);shutil.copy2(folder/'preview.png',game/'train-station-01-v2.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'facility.blend'),compress=True)
    spec=json.loads((folder.parent/'spec.json').read_text(encoding='utf-8'))
    for key in ['review_train_centres_godot','platform_rear_edge_blender_y_m']:spec.pop(key,None)
    spec.update(version='v2',supersedes='train-station-01 v1 retained',width=8,depth=9,metres=[32,36],width_m=32,length_m=36,height_m=round(hi[2],4),triangles=tri,model='res://assets/facilities/train-station-01-v2.glb',preview='res://assets/facilities/train-station-01-v2.png',source='assets/facilities/train-station-01/v2/facility.blend',render=info,bounds_blender_m={'min':[round(v,4) for v in lo],'max':[round(v,4) for v in hi]},platform_count=2,platform_depth_m=4.2,platform_edges_blender_y_m=[6.2,13.8],track_count=2,track_centres_blender_y_m=[8,12],track_midline_blender_y_m=10,track_spacing_m=4,platform_edge_to_track_centre_m=1.8,trackway_width_m=7.6,track_end_points_blender=[[-16,10,0],[16,10,0]],underpass_floor_blender_z_m=-3.6,underpass_bottom_blender_z_m=round(lo[2],4),underpass_stair_openings_blender=[opening1,opening2],underpass_stair_inner_width_m=1.8,underpass_trackside_walk_width_m=2.1,underpass_intermediate_landing_z_m=-1.25,underpass_tunnel_included=False,layer_nodes=['StationFront','StationRear'],max_consist_length_m=32,dropoff_bay_centres_blender=[[-6.5,-13.3,.14],[1,-13.3,.14],[8.5,-13.3,.14]],terrain_cutout_required=True)
    B.write_json(folder/'spec.json',spec)
    (folder/'build.py').write_text('import runpy\nfrom pathlib import Path\nrunpy.run_path(str(Path(__file__).resolve().parents[4]/"tools/build_rail_station_v2.py"),run_name="__main__")\n',encoding='utf-8')
    path=game/'catalog.json';doc=json.loads(path.read_text(encoding='utf-8'));doc['facilities']=[spec if e['id']=='train-station-01' else e for e in doc['facilities']];B.write_json(path,doc)
    print('STATION_V2_BUILT',tri,lo,hi,flush=True)
if __name__=='__main__':main()
