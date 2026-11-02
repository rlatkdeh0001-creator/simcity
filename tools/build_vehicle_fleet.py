"""Blender 4.3+: reproducible stylized fleet, adapted from zstack helpers (MIT).

blender -b --factory-startup -t 2 -P tools/build_vehicle_fleet.py
Append -- --render to create 8-direction transparent sprites (Cycles CPU).
Append -- --only ID to rebuild one asset. No external API or Claude required.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.agents/skills/vehicle/blender'))
import common as C

# Original fictional design dimensions, not measured production vehicle replicas.
# id, Korean name, class, L/W/H metres, paint, style
FLEET = [
 ('bus-city-01','시내버스','bus',10.8,2.5,3.15,'417eaf','bus'),
 ('taxi-sedan-01','택시','taxi',4.65,1.82,1.5,'edb63c','taxi'),
 ('car-hatch-01','소형 해치백','civilian',3.65,1.64,1.49,'df7159','hatch'),
 ('car-compact-02','준중형 세단','civilian',4.35,1.76,1.43,'73a4aa','sedan'),
 ('car-sedan-03','중형 세단','civilian',4.85,1.87,1.48,'455d7e','sedan'),
 ('car-wagon-04','스테이션왜건','civilian',4.75,1.83,1.52,'80a18a','wagon'),
 ('car-crossover-05','크로스오버','civilian',4.35,1.82,1.65,'d6c6a2','crossover'),
 ('car-suv-06','대형 SUV','civilian',5.05,2.0,1.88,'617d72','suv'),
 ('car-coupe-07','스포츠쿠페','civilian',4.45,1.88,1.23,'b6524d','coupe'),
 ('car-minivan-08','패밀리 미니밴','civilian',4.95,1.9,1.85,'b9c8d3','minivan'),
 ('car-electric-09','전기 세단','civilian',4.7,1.86,1.45,'b8d5cf','electric'),
 ('car-pickup-10','레저 픽업','civilian',5.25,1.95,1.82,'bd8d60','pickup'),
 ('truck-box-01','소형 탑차','industrial',6.1,2.15,3.05,'e8d9bc','box'),
 ('truck-flatbed-02','평판트럭','industrial',7.4,2.35,2.85,'4d91a7','flatbed'),
 ('truck-fridge-03','냉동트럭','industrial',7.0,2.35,3.35,'c4dbe2','fridge'),
 ('truck-mixer-04','콘크리트 믹서','industrial',8.2,2.48,3.45,'d6ad57','mixer'),
 ('trailer-container-05','컨테이너 트레일러','industrial',15.5,2.5,3.9,'ba7157','container'),
 ('trailer-tanker-06','탱크 트레일러','industrial',14.6,2.5,3.7,'9daeb5','tanker'),
 ('truck-dump-07','중형 덤프트럭','industrial',7.25,2.4,3.0,'cda254','dump'),
 ('truck-heavy-dump-08','대형 덤프트럭','industrial',9.2,2.9,3.65,'c18948','heavy_dump'),
 ('fire-engine-01','소방차','service',7.6,2.35,2.95,'b94d43','fire'),
 ('police-car-01','경찰차','service',4.85,1.87,1.48,'e4e8df','police'),
 ('hearse-01','운구차','service',5.5,1.95,1.85,'39464c','hearse'),
]


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def material(name, color, metal=0):
    rgb = [int(color[i:i+2], 16)/255 for i in (0,2,4)]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    # Convert palette sRGB to linear for matching Blender/Godot rendering.
    bsdf.inputs['Base Color'].default_value = (*(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb),1)
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = .56
    return mat


def finish(ob, mat, parent):
    ob.data.materials.append(mat)
    # Flat broad surfaces with small bevels preserve the city's stylized finish.
    for p in ob.data.polygons:
        p.use_smooth = False
    C.parent_keep(ob, parent)
    return ob


def box(name, size, pos, mat, parent, bevel=.025):
    return finish(C.rounded_box(name,size,pos,bevel=bevel,segs=1),mat,parent)


def mesh(name, verts, faces, mat, parent):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    ob=bpy.data.objects.new(name,data);C.link(ob)
    return finish(ob,mat,parent)


def cabin(name, width, front, rear, bottom, top, mat, parent, rake=.25):
    # A closed trapezoidal greenhouse: bottom fore/aft, roof inset.
    verts=[]
    for z,w,a,b in [(bottom,width,front,rear),(top,width*.82,front+rake,rear-rake*.65)]:
        verts += [(-w/2,a,z),(w/2,a,z),(w/2,b,z),(-w/2,b,z)]
    return mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,parent)


def cylinder(name, radius, length, pos, mat, parent, axis='Y', segments=16):
    ob=C.revolve(name,[(radius,-length/2),(radius,length/2)],segments=segments,axis=axis,cap=True)
    ob.location=pos
    return finish(ob,mat,parent)


def wheels(root, L, W, radius, front, rears, mats, trailer=None):
    for index,y in enumerate([front]+rears):
        for side,x in [('L',W/2-.10),('R',-W/2+.10)]:
            label=('F' if index==0 else ('R' if index==1 else str(index)))+side
            owner=trailer if trailer and y>0 else root
            steer=C.empty('Wheel_'+label,(x,y,radius));C.parent_keep(steer,owner)
            steer['steerable']=index==0
            spin=C.empty('Wheel_'+label+'_Spin',(x,y,radius));C.parent_keep(spin,steer)
            spin['spinAxisGltf']=[1.,0.,0.]
            width=radius*.56
            tyre=C.revolve('Tyre_'+label,[(radius*.76,-width/2),(radius*.95,-width*.45),(radius,0),(radius*.95,width*.45),(radius*.76,width/2)],segments=16,axis='X',cap=True)
            tyre.location=(x,y,radius);finish(tyre,mats['Tyre'],spin)
            outward=1 if x>0 else -1
            cylinder('Rim_'+label,radius*.60,.035,(x+outward*width*.52,y,radius),mats['Metal'],spin,axis='X')
            cylinder('Hub_'+label,radius*.23,.05,(x+outward*width*.58,y,radius),mats['Dark'],spin,axis='X',segments=8)


def driver(root, W, y, z, mats):
    anchor=C.empty('Seat_FL',(.25*W,y,z));C.parent_keep(anchor,root)
    anchor['role']='left_hand_driver'
    box('DriverSeat',(.40,.38,.38),(.25*W,y,z+.1),mats['Dark'],anchor)
    ob=cylinder('SteeringWheel',.17,.035,(.25*W,y-.38,z+.48),mats['Dark'],root,axis='Y',segments=12)
    ob['driver_side']='left_positive_x'


def lamps(root,L,W,z,mats,front=None):
    front=-L/2 if front is None else front
    for x in [-W*.34,W*.34]:
        box('Lamp_Head', (W*.21,.04,.13),(x,front-.015,z),mats['Head'],root,.015)
        box('Lamp_Tail', (W*.17,.04,.13),(x,L/2+.015,z),mats['Tail'],root,.015)


def passenger(root,L,W,H,style,mats):
    radius=.29 if L<4 else (.39 if style in ['suv','pickup'] else .33)
    base=H*.57
    box('Body',(W,L,base-radius*.7),(0,0,(base+radius*.7)/2),mats['Paint'],root,.10)
    box('Sill',(W*.96,L*.9,.13),(0,0,radius*.85),mats['Dark'],root)
    front=-L*.18;rear=L*.27;rake=.40
    if style in ['hatch','wagon','suv','crossover','minivan']:rear=L*.43
    if style=='minivan':front=-L*.32;rake=.28
    if style=='suv':rake=.18
    if style=='coupe':front=-L*.12;rear=L*.25;rake=.52
    if style=='electric':front=-L*.24;rear=L*.34;rake=.52
    if style=='pickup':front=-L*.27;rear=L*.05;rake=.25
    cabin('Glass',W*.93,front,rear,base,H-.06,mats['Glass'],root,rake)
    roof_len=(rear-front)-rake*1.65
    box('Roof',(W*.78,max(.25,roof_len),.09),(0,(front+rear+rake*.35)/2,H-.045),mats['Paint'],root,.04)
    # Pillars on the window surface, following each greenhouse slope.
    for x in [-1,1]:
        for bottom_y,top_y in [(front,front+rake),((front+rear)/2,(front+rear+rake*.35)/2),(rear,rear-rake*.65)]:
            pillar=C.tube('WindowPillar',[(x*W*.466,bottom_y,base+.01),(x*W*.411,top_y,H-.06)],.028,segments=6)
            finish(pillar,mats['Paint'],root)
        box('DoorHandle',(.045,.15,.035),(x*W*.505,L*.08,base-.1),mats['Metal'],root,.005)
        box('Mirror',(.15,.22,.11),(x*(W/2+.055),front+.1,base+.15),mats['Paint'],root)
    if style=='pickup':
        bed_y=L*.30
        box('PickupBed',(W*.84,L*.40,.07),(0,bed_y,base-.10),mats['Dark'],root)
        for x in [-W*.46,W*.46]:box('BedRail',(.12,L*.42,.27),(x,bed_y,base+.02),mats['Paint'],root)
        box('Tailgate',(W,.10,.30),(0,L*.48,base+.02),mats['Paint'],root)
    if style in ['wagon','suv','crossover']:
        for x in [-W*.3,W*.3]:box('RoofRail',(.045,max(.3,roof_len*.85),.05),(x,(front+rear)/2,H+.025),mats['Metal'],root,.01)
    if style=='taxi':
        box('TaxiSign',(.62,.24,.18),(0,0,H+.08),mats['Head'],root)
        # Generic taxi checker band; no trademark.
        for x in [-W*.505,W*.505]:
            for k in range(7):box('TaxiChecker',(.015,.13,.09),(x,-.35+k*.15,base-.17),mats['Dark'] if k%2 else mats['Head'],root,.001)
    if style=='electric':box('ChargePort',(.02,.17,.14),(W*.505,L*.30,base-.13),mats['Dark'],root,.01)
    wheels(root,L,W,radius,-L*.31,[L*.30],mats)
    driver(root,W,front+.85,base-.25,mats)
    lamps(root,L,W,base-.16,mats)
    box('FrontGrille',(W*.4,.035,.13),(0,-L/2-.015,base-.16),mats['Dark'],root,.015)


def service(root,L,W,H,style,mats):
    if style=='fire':
        industrial(root,L,W,H,'box',mats)
        # Cream equipment body with silver roller shutters, matching the fleet palette.
        for side in [-1,1]:
            for y in [-.1,1.05,2.2]:
                box('EquipmentShutter',(.04,.92,1.20),(side*W*.493,y,1.85),mats['Metal'],root)
                for z in [1.4,1.65,1.9,2.15,2.4]:
                    box('ShutterSlat',(.05,.87,.025),(side*W*.50,y,z),mats['Dark'],root,.003)
            box('ReflectiveBand',(.055,L*.85,.13),(side*W*.50,0,1.10),mats['Head'],root)
        for x in [-.55,.55]:
            box('LadderRail',(.07,4.5,.10),(x,.85,H+.13),mats['Metal'],root)
        for y in [i*.35-1.2 for i in range(13)]:
            box('LadderRung',(1.1,.045,.045),(0,y,H+.13),mats['Metal'],root)
        cylinder('HoseReel',.36,.55,(-.7,2.7,H+.22),mats['Dark'],root,axis='X')
        light_y=-L*.32;light_z=H*.9+.13
    else:
        passenger(root,L,W,H,'wagon' if style=='hearse' else 'sedan',mats)
        if style=='hearse':
            # Extended covered rear compartment, curtains, discreet silver trim.
            box('RearCompartment',(W*.84,L*.46,.69),(0,L*.18,H-.44),mats['Paint'],root,.08)
            for side in [-1,1]:
                box('CurtainWindow',(.025,L*.38,.40),(side*W*.427,L*.18,H-.39),mats['Glass'],root)
                for i in range(10):
                    box('CurtainFold',(.03,.045,.32),(side*W*.433,-.06+i*.20,H-.39),mats['Cream'],root,.005)
                box('ChromeTrim',(.04,L*.82,.045),(side*W*.50,0,H*.54),mats['Metal'],root)
            return
        for side in [-1,1]:
            box('PoliceBlueBand',(.025,L*.87,.23),(side*W*.504,0,H*.46),mats['Blue'],root,.01)
            box('PoliceShield',(.035,.30,.32),(side*W*.515,0,H*.56),mats['Head'],root,.04)
        light_y=0;light_z=H+.13
    box('LightbarBase',(W*.67,.28,.09),(0,light_y,light_z),mats['Dark'],root)
    for x,mat in [(-W*.22,mats['Blue']),(W*.22,mats['Tail'])]:
        box('EmergencyLight',(.40,.25,.15),(x,light_y,light_z+.10),mat,root,.035)


def bus(root,L,W,H,mats):
    box('Body',(W,L,H-.48),(0,0,(H+.48)/2),mats['Paint'],root,.12)
    box('LowerBand',(W+.015,L+.02,.45),(0,0,.85),mats['Cream'],root,.04)
    box('Roof',(W*.98,L*.97,.16),(0,0,H),mats['Cream'],root,.08)
    for side in [-1,1]:
        for i in range(7):
            y=-L/2+1+i*1.35
            # Leave right-side front and middle passenger door bays clear.
            if side==-1 and i in [0,3]:continue
            box('Window',(.025,1.12,.94),(side*(W/2+.01),y,H-.72),mats['Glass'],root,.05)
    box('Glass_Windscreen',(W*.9,.035,1.0),(0,-L/2-.02,H-.76),mats['Glass'],root,.07)
    box('DestinationDisplay',(W*.66,.04,.25),(0,-L/2-.045,H-.16),mats['Dark'],root)
    box('RouteStripe',(W*.38,.015,.055),(0,-L/2-.07,H-.16),mats['Head'],root,.005)
    for y in [-L/2+.65,-.35]:
        for dy in [-.27,.27]:
            ob=box('PassengerDoor_R',(.04,.51,1.90),(-W/2-.025,y+dy,1.48),mats['Glass'],root,.02)
            ob['passenger_side']='right_negative_x'
        box('DoorStep',(.12,1.12,.12),(-W/2-.055,y,.43),mats['Metal'],root)
    box('HVAC',(1.3,2.1,.22),(0,1,H+.16),mats['Metal'],root,.06)
    wheels(root,L,W,.48,-L*.32,[L*.30],mats)
    driver(root,W,-L/2+.75,1.0,mats)
    lamps(root,L,W,.82,mats)


def industrial(root,L,W,H,style,mats):
    trailer=style in ['container','tanker']
    radius=.52 if style=='heavy_dump' else .44
    cab_len=2.7 if trailer else L*.31
    front=-L/2
    cab_y=front+cab_len/2
    cab_h=min(2.9,H*.9)
    box('Chassis',(W*.65,L*.97,.24),(0,0,radius+.06),mats['Dark'],root)
    box('Cab',(W*.96,cab_len,cab_h-.65),(0,cab_y,(cab_h+.65)/2),mats['Paint'],root,.12)
    box('Glass_Windscreen',(W*.86,.04,.68),(0,front-.025,cab_h-.60),mats['Glass'],root,.045)
    for side in [-1,1]:
        box('CabWindow',(.03,cab_len*.48,.65),(side*W*.485,cab_y-.12,cab_h-.61),mats['Glass'],root,.04)
        box('Mirror',(.16,.22,.30),(side*(W*.51),front+.25,cab_h-.55),mats['Dark'],root)
        box('CabStep',(.18,.65,.10),(side*W*.49,cab_y+.18,.61),mats['Metal'],root)
    driver(root,W,front+.8,1.0,mats)
    cargo_front=front+cab_len+.25
    cargo_len=L/2-cargo_front-.08
    center=cargo_front+cargo_len/2
    owner=root
    if trailer:
        owner=C.empty('TrailerHitch',(0,cargo_front+.25,.95));C.parent_keep(owner,root)
        owner['hingeAxisGltf']=[0.,1.,0.]
        box('TrailerFrame',(W*.70,cargo_len,.18),(0,center,.86),mats['Dark'],owner)
    if style in ['box','fridge','container']:
        box('CargoBox',(W*.97,cargo_len,H-1.02),(0,center,(H+1.02)/2),mats['Cream'] if style!='container' else mats['Paint'],owner,.04)
        for x in [-W*.26,W*.26]:box('CargoDoorBar',(.045,.04,H-1.28),(x,L/2, (H+1.08)/2),mats['Metal'],owner,.005)
        if style=='container':
            for y in range(int(cargo_len/.25)):
                for side in [-1,1]:box('ContainerRib',(.035,.055,H-1.10),(side*W*.49,cargo_front+.12+y*.25,(H+1.02)/2),mats['Paint'],owner,.005)
        if style=='fridge':
            box('RefrigerationUnit',(W*.63,.36,.65),(0,cargo_front-.15,H-.46),mats['Head'],owner)
            for x in [-.36,.36]:cylinder('CoolingFan',.22,.035,(x,cargo_front-.35,H-.46),mats['Dark'],owner,segments=12)
    elif style=='tanker':
        tank_len=cargo_len*.95;rad=W*.47;z=H-rad
        cylinder('Tank',rad,tank_len,(0,center,z),mats['Metal'],owner,segments=24)
        for y in [center-tank_len*.42,center+tank_len*.42]:
            # Flat caps slightly inset in end rings.
            cylinder('TankBand',rad*1.012,.08,(0,y,z),mats['Dark'],owner,segments=24)
        box('TankWalkway',(.4,tank_len*.85,.07),(0,center,H+.025),mats['Dark'],owner)
        for y in [center-1,center+1]:cylinder('TankHatch',.23,.09,(0,y,H+.1),mats['Metal'],owner,axis='Z')
    elif style=='mixer':
        spin=C.empty('MixerSpin',(0,center,2.05));C.parent_keep(spin,root)
        spin['spinAxisGltf']=[0.,0.,1.]
        ob=C.revolve('MixerDrum',[(.48,-cargo_len*.40),(.9,-cargo_len*.20),(1.0,cargo_len*.10),(.55,cargo_len*.37),(.28,cargo_len*.43)],segments=20,axis='Y',cap=True)
        ob.location=(0,center,2.05);finish(ob,mats['Cream'],spin)
        for y in [center-.65,center+.65]:cylinder('DrumBand',.91,.12,(0,y,2.05),mats['Paint'],spin,segments=20)
        box('DischargeChute',(.45,1.0,.18),(0,L*.45,1.4),mats['Metal'],root)
    else:
        if style in ['dump','heavy_dump']:
            owner=C.empty('DumpBedPivot',(0,L/2-.15,1.10));C.parent_keep(owner,root)
            owner['hingeAxisGltf']=[1.,0.,0.];owner['openLimit']=.75
        base=1.12;wall=.35 if style=='flatbed' else H-base
        box('BedFloor',(W,cargo_len,.16),(0,center,base),mats['Dark'],owner)
        for side in [-1,1]:
            box('BedWall',(.12,cargo_len,wall),(side*W*.47,center,base+wall/2),mats['Paint'],owner)
            for k in range(5):box('BedRib',(.045,.09,wall*.93),(side*W*.503,cargo_front+.25+k*(cargo_len-.5)/4,base+wall/2),mats['Cream'],owner,.01)
        for y in [cargo_front,L/2-.1]:box('BedEnd',(W,.12,wall),(0,y,base+wall/2),mats['Paint'],owner)
    rears=[L*.27]
    if style in ['mixer','dump','heavy_dump']:rears=[L*.19,L*.34]
    if trailer:rears=[front+3.55,L*.31,L*.39]
    wheels(root,L,W,radius,front+cab_len*.40,rears,mats,owner if trailer else None)
    lamps(root,L,W,.85,mats)
    box('Grille',(W*.40,.05,.38),(0,front-.025,1.12),mats['Dark'],root)


def render_views(out,L,W,H):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=24
    # The managed Blender build has no OpenImageDenoise support.
    scene.cycles.use_denoising=False
    scene.render.resolution_x=430;scene.render.resolution_y=245;scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.world=bpy.data.worlds.new('StudioWorld');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    scene.view_settings.view_transform='Standard'
    light_data=bpy.data.lights.new('Key','AREA');light_data.energy=1100;light_data.shape='DISK';light_data.size=7
    light=bpy.data.objects.new('Key',light_data);scene.collection.objects.link(light);light.location=(5,-6,9)
    light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
    camera_data=bpy.data.cameras.new('Camera');camera=bpy.data.objects.new('Camera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
    camera_data.type='ORTHO'
    # Fixed framing per vehicle across all azimuths; scale includes height + margins.
    diagonal=math.hypot(L,W)
    camera_data.ortho_scale=max(diagonal,(diagonal*.5+H*.866)*430/245)*1.16
    target=Vector((0,0,H*.48))
    out.mkdir(parents=True,exist_ok=True)
    for angle in range(0,360,45):
        a=math.radians(angle)
        # 000 sees the nose, Blender -Y. Positive azimuth moves toward vehicle left.
        camera.location=target+Vector((math.sin(a)*15,-math.cos(a)*15,15*math.tan(math.radians(30))))
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(out/f'{angle:03}.png');bpy.ops.render.render(write_still=True)
    return 430/camera_data.ortho_scale


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--render',action='store_true');parser.add_argument('--only',choices=[r[0] for r in FLEET])
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    entries=[];rendered=[]
    for ident,name,kind,L,W,H,color,style in FLEET:
        if args.only and ident!=args.only:continue
        C.reset_scene();scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
        root=C.empty('VehicleRoot');root['asset_id']=ident;root['forwardGltf']=[0.,0.,1.];root['units']='metres'
        mats={k:material(k,c, .25 if k=='Metal' else 0) for k,c in {'Paint':color,'Glass':'294453','Dark':'30383b','Tyre':'242a2c','Metal':'a6b4b7','Cream':'e3ded0','Head':'f3e9bb','Tail':'c95343','Blue':'387cb8'}.items()}
        if kind=='service':service(root,L,W,H,style,mats)
        elif kind in ['civilian','taxi']:passenger(root,L,W,H,style,mats)
        elif kind=='bus':bus(root,L,W,H,mats)
        else:industrial(root,L,W,H,style,mats)
        C.update()
        triangles=C.tri_count(list(scene.objects))
        spec={'id':ident,'name':name,'category':kind,'style':style,'length_m':L,'width_m':W,'height_m':H,'dimensions_source':'fictional game design; nominal body envelope excludes mirrors, lamps and roof accessories','frame_blender':{'forward':'-Y','left':'+X','up':'+Z'},'frame_gltf':{'forward':'+Z','left':'+X','up':'+Y'},'triangles':triangles,'driver_side':'left','reconstruction':('new 2026-11-03 service asset; reused fleet geometry helpers' if kind=='service' else 'new 2026-11-01 implementation; not recovered previous model'),'not_validated':['reference IoU','door opening','crash deformation','traffic AI','large-fleet performance']}
        source=ROOT/'assets/vehicle-fleet'/ident;source.mkdir(parents=True,exist_ok=True)
        write_json(source/'spec.json',spec)
        bpy.ops.wm.save_as_mainfile(filepath=str(source/'vehicle.blend'),compress=False)
        game=ROOT/'cities_do/assets/vehicles';game.mkdir(parents=True,exist_ok=True)
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(filepath=str(game/(ident+'.glb')),export_format='GLB',export_extras=True,export_yup=True,export_animations=False)
        entry={**spec,'model':'res://assets/vehicles/'+ident+'.glb'};entries.append(entry)
        if args.render:
            ppm=render_views(game/'sprites'/ident,L,W,H)
            rendered.append({'id':ident,'pixels_per_metre':ppm,'angles_deg':list(range(0,360,45))})
        print('FLEET_BUILT',ident,triangles,flush=True)
    if args.only:
        for filename, key, additions in [('catalog.json','vehicles',entries),('render_manifest.json','vehicles',rendered)]:
            path=ROOT/'cities_do/assets/vehicles'/filename
            if additions and path.exists():
                doc=json.loads(path.read_text())
                replacements={e['id']:e for e in additions}
                original_ids={e['id'] for e in doc[key]}
                doc[key]=[replacements.get(e['id'],e) for e in doc[key]]+[e for e in additions if e['id'] not in original_ids]
                write_json(path,doc)
    if not args.only:
        write_json(ROOT/'cities_do/assets/vehicles/catalog.json',{'schema_version':1,'vehicles':entries})
        if args.render:write_json(ROOT/'cities_do/assets/vehicles/render_manifest.json',{'resolution':[430,245],'camera_elevation_deg':30,'angle_zero':'nose view; positive camera azimuth towards left (+X Blender)','vehicles':rendered})
    write_json(ROOT/'assets/vehicle-fleet'/('last-build-'+args.only+'.json' if args.only else 'last-build.json'),entries)


if __name__=='__main__':main()
