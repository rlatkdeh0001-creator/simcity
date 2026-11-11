"""Asset-only service vehicles using the existing fleet's pinned zstack helpers.
blender -b --factory-startup -t 4 -P tools/build_service_vehicles_2.py [-- --only ID]
No GLB, directional sprites or runtime catalog writes.
"""
from pathlib import Path
import sys,json,math,argparse,importlib.util
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fleet_base',ROOT/'tools/build_vehicle_fleet.py');B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B);C=B.C
ROWS=[('garbage-truck-01','쓰레기차','waste',8.0,2.45,3.2),('ambulance-01','구급차','medical',5.9,2.1,2.6)]

def profile(name,poly,center,u,v,mat,root):
 center,u,v=Vector(center),Vector(u),Vector(v)
 return B.mesh(name,[tuple(center+u*a+v*b) for a,b in poly],[tuple(range(len(poly)))],mat,root)

def medical_mark(name,center,u,v,mats,root):
 for angle in [0,math.pi/3,2*math.pi/3]:
  c,s=math.cos(angle),math.sin(angle);shape=[(-.10,-.42),(.10,-.42),(.10,.42),(-.10,.42)]
  profile(name,[(a*c-b*s,a*s+b*c) for a,b in shape],center,u,v,mats['Blue'],root)
 n=Vector(u).cross(Vector(v)).normalized();shift=Vector(center)+n*.012
 profile(name+'_Staff',[(-.025,-.27),(.025,-.27),(.025,.27),(-.025,.27)],shift,u,v,mats['Cream'],root)

def recycle(center,u,v,mat,root):
 arrow=[(-.19,-.055),(.07,-.055),(.07,-.13),(.25,0),(.07,.13),(.07,.055),(-.19,.055)]
 for a in [math.pi/2,math.pi/2+math.tau/3,math.pi/2+2*math.tau/3]:
  cx,cy=.25*math.cos(a),.25*math.sin(a);rot=a+math.pi/2;c,s=math.cos(rot),math.sin(rot)
  profile('RecyclingArrow',[(cx+x*c-y*s,cy+x*s+y*c) for x,y in arrow],center,u,v,mat,root)

def cab(root,L,W,top,mats,van=False):
 front=-L/2;rear=front+(2.2 if not van else 2.1);cy=(front+rear)/2
 B.box('Chassis',(W*.70,L*.95,.22),(0,0,.56),mats['Dark'],root)
 if van:
  B.box('Cab',(W*.96,rear-front,.57),(0,cy,.965),mats['Paint'],root,.10)
  B.cabin('VanGreenhouse',W*.92,front+.4,rear-.05,1.25,top-.06,mats['Glass'],root,.40)
  B.box('VanRoof',(W*.76,.99,.10),(0,front+1.30,top-.04),mats['Paint'],root,.045)
  for side in [-1,1]:
   for bottom_y,upper_y in [(front+.4,front+.8),(rear-.05,rear-.31)]:
    pillar=C.tube('VanPillar',[(side*W*.46,bottom_y,1.25),(side*W*.377,upper_y,top-.06)],.04,segments=6);B.finish(pillar,mats['Paint'],root)
 else:
  B.box('Cab',(W*.96,rear-front,top-.68),(0,cy,(top+.68)/2),mats['Paint'],root,.10)
  B.box('Glass_Windscreen',(W*.83,.04,.78),(0,front-.022,top-.57),mats['Glass'],root,.035)
 for side in [-1,1]:
  if not van:B.box('SideWindow',(.03,1.15,.72),(side*W*.485,cy-.15,top-.58),mats['Glass'],root,.025)
  B.box('DoorHandle',(.025,.18,.045),(side*W*.49,cy+.28,top-1.05),mats['Metal'],root,.003)
  B.box('Mirror',(.13,.22,.15),(side*(W*.50+.06),front+.38,top-.60),mats['Dark'],root,.015)
  B.box('CabStep',(.10,.6,.08),(side*W*.48,cy+.2,.60),mats['Metal'],root,.005)
 B.box('FrontBumper',(W*.97,.12,.22),(0,front+.01,.68),mats['Cream'],root,.025)
 B.box('Grille',(W*.38,.035,.25),(0,front-.055,.99),mats['Dark'],root,.01)
 for x in [-W*.35,W*.35]:B.box('Headlamp',(W*.18,.035,.17),(x,front-.055,1.1),mats['Head'],root,.015)
 B.driver(root,W,front+.95,.92,mats)
 return rear

