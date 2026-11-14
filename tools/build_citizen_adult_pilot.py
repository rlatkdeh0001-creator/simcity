"""Original neutral adult: four skinned grayscale meshes, one shared minimal skeleton.
blender -b --factory-startup -t 4 -P tools/build_citizen_adult_pilot.py
"""
from pathlib import Path
import bpy,math,json,sys
from mathutils import Vector,Quaternion
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/citizens/adult-pilot-01';OUT.mkdir(parents=True,exist_ok=True)
PARTS=['body','hair','top','bottom'];V={p:[] for p in PARTS};F={p:[] for p in PARTS};WEIGHTS={p:[] for p in PARTS};SHOE={}

def add(part,vs,fs,weights):
 start=len(V[part]);V[part].extend(vs);F[part].extend([tuple(start+i for i in face) for face in fs]);WEIGHTS[part].extend(weights if isinstance(weights,list) else [weights.copy() for _ in vs]);return list(range(start,len(V[part])))

def loft(part,rings,weights,segments=8):
 vs=[(cx+rx*math.cos(i*math.tau/segments),cy+ry*math.sin(i*math.tau/segments),z) for cx,cy,z,rx,ry in rings for i in range(segments)];n=segments
 faces=[tuple(reversed(range(n))),tuple(range((len(rings)-1)*n,len(rings)*n))]
 faces += [(k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i) for k in range(len(rings)-1) for i in range(n)]
 return add(part,vs,faces,[w.copy() for w in weights for _ in range(n)])

def ellipsoid(part,center,radii,bone,segments=8,latitudes=4):
 cx,cy,cz=center;rx,ry,rz=radii;vs=[(cx,cy,cz-rz)];faces=[]
 for j in range(1,latitudes):
  angle=-math.pi/2+math.pi*j/latitudes
  vs += [(cx+rx*math.cos(angle)*math.cos(i*math.tau/segments),cy+ry*math.cos(angle)*math.sin(i*math.tau/segments),cz+rz*math.sin(angle)) for i in range(segments)]
 vs.append((cx,cy,cz+rz));last=len(vs)-1
 faces += [(0,1+(i+1)%segments,1+i) for i in range(segments)]
 for j in range(latitudes-2):
  for i in range(segments):faces.append((1+j*segments+i,1+j*segments+(i+1)%segments,1+(j+1)*segments+(i+1)%segments,1+(j+1)*segments+i))
 faces += [(last,1+(latitudes-2)*segments+i,1+(latitudes-2)*segments+(i+1)%segments) for i in range(segments)]
 return add(part,vs,faces,{bone:1.0})

def shoe(side,x):
 # Symmetric combined sole bounds around world origin, z=0. No foot detail textures.
 vs=[(x+a,b,c) for a,b,c in [(-.057,-.125,0),(.057,-.125,0),(.057,.125,0),(-.057,.125,0),(-.055,-.125,.075),(.055,-.125,.075),(.048,.10,.12),(-.048,.10,.12)]]
 SHOE[side]=add('bottom',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],{'foot.'+side:1})

