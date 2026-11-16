"""Original small taxi stop + width-only bus-stop v2 repack for the minimum sidewalk.
Current local2/3-lane sidewalk is 0.75m (road_profile.gd); body depth0.72m.
Road paint is an independent mesh outside the curb, excluded from sidewalk footprint.
Blender4.3.2; --output-root NEW_EMPTY_WORKSPACE preserves previous sources.
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_roadside as R
import build_transit_subway as S
import build_transit_vehicles as T
B=R.B;C=R.C
DEPTH=.72
ROWS=[('bus-stop-01','버스 정류장',8.,'v2'),('taxi-stop-01','소형 택시 정류장',6.,None)]


def box(name,size,pos,mat,bevel=.018):return R.box(name,size,pos,mat,bevel)

def bench(x,y,length):
    # Preserve X/Z proportions; only shallow depth is repacked for the sidewalk.
    for dy in [-.105,-.035,.035,.105]:box('BenchSeat',(length,.065,.08),(x,y+dy,.60),'wood',.01)
    for z in [.85,1.05]:box('BenchBack',(length,.05,.15),(x,y+.16,z),'wood',.01)
    for dx in [-length*.34,length*.34]:
        box('BenchFoot',(.12,.29,.09),(x+dx,y,.145),'metal',.01)
        box('BenchLeg',(.10,.08,.45),(x+dx,y,.37),'metal',.01)
        box('BenchBackUpright',(.07,.06,.62),(x+dx,y+.16,.82),'metal',.01)


def canopy(x,w,h,glazed):
    for px in [x-w/2+.18,x+w/2-.18]:
        for y in [.12,.62]:
            box('CanopyColumn',(.10,.08,h-.1),(px,y,(h+.1)/2),'metal',.012)
            box('ColumnFoot',(.18,.16,.08),(px,y,.14),'metal',.01)
    for y in [.055,.665]:box('CanopyFascia',(w,.09,.18),(x,y,h),'accent',.015)
    for px in [x-w/2+.06,x+w/2-.06]:box('CanopySide',(.12,.70,.18),(px,.36,h),'metal',.015)
    n=max(3,int(w/1.5))
    for i in range(n):
        px=x-w/2+(i+.5)*w/n
        box('CanopyPanel',(w/n-.035,.61,.06),(px,.36,h+.035),'glass' if glazed else 'roof',.007)
    for i in range(1,n):box('CanopyCrossMember',(.05,.68,.10),(x-w/2+i*w/n,.36,h-.04),'metal',.007)


def thin_board(x):
    box('InformationCase',(.88,.08,1.20),(x,.65,1.8),'metal',.015)
    box('InformationPanel',(.76,.014,1.08),(x,.607,1.8),'cream',0)
    for dz in [-.32,-.12,.08,.28]:box('RouteDiagram',(.52,.012,.025),(x,.594,1.8+dz),'accent',0)
    for dx in [-.18,0,.18]:box('RouteNode',(.04,.012,.07),(x+dx,.594,1.88),'accent',0)


def sign(x,kind,height):
    box('StopPole',(.12,.10,height-.1),(x,.50,(height+.1)/2),'metal',.015)
    box('PoleFoot',(.24,.20,.10),(x,.50,.15),'metal',.015)
    box('StopSign',(.88,.14,.66),(x,.50,height-.25),'accent',.02)
    R.text(kind,x,.415,height-.40,.30)


def road_decal(name,rects,color):
    verts=[];faces=[]
    for x0,y0,x1,y1 in rects:
        start=len(verts);verts += [(x0,y0,.012),(x1,y0,.012),(x1,y1,.012),(x0,y1,.012)];faces.append((start,start+1,start+2,start+3))
    ob=B.mesh(name,verts,faces,R.M[color],R.root);ob['placement_part']='road_decal';ob['not_sidewalk_occupancy']=True


def bus_stop():
    box('SidewalkPad',(8.,DEPTH,.10),(0,DEPTH/2,.05),'paving',.01)
    canopy(-.35,5.8,2.95,True)
    box('ShelterBackGlass',(5.38,.02,1.9),(-.35,.69,1.54),'glass',0)
    for x in [-3.05,2.35]:box('ShelterSideGlass',(.025,.38,1.9),(x,.50,1.54),'glass',0)
    for z in [.59,2.49]:box('GlassBackRail',(5.4,.06,.05),(-.35,.69,z),'metal',.006)
    for x in [-3.05,2.35]:box('GlassSideRail',(.05,.52,.05),(x,.42,.59),'metal',.006)
    for x in [-1.75,1.05]:bench(x,.48,1.65)
    thin_board(-.35);sign(3.4,'BUS',3.2)
    road_decal('StopZoneYellowDecal',[(-3.8,-.12,3.8,-.02)],'yellow')


def taxi_stop():
    box('SidewalkPad',(6.,DEPTH,.10),(0,DEPTH/2,.05),'paving',.01)
    canopy(-.55,3.8,2.60,False)
    bench(-.55,.48,1.8)
    sign(2.50,'TAXI',3.0)
    # One curbside taxi bay, independently removable/repositionable in the game.
    road_decal('TaxiStopRoadDecal',[(-2.6,-2.5,2.6,-2.43),(-2.6,-.27,2.6,-.20),(-2.6,-2.43,-2.53,-.27),(2.53,-2.43,2.6,-.27)],'yellow')
    # Slim information blade on a canopy column; keeps the street-facing design legible.
    box('TaxiInfoBlade',(.62,.08,.88),(-2.05,.62,1.66),'accent',.012)
    for z in [1.45,1.65,1.85]:box('InfoRouteLine',(.42,.012,.026),(-2.05,.575,z),'paint',0)


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.output_root;entries=[]
    for ident,name,length,version in ROWS:
        relative=Path('assets/facilities')/ident
        if version:relative/=version
        folder=out/relative;export=ident+('-'+version if version else '')
        if folder.exists():raise RuntimeError('Protected source exists: '+str(folder))
        C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
        R.root=C.empty('SidewalkStopRoot');R.root['asset_id']=ident;R.root['placement']='road_edge';R.root['zoning_occupancy_cells']=0
        R.M={k:B.material(k,c) for k,c in {'paving':'ded6bf','paint':'e8e7dc','yellow':'e4bd5f','wood':'aa8059','metal':'344b53','accent':'507c89','cream':'e2dcc8','roof':'526b70','glass':'91b1b9'}.items()}
        R.M['glass'].diffuse_color=(*R.M['glass'].diffuse_color[:3],.32);R.M['glass'].node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.32;R.M['glass'].surface_render_method='DITHERED'
        (bus_stop if ident=='bus-stop-01' else taxi_stop)();C.update();tri,lo,hi=T.measure()
        body=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.get('placement_part')!='road_decal']
        points=[o.matrix_world@v.co for o in body for v in o.data.vertices];body_lo=[min(v[i] for v in points) for i in range(3)];body_hi=[max(v[i] for v in points) for i in range(3)]
        assert abs(body_hi[0]-body_lo[0]-length)<.001 and abs(body_lo[1])<.001 and abs(body_hi[1]-DEPTH)<.001,(ident,body_lo,body_hi)
        assert 1500<=tri<=4000,(ident,tri)
        folder.mkdir(parents=True);game=out/'cities_do/assets/facilities';game.mkdir(parents=True,exist_ok=True)
        bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/(export+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
        info=S.studio(folder/'preview.png',lo,hi);shutil.copy2(folder/'preview.png',game/(export+'.png'))
        bpy.ops.wm.save_as_mainfile(filepath=str(folder/'facility.blend'),compress=True)
        spec={'id':ident,'name':name,'kind':'transit_sidewalk_stop','width':length/4,'depth':DEPTH/4,'metres':[length,DEPTH],'storeys':0,'capacity':1,'capacity_unit':'static curbside stopping position, not passengers',
            'placement':'road_edge','placement_surface':'sidewalk_only','road_side':{'blender':'-Y','gltf':'+Z','edge_coordinate_m':0},'origin':'curb-contact edge centre at ground datum','sidewalk_occupied_width_m':DEPTH,'required_sidewalk_width_m':.75,'minimum_sidewalk_derived_from':'core/road_profile.gd local2/3, total12m/asphalt10.5m, per-side sidewalk0.75m','zoning_occupancy_cells':0,'zoning_footprint_cells':[0,0],
            'height_m':round(hi[2],4),'width_m':length,'length_m':DEPTH,'triangles':tri,'body_bounds_blender_m':{'min':[round(v,4) for v in body_lo],'max':[round(v,4) for v in body_hi]},'all_geometry_bounds_blender_m':{'min':[round(v,4) for v in lo],'max':[round(v,4) for v in hi]},
            'model':'res://assets/facilities/'+export+'.glb','preview':'res://assets/facilities/'+export+'.png','source':relative.as_posix()+'/facility.blend','render':info,
            'separate_decal_mesh':'StopZoneYellowDecal' if ident=='bus-stop-01' else 'TaxiStopRoadDecal','road_decal_excluded_from_sidewalk_footprint':True,'status':'inspection_only','road_attachment_implemented':False,'not_validated':['live road attachment','passenger paths','curbside vehicle stopping simulation']}
        if version:spec.update({'supersedes':'bus-stop-01 v1 retained','revision_scope':'X extent/height/palette/components retained, only depth repacked from3m to0.72m'})
        B.write_json(folder/'spec.json',spec)
        (folder/'build.py').write_text('import runpy\nfrom pathlib import Path\nroot=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_sidewalk_transit_stops.py").is_file())\nrunpy.run_path(str(root/"tools/build_sidewalk_transit_stops.py"),run_name="__main__")\n',encoding='utf-8')
        entries.append(spec);print('SIDEWALK_STOP_BUILT',ident,[length,DEPTH,round(hi[2],4)],'TRIANGLES',tri,flush=True)
    p=out/'cities_do/assets/facilities/catalog.json';doc=json.loads(p.read_text(encoding='utf-8')) if p.exists() else {'facilities':[]};replacements={e['id']:e for e in entries};ids={e['id'] for e in doc['facilities']};doc['facilities']=[replacements.get(e['id'],e) for e in doc['facilities']]+[e for e in entries if e['id'] not in ids];B.write_json(p,doc)
if __name__=='__main__':main()