def garbage(root,L,W,H,m):
 cab_end=cab(root,L,W,2.66,m)
 B.box('CompactorBody',(W*.96,4.00,2.05),(0,.95,2.115),m['Paint'],root,.16)
 for side in [-1,1]:
  B.box('WhiteRouteStripe',(.025,4.1,.28),(side*W*.487,.95,1.56),m['Cream'],root,.005)
  B.box('CargoSidePanel',(.028,2.2,.95),(side*W*.490,.72,2.27),m['Paint'],root,.025)
  # Outward-facing geometry, never an external decal texture.
  recycle((side*(W*.50),.8,2.28),(0,side,0),(0,0,1),m['Cream'],root)
  for y in [-.72,2.63]:B.box('BodyStructuralRib',(.07,.12,1.88),(side*W*.48,y,2.10),m['Metal'],root,.015)
 # Rear hopper is recessed between a hood, side cheeks, and lower feed shelf.
 B.box('HopperShadow',(W*.76,.08,1.17),(0,3.57,1.94),m['Dark'],root,.025)
 B.box('HopperCanopy',(W*.94,1.05,.37),(0,3.40,2.96),m['Paint'],root,.12)
 for side in [-1,1]:
  B.box('HopperCheek',(.20,1.15,1.75),(side*W*.43,3.39,1.96),m['Paint'],root,.09)
 B.box('FeedTray',(W*.76,.66,.12),(0,3.65,1.29),m['Metal'],root,.025)
 pivot=C.empty('BinLiftPivot',(0,3.35,1.10));C.parent_keep(pivot,root);pivot['hingeAxisGltf']=[1.,0.,0.]
 for x in [-W*.31,W*.31]:
  bar=C.tube('BinLiftArm',[(x,3.20,.90),(x,3.90,1.42),(x,3.90,1.76)],.065,segments=6);B.finish(bar,m['Metal'],pivot)
 B.box('BinLiftCrossbar',(W*.68,.12,.12),(0,3.91,1.42),m['Metal'],pivot,.015)
 B.box('RearBumper',(W*.98,.15,.17),(0,3.94,.68),m['Cream'],root,.025)
 for x in [-W*.39,W*.39]:B.box('RearLamp',(.15,.035,.25),(x,4.024,.91),m['Tail'],root,.01)
 B.wheels(root,L,W,.43,-2.75,[1.9,2.85],m)
 for x in [-.52,.52]:B.box('AmberBeacon',(.22,.28,.16),(x,-2.65,2.77),m['Amber'],root,.035)