def meshes():
 # Skin only: head/neck/two mitten-like hands. No eyes/nose/mouth/ears/fingers.
 ellipsoid('body',(0,0,1.575),(.118,.105,.155),'head')
 loft('body',[(0,0,1.355,.053,.050),(0,0,1.485,.053,.050)],[{'head':1},{'head':1}])
 for side,sign in [('L',1),('R',-1)]:
  ellipsoid('body',(sign*.264,-.003,.884),(.037,.038,.069),'forearm.'+side,8,4)
 # Shirt covers the trouser waist by 7cm, sharing pelvis weights through the overlap.
 loft('top',[(0,0,.935,.159,.112),(0,0,1.04,.162,.108),(0,0,1.28,.194,.110),(0,0,1.385,.174,.098)],
      [{'pelvis':1},{'pelvis':.65,'spine':.35},{'spine':1},{'spine':1}])
 for side,sign in [('L',1),('R',-1)]:
  loft('top',[(sign*.195,0,1.345,.068,.073),(sign*.225,0,1.22,.063,.065),(sign*.245,0,1.10,.056,.056),(sign*.257,0,1.015,.049,.050),(sign*.264,0,.937,.044,.047)],
       [{'spine':.45,'upper_arm.'+side:.55},{'upper_arm.'+side:1},{'upper_arm.'+side:.5,'forearm.'+side:.5},{'forearm.'+side:1},{'forearm.'+side:1}])
 loft('bottom',[(0,0,.91,.149,.102),(0,0,1.005,.148,.102)],[{'pelvis':1},{'pelvis':1}])
 for side,x in [('L',.095),('R',-.095)]:
  loft('bottom',[(x,0,.955,.076,.088),(x,0,.73,.070,.074),(x,0,.52,.061,.065),(x,.022,.30,.051,.054),(x,.035,.105,.044,.047)],
       [{'pelvis':.4,'thigh.'+side:.6},{'thigh.'+side:1},{'thigh.'+side:.5,'shin.'+side:.5},{'shin.'+side:1},{'shin.'+side:.65,'foot.'+side:.35}])
  shoe(side,x)
 # Short unisex cap: wraps the sides/back, front hairline sits above the blank face.
 n=10;vs=[(0,0,1.75)]
 for ring in [1/3,2/3,1]:
  for i in range(n):
   a=i*math.tau/n;limit=math.acos(-.07*math.sin(a)/.17);t=limit*ring
   vs.append((.129*math.sin(t)*math.cos(a),.117*math.sin(t)*math.sin(a),1.58+.17*math.cos(t)))
 faces=[(0,1+i,1+(i+1)%n) for i in range(n)]
 for ring in range(2):
  for i in range(n):faces.append((1+ring*n+i,1+(ring+1)*n+i,1+(ring+1)*n+(i+1)%n,1+ring*n+(i+1)%n))
 for i in range(n):
  a=i*math.tau/n;limit=math.acos(-.07*math.sin(a)/.17);vs.append((.121*math.sin(limit)*math.cos(a),.108*math.sin(limit)*math.sin(a),1.58+.17*math.cos(limit)+.003))
 for i in range(n):faces.append((21+i,31+i,31+(i+1)%n,21+(i+1)%n))
 add('hair',vs,faces,{'head':1})

BONES=[('root',(0,0,0),(0,0,.12),None),('pelvis',(0,0,.92),(0,0,1.04),'root'),('spine',(0,0,1.04),(0,0,1.36),'pelvis'),('head',(0,0,1.36),(0,0,1.66),'spine')]
for side,x in [('L',.095),('R',-.095)]:
 sign=1 if x>0 else -1
 BONES += [('upper_arm.'+side,(sign*.205,0,1.335),(sign*.245,0,1.10),'spine'),('forearm.'+side,(sign*.245,0,1.10),(sign*.264,0,.925),'upper_arm.'+side),('thigh.'+side,(x,0,.94),(x,0,.52),'pelvis'),('shin.'+side,(x,0,.52),(x,.035,.10),'thigh.'+side),('foot.'+side,(x,.035,.10),(x,-.11,.045),'shin.'+side)]

def rotate(rig,name,angle):
 pb=rig.pose.bones[name];axis=pb.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0));pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion(axis,angle)

def pose(rig,phase=None):
 for pb in rig.pose.bones:pb.location=(0,0,0);pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(1,0,0,0);pb.scale=(1,1,1)
 if phase is None:return
 a=.30*math.cos(phase);knees={'L':.52*max(0,-math.sin(phase)),'R':.52*max(0,math.sin(phase))}
 for side,thigh,arm in [('L',-a,a*.85),('R',a,-a*.85)]:
  rotate(rig,'thigh.'+side,thigh);rotate(rig,'shin.'+side,knees[side]);rotate(rig,'foot.'+side,-thigh-knees[side]);rotate(rig,'upper_arm.'+side,arm);rotate(rig,'forearm.'+side,.12+.035*math.cos(phase))
 bpy.context.view_layer.update();ob=bpy.data.objects['bottom'];e=ob.evaluated_get(bpy.context.evaluated_depsgraph_get());me=e.to_mesh();minimum=min((e.matrix_world@me.vertices[i].co).z for side in ['L','R'] for i in SHOE[side]);e.to_mesh_clear()
 rig.pose.bones['pelvis'].location=rig.data.bones['pelvis'].matrix_local.to_3x3().inverted()@Vector((0,0,-minimum));bpy.context.view_layer.update()

