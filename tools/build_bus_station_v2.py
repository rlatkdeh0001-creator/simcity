"""Bus station v2: approved 48x20m, five 30-degree sawtooth bays, one-way apron.
Blender 4.3.2. --output-root NEW_EMPTY_WORKSPACE preserves originals.
Uses existing original road-edge primitives/studio and MIT vehicle helper.
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
C=R.C;B=R.B
ANGLE=math.radians(30)
CENTRES=[(-18.,7.60),(-9.,7.60),(0.,7.60),(9.,7.60),(18.,7.60)]

def mark(name,points,width=.065,color='paint'):
    # Up-facing planar strip; all painted geometry stays above the asphalt.
    for i,(a,b) in enumerate(zip(points,points[1:])):
        dx=b[0]-a[0];dy=b[1]-a[1];length=math.hypot(dx,dy);nx=-dy/length*width/2;ny=dx/length*width/2
        R.B.mesh(name+str(i),[(a[0]+nx,a[1]+ny,.116),(a[0]-nx,a[1]-ny,.116),(b[0]-nx,b[1]-ny,.116),(b[0]+nx,b[1]+ny,.116)],[(0,1,2,3)],R.M[color],R.root)

def arrow(x,y,dx,dy,length=1.1):
    n=math.hypot(dx,dy);dx/=n;dy/=n
    mark('OneWayArrowShaft',[(x-dx*length/2,y-dy*length/2),(x+dx*length/2,y+dy*length/2)],.13)
    tip=(x+dx*(length/2+.45),y+dy*(length/2+.45),.119)
    back=(x+dx*(length/2-.12),y+dy*(length/2-.12))
    R.B.mesh('OneWayArrowHead',[tip,(back[0]-dy*.34,back[1]+dx*.34,.119),(back[0]+dy*.34,back[1]-dx*.34,.119)],[(0,1,2)],R.M['paint'],R.root)

def bay(x,y):
    # Nose points toward the front-left aisle; right-hand doors face rear platform.
    ux,uy=math.cos(ANGLE),math.sin(ANGLE);vx,vy=-uy,ux
    corners=[(x+ux*a+vx*b,y+uy*a+vy*b) for a,b in [(-5.575,-1.425),(5.575,-1.425),(5.575,1.425),(-5.575,1.425)]]
    mark('SawtoothBay',corners+[corners[0]],.07)
    mark('PlatformSafetyStripe',[(x-ux*5.575+vx*1.61,y-uy*5.575+vy*1.61),(x+ux*5.575+vx*1.61,y+uy*5.575+vy*1.61)],.08,'yellow')
    arrow(x-4.1,y-2.38,-ux,-uy,.6)

def full_canopy():
    # A single roof with real span supports avoids unnecessary hidden panel bevels.
    for x in [-23.7,-16,-8,0,8,16,23.7]:
        for y in [12.0,15.8]:
            R.box('CanopyColumn',(.15,.15,4.0),(x,y,2.2),'metal')
            R.box('ColumnFoot',(.28,.28,.10),(x,y,.25),'metal')
        R.box('CanopyCrossBeam',(.10,4.0,.14),(x,13.9,4.11),'metal')
    for y in [11.9,15.9]:R.box('CanopyLongBeam',(48,.15,.20),(0,y,4.1),'accent')
    R.box('WholePlatformCanopy',(48,4.2,.16),(0,13.9,4.23),'roof',.02)

def waiting_room():
    R.box('RearLobbyPaving',(22,4,.12),(0,18,.16),'paving',.01)
    R.box('WaitingRoomBody',(14,3.6,3.1),(0,18,1.77),'cream',.035)
    R.box('WaitingRoomRoof',(14.4,3.9,.16),(0,18,3.40),'roof',.02)
    for x in [-5.4,-3.6,3.6,5.4]:
        R.box('WaitingRoomGlass',(1.55,.025,2.08),(x,16.175,1.62),'glass')
        R.box('WindowTopTrim',(1.65,.045,.08),(x,16.16,2.70),'metal')
    for x in [-.57,.57]:R.box('WaitingRoomEntryDoor',(1.05,.045,2.30),(x,16.155,1.37),'glass')
    for x in [-1.16,0,1.16]:R.box('WaitingRoomDoorFrame',(.06,.06,2.38),(x,16.14,1.41),'metal')
    R.box('LobbySignBoard',(3.1,.08,.40),(0,16.14,2.96),'accent')
    R.text('BUS',0,16.09,2.82,.32)

def build():
    R.box('StationApron48x20',(48,20,.10),(0,10,.05),'asphalt',.01)
    # Entire front 3.5m remains an uninterrupted one-way lane.
    for x in [-20,-14,-8,-2,4,10,16,20]:arrow(x,1.75,-1,0)
    for x in [-21.5,21.5]:
        for dx in [-1.9,1.9]:R.box('EntryExitEdge',(.08,2.1,.008),(x+dx,1.05,.114),'paint')
        for k in range(3):R.box('EntryExitPavingMark',(.28,.64,.008),(x-1.2+k*1.2,.48,.114),'yellow')
    # Entry at right, exit at left, with directional arrows wholly inside apron.
    arrow(21.5,.9,0,1,.65);arrow(-21.5,.9,0,-1,.65)
    for x,y in CENTRES:bay(x,y)
    R.box('FullRearWaitingPlatform',(48,4.20,.12),(0,13.9,.16),'paving',.01)
    full_canopy();waiting_room()
    for x in [-18,-9,0,9,18]:R.bench(x,14.65,2.2)
    for x in [-21.5,21.5]:R.notice_board(x,15.72,1.9)
    R.box('RearBoundaryKerb',(48,.12,.22),(0,19.94,.11),'curb',.01)
    R.marker(22.3,12.9,'BUS',3.6)
    # Platform access steps are outside the bays, at both apron ends.
    for x in [-22,22]:R.box('PlatformApproach', (2.8,.8,.12),(x,11.4,.10),'paving',.01)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    out=args.output_root;source=out/'assets/facilities/bus-station-01/v2'
    if source.exists():raise RuntimeError('Protected v2 source exists: '+str(source))
    C.reset_scene();bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    R.root=C.empty('RoadEdgeFacilityRoot');R.root['asset_id']='bus-station-01';R.root['placement']='road_edge'
    R.M={k:B.material(k,c) for k,c in {'asphalt':'4c5659','paint':'e8e7dc','yellow':'e4bd5f','paving':'ded6bf','wood':'aa8059','metal':'344b53','curb':'c8cbc3','accent':'507c89','cream':'e2dcc8','roof':'526b70','glass':'91b1b9'}.items()}
    build();C.update();meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];tri=C.tri_count(meshes)
    points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices];lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)]
    assert 1500<=tri<=4000,(tri,lo,hi)
    assert abs(lo[0]+24)<.001 and abs(hi[0]-24)<.001 and abs(lo[1])<.001 and abs(hi[1]-20)<.001,(lo,hi)
    source.mkdir(parents=True);game=out/'cities_do/assets/facilities';game.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/'bus-station-01-v2.glb'),export_format='GLB',export_extras=True,export_animations=False)
    info=R.render(source/'preview.png',48,20,hi[2]);shutil.copy2(source/'preview.png',game/'bus-station-01-v2.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(source/'facility.blend'),compress=True)
    spec=json.loads((ROOT/'assets/facilities/bus-station-01/spec.json').read_text(encoding='utf-8'))
    spec.update({'width':12,'depth':5,'metres':[48,20],'width_m':48,'height_m':round(hi[2],4),'length_m':20,'inward_depth_m':20,'triangles':tri,'capacity':5,
        'model':'res://assets/facilities/bus-station-01-v2.glb','preview':'res://assets/facilities/bus-station-01-v2.png','source':'assets/facilities/bus-station-01/v2/facility.blend','render':info,
        'bay_angle_deg':30,'bay_dimensions_m':[11.15,2.85],'review_bus_centres_blender':[[x,y,.1] for x,y in CENTRES],
        'review_bus_yaw_godot_deg':-60,'one_way_aisle_width_m':3.5,'entry_exit_centres_blender':[[21.5,0,0],[-21.5,0,0]],
        'circulation_direction':'right entrance -> front one-way aisle (towards -X) -> left exit; sawtooth bays behind aisle',
        'waiting_platform_depth_m':4.2,'waiting_canopy_coverage_m':[48,4.2],'waiting_room_dimensions_m':[14,3.6,3.1],'supersedes':'bus-station-01 v1, originals retained',
        'not_validated':['live road attachment','bus swept turning envelopes','passenger simulation']})
    B.write_json(source/'spec.json',spec)
    (source/'build.py').write_text('import runpy\nfrom pathlib import Path\nroot=Path(__file__).resolve().parents[4]\nrunpy.run_path(str(root/"tools/build_bus_station_v2.py"),run_name="__main__")\n',encoding='utf-8')
    path=game/'catalog.json';doc=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'facilities':[]}
    doc['facilities']=[spec if e['id']=='bus-station-01' else e for e in doc['facilities']] if any(e['id']=='bus-station-01' for e in doc['facilities']) else doc['facilities']+[spec];B.write_json(path,doc)
    print('BUS_STATION_V2_BUILT',[48,20,round(hi[2],4)],'TRIANGLES',tri,flush=True)
if __name__=='__main__':main()