def ambulance(root,L,W,H,m):
 # Original Korean-style high-roof van silhouette; no brand or photo textures.
 # Each station: y, half-width, roof z. The body stays one continuous van shell.
 stations=[(-2.87,.87,1.12),(-2.55,1.00,1.32),(-1.86,1.04,1.46),(-.99,1.05,2.18),(2.67,1.05,2.18),(2.88,.97,2.08)]
 verts=[]
 for y,w,z in stations:
  shoulder=min(1.36,z-.08)
  verts.extend([(x,y,h) for x,h in [(-w+.08,.57),(w-.08,.57),(w,.67),(w,shoulder),(w-.10,z),(-w+.10,z),(-w,shoulder),(-w,.67)]])
 faces=[tuple(range(8)),tuple(reversed(range((len(stations)-1)*8,len(stations)*8)))]
 for i in range(len(stations)-1):
  for j in range(8):faces.append((i*8+j,(i+1)*8+j,(i+1)*8+(j+1)%8,i*8+(j+1)%8))
 body=B.mesh('VanBody',verts,faces,m['Cream'],root)
 # Cut actual wheel openings instead of burying the tyres inside a solid slab.
 for y in [-1.87,1.89]:
  cutter=B.cylinder('WheelArchCutter',.465,3.0,(0,y,.38),m['Dark'],root,axis='X',segments=24)
  mod=body.modifiers.new('WheelOpening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
  bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
 B.box('Chassis',(W*.68,L*.88,.14),(0,0,.48),m['Dark'],root,.015)
 B.mesh('Glass_Windscreen',[(-.85,-1.80,1.515),(.85,-1.80,1.515),(.85,-1.055,2.133),(-.85,-1.055,2.133)],[(0,1,2,3)],m['Glass'],root)
 # A gently chamfered raised medical roof sits on the van, rather than a cargo truck box.
 B.box('HighRoof',(1.87,3.72,.39),(0,.77,2.325),m['Cream'],root,.15)
 B.box('RoofFrontFairing',(1.75,.46,.21),(0,-1.10,2.245),m['Cream'],root,.09)
 for side,label in [(1,'L'),(-1,'R')]:
  def glass(name,poly):
   return B.mesh(name,[(side*(1.05-.10*(z-1.36)/.82+.012),y,z) for y,z in poly],[tuple(range(len(poly)))],m['Glass'],root)
  glass('DriverWindow_'+label,[(-1.69,1.49),(-1.025,2.075),(-.26,2.075),(-.26,1.49)])
  glass('MedicalSideWindow_'+label,[(-.13,1.50),(-.13,2.075),(1.04,2.075),(1.04,1.50)])
  glass('RearSideWindow_'+label,[(1.19,1.50),(1.19,2.075),(2.53,2.075),(2.53,1.50)])
  # Reflection band follows the body above the arches; lower small blocks stay clear of tyres.
  B.box('ReflectorStripe_'+label,(.025,4.93,.22),(side*1.058,.20,1.22),m['Orange'],root,.004)
  B.box('LowerReflector_'+label,(.028,2.72,.16),(side*1.054,.01,.88),m['Tail'],root,.004)
  B.box('CabDoorSeam_'+label,(.018,.018,.78),(side*1.055,-.205,.96),m['Metal'],root,.002)
  B.box('SlidingDoorRail_'+label,(.022,2.49,.028),(side*1.057,1.36,1.38),m['Metal'],root,.003)
  for y in [-.42,.28]:B.box('DoorHandle_'+label,(.035,.20,.045),(side*1.075,y,1.39),m['Dark'],root,.008)
  # Side medical symbol is on a small white panel over the window, leaving window margins visible.
  B.box('MedicalBadgePanel_'+label,(.028,.92,.85),(side*1.043,1.83,1.78),m['Cream'],root,.025)
  medical_mark('MedicalStarSide',(side*1.062,1.83,1.78),(0,side,0),(0,0,1),m,root)
  # Solid mounting pad overlaps the metal door; the arm embeds into pad AND mirror housing.
  B.box('MirrorMount_'+label,(.095,.19,.16),(side*1.035,-1.39,1.41),m['Dark'],root,.018)
  pts=[(side*1.035,-1.39,1.41),(side*1.18,-1.42,1.48),(side*1.25,-1.47,1.55)]
  arm=C.tube('MirrorArm_'+label,pts,.035,segments=8);B.finish(arm,m['Dark'],root);arm['mount_points_m']=[v for p in pts for v in p]
  B.box('MirrorHousing_'+label,(.18,.31,.24),(side*1.25,-1.47,1.57),m['Dark'],root,.035)
  B.box('MirrorGlass_'+label,(.12,.014,.17),(side*1.26,-1.308,1.58),m['Metal'],root,.012)
 # Fictional grille, tall headlamps, bonnet seam: the reference's design cues without its branding.
 B.box('FrontBumper',(1.88,.18,.20),(0,-2.88,.70),m['Tail'],root,.055)
 B.box('Grille',(1.13,.035,.26),(0,-2.889,1.005),m['Dark'],root,.045)
 for z in [.94,1.02,1.10]:B.box('GrilleSlat',(1.0,.016,.018),(0,-2.912,z),m['Metal'],root,.003)
 for side in [-1,1]:
  B.mesh('HeadlampHousing',[(side*.62,-2.54,1.332),(side*.88,-2.54,1.332),(side*.91,-2.06,1.4294),(side*.75,-2.06,1.4294)],[(0,1,2,3)],m['Dark'],root)
  B.mesh('Headlamp',[(side*.65,-2.51,1.3451),(side*.86,-2.51,1.3451),(side*.89,-2.09,1.4303),(side*.77,-2.09,1.4303)],[(0,1,2,3)],m['Head'],root)
  B.box('FogLamp',(.19,.035,.075),(side*.64,-2.985,.72),m['Head'],root,.015)
  B.box('RearTailLamp',(.13,.065,.46),(side*.90,2.905,1.11),m['Tail'],root,.025)
 B.box('RearBumper',(1.98,.15,.15),(0,2.94,.61),m['Dark'],root,.025)
 for x in [-.46,.46]:
  B.box('RearWindow',(.75,.026,.54),(x,2.893,1.77),m['Glass'],root,.04)
  B.box('RearDoorHandle',(.055,.03,.17),(x*.19,2.916,1.23),m['Metal'],root,.01)
 B.box('RearDoorSeam',(.016,.018,1.36),(0,2.914,1.34),m['Metal'],root,.002)
 B.box('RearReflector',(1.83,.025,.22),(0,2.922,.97),m['Orange'],root,.005)
 medical_mark('MedicalStarRear',(0,2.933,1.74),(-1,0,0),(0,0,1),m,root)
 B.box('LightbarBase',(1.47,.32,.065),(0,-.74,2.525),m['Metal'],root,.018)
 for x,paint in [(-.47,'Blue'),(.47,'Tail')]:B.box('EmergencyLight',(.42,.28,.075),(x,-.74,2.5625),m[paint],root,.025)
 for side in [-1,1]:B.box('RearEmergencyLight',(.19,.04,.10),(side*.66,2.625,2.415),m['Tail'],root,.018)
 B.driver(root,W,-.84,.94,m);B.wheels(root,L,W,.38,-1.87,[1.89],m)

def geometry():
 bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();points=[];tri=0
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  e=o.evaluated_get(dep);mesh=e.to_mesh();tri+=sum(len(p.vertices)-2 for p in mesh.polygons);points.extend(e.matrix_world@v.co for v in mesh.vertices);e.to_mesh_clear()
 lo=[min(v[i] for v in points) for i in range(3)];hi=[max(v[i] for v in points) for i in range(3)]
 return lo,hi,tri

def studio(L,W,H):
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=False
 scene.render.resolution_x=1000;scene.render.resolution_y=700;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard'
 scene.world=bpy.data.worlds.new('StudioWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.80,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
 ld=bpy.data.lights.new('Key','AREA');ld.energy=1100;ld.shape='DISK';ld.size=7;o=bpy.data.objects.new('Key',ld);scene.collection.objects.link(o);o.location=(5,-6,9);o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
 cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);scene.collection.objects.link(cam);scene.camera=cam;cd.type='ORTHO';diagonal=math.hypot(L,W);cd.ortho_scale=max(diagonal,(diagonal*.5+H*.866)*1000/700)*1.16
 return cam,Vector((0,0,H*.48))

def build(row):
 ident,name,style,L,W,H=row;C.reset_scene();scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
 root=C.empty('VehicleRoot');root['asset_id']=ident;root['units']='metres';root['forwardGltf']=[0.,0.,1.]
 colors={'Paint':'608873' if style=='waste' else 'e4e8df','Cream':'e4e8df','Glass':'294453','Dark':'30383b','Tyre':'242a2c','Metal':'75868c','Head':'f3e9bb','Tail':'c95343','Blue':'387cb8','Orange':'d7874d','Amber':'dfae4f'}
 mats={k:B.material(k,v,.25 if k=='Metal' else 0) for k,v in colors.items()}
 (garbage if style=='waste' else ambulance)(root,L,W,H,mats)
 lo,hi,tri=geometry();assert 2000<=tri<=5000,(ident,tri)
 assert abs(lo[2])<.001 and hi[2]<= (3.3 if style=='waste' else 3.4),(ident,lo,hi)
 out=ROOT/'assets/vehicle-fleet'/ident;out.mkdir(parents=True,exist_ok=True)
 data={'id':ident,'name':name,'category':'service','style':style,'length_m':L,'width_m':W,'height_m':H,'dimensions_source':'fictional game design; nominal body envelope excludes mirrors, lamps and roof accessories','frame_blender':{'forward':'-Y','left':'+X','up':'+Z'},'frame_gltf':{'forward':'+Z','left':'+X','up':'+Y'},'triangles':tri,'driver_side':'left','reconstruction':'new service asset','not_validated':['reference IoU','door opening','traffic AI','large-fleet performance','crash deformation'],'vertex_bounds_m':[lo,hi],'measured_dimensions_m':[hi[1]-lo[1],hi[0]-lo[0],hi[2]-lo[2]],'full_accessory_height_m':hi[2],'height_limit_m':3.3 if style=='waste' else 3.4,'wheel_count':len([o for o in scene.objects if o.name.startswith('Wheel_') and o.name.endswith('_Spin')]),'game_registered':False,'source_skill':'zstack/vehicle; 74f7786e9931b9ced858a0e2df880f23e4c2430e; MIT','preview':'preview.png','rear_review':'rear-review.png'}
 B.write_json(out/'spec.json',data)
 cam,target=studio(L,W,H)
 def aim(x,y):
  cam.location=target+Vector((x,y,15*math.tan(math.radians(30))));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 aim(15/math.sqrt(2),-15/math.sqrt(2));bpy.ops.wm.save_as_mainfile(filepath=str(out/'vehicle.blend'),compress=False)
 scene.render.filepath=str(out/'preview.png');bpy.ops.render.render(write_still=True)
 aim(-15/math.sqrt(2),15/math.sqrt(2));scene.render.filepath=str(out/'rear-review.png');bpy.ops.render.render(write_still=True)
 print('SERVICE_DONE',ident,data['measured_dimensions_m'],tri,flush=True)
 return data

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--only',choices=[r[0] for r in ROWS]);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 for row in ROWS:
  if not a.only or a.only==row[0]:build(row)