def key(rig,frame):
 for pb in rig.pose.bones:
  pb.keyframe_insert('location',frame=frame);pb.keyframe_insert('rotation_quaternion',frame=frame)

def build():
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0;scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
 meshes();data=bpy.data.armatures.new('CitizenSkeleton');rig=bpy.data.objects.new('CitizenRig',data);scene.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for name,head,tail,parent in BONES:
  b=data.edit_bones.new(name);b.head=head;b.tail=tail
  if parent:b.parent=data.edit_bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True;triangles={}
 for part in PARTS:
  me=bpy.data.meshes.new(part);me.from_pydata(V[part],[],F[part]);me.update();ob=bpy.data.objects.new(part,me);scene.collection.objects.link(ob);ob.parent=rig
  mat=bpy.data.materials.new('mat_'+part+'_gray');mat.use_nodes=True;n=mat.node_tree.nodes['Principled BSDF'];n.inputs['Base Color'].default_value=(.72,.72,.72,1);n.inputs['Roughness'].default_value=.90;me.materials.append(mat)
  for face in me.polygons:face.use_smooth=False
  for bone in data.bones:ob.vertex_groups.new(name=bone.name)
  for index,weights in enumerate(WEIGHTS[part]):
   for bone,weight in weights.items():ob.vertex_groups[bone].add([index],weight,'REPLACE')
  modifier=ob.modifiers.new('SharedCitizenSkin','ARMATURE');modifier.object=rig;modifier.use_deform_preserve_volume=False
  triangles[part]=sum(len(face.vertices)-2 for face in me.polygons)
 assert sum(triangles.values())<=1500,triangles
 rig.animation_data_create();idle=bpy.data.actions.new('Idle');idle.use_fake_user=True;rig.animation_data.action=idle;pose(rig);key(rig,1)
 walk=bpy.data.actions.new('Walk');walk.use_fake_user=True;rig.animation_data.action=walk
 for index,frame in enumerate([1,5,9,13,17]):pose(rig,index*math.pi/2);key(rig,frame)
 for curve in walk.fcurves:
  for k in curve.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
  curve.modifiers.new('CYCLES')
 rig.animation_data.action=idle;scene.frame_set(1);bpy.context.view_layer.update();scene.frame_start=1;scene.frame_end=16;scene.render.fps=20
 rig['frame_blender']='forward -Y, up +Z, sole-pair center at origin';rig['shared_part_contract']='body/hair/top/bottom; one skeleton; unchanged origins across variants'
 meta=dict(id='adult-pilot-01',name='중성 성인 시민 시험형',height_m=1.75,height_reference='idle hair apex; soles z=0',triangles_by_layer=triangles,triangles_total=sum(triangles.values()),layers=PARTS,armature='CitizenRig',bones=[b[0] for b in BONES],bone_count=len(BONES),rest_bones={n:dict(head=h,tail=t,parent=p) for n,h,t,p in BONES},frame_blender=dict(forward='-Y',left='+X',up='+Z'),origin='center of combined soles in idle; (0,0,0)',actions=dict(idle='Idle',walk='Walk'),walk_sample_frames=[1,5,9,13],walk_closure_frame=17,cycle_seconds=.8,canvas_px=[64,96],pixels_per_meter=40,foot_anchor_px=[32,84],directions=dict(S=0,SE=45,E=90,NE=135,N=180),frames=['idle','1','2','3','4'],shoe_vertex_indices=SHOE,source='original scripted geometry and armature; no external models, textures, fonts or generation APIs',game_registered=False,not_validated=['game renderer integration','all future garment combinations','large-crowd performance','game camera calibration'])
 meta.update(archetype='adult-neutral',part_interface_version=1)
 sys.path.insert(0,str(ROOT/'tools'));import citizen_pilot_common as C;C.studio(scale=1);C.set_view('S');meta['pixels_per_meter']=C.PIXELS_PER_METRE;meta['canvas_px']=[C.WIDTH,C.HEIGHT];meta['foot_anchor_px']=list(C.ANCHOR)
 (OUT/'spec.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'citizen.blend'))
 print('CITIZEN_BUILT',triangles,'total',sum(triangles.values()),'bones',len(BONES),flush=True)
if __name__=='__main__':build()
