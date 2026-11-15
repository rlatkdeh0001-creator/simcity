"""Read-only shared-skin, scale, attachment, foot plant and animation closure checks."""
from pathlib import Path
import bpy,json,math,hashlib,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/citizens/adult-pilot-01';DOC=ROOT/'docs/citizen-adult-pilot';m=json.loads((OUT/'spec.json').read_text());source=OUT/'citizen.blend';before=hashlib.sha256(source.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(source));rig=bpy.data.objects['CitizenRig'];parts=[bpy.data.objects[p] for p in m['layers']];tri={o.name:sum(len(p.vertices)-2 for p in o.data.polygons) for o in parts}
checks={'four_mesh_parts':len([o for o in bpy.context.scene.objects if o.type=='MESH'])==4,'one_armature_14_bones':len([o for o in bpy.context.scene.objects if o.type=='ARMATURE'])==1 and len(rig.data.bones)==14,'all_share_one_skin':all(len(o.modifiers)==1 and o.modifiers[0].type=='ARMATURE' and o.modifiers[0].object==rig for o in parts),'all_vertices_weighted_normalized':all(abs(sum(g.weight for g in v.groups)-1)<.00001 for o in parts for v in o.data.vertices),'no_unknown_bone_groups':all(g.name in rig.data.bones for o in parts for g in o.vertex_groups),'one_gray_material_each':all(len(o.data.materials)==1 and len(set(o.data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value[:3]))==1 for o in parts),'no_external_images':not any(im.source=='FILE' for im in bpy.data.images),'triangles_within_1500':sum(tri.values())<=1500,'triangle_counts_metadata':tri==m['triangles_by_layer'] and sum(tri.values())==m['triangles_total'],'metres':bpy.context.scene.unit_settings.system=='METRIC' and bpy.context.scene.unit_settings.scale_length==1,'two_actions':all(bpy.data.actions.get(n) for n in ['Idle','Walk']),'loop_modifier_on_every_walk_curve':all(any(mod.type=='CYCLES' for mod in f.modifiers) for f in bpy.data.actions['Walk'].fcurves),'no_duplicate_endpoint_in_playback':bpy.context.scene.frame_start==1 and bpy.context.scene.frame_end==16}

def vertices(action,frame):
 rig.animation_data.action=bpy.data.actions[action];bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();result={}
 for o in parts:
  e=o.evaluated_get(dep);mesh=e.to_mesh();result[o.name]=np.array([tuple(e.matrix_world@v.co) for v in mesh.vertices]);e.to_mesh_clear()
 return result
idle=vertices('Idle',1);allidle=np.concatenate(list(idle.values()));lo=allidle.min(axis=0);hi=allidle.max(axis=0);checks['idle_height_175']=abs(hi[2]-lo[2]-1.75)<.00001;checks['sole_ground_zero']=abs(lo[2])<.00001
sole_indices=sum(m['shoe_vertex_indices'].values(),[]);soles=idle['bottom'][sole_indices];checks['sole_pair_center_xy_origin']=np.max(np.abs((soles.min(axis=0)+soles.max(axis=0))[:2]/2))<.00001
# Geometry interfaces are deliberately overlapped, not merely aligned at one edge.
overlap=max(v.co.z for v in bpy.data.objects['bottom'].data.vertices)-min(v.co.z for v in bpy.data.objects['top'].data.vertices);checks['shirt_overlaps_waist_7cm']=abs(overlap-.07)<.00001
body=bpy.data.objects['body'].data;pending=set(range(len(body.vertices)));components=[]
while pending:
 seed=pending.pop();group={seed};stack=[seed]
 while stack:
  current=stack.pop()
  for edge in body.edges:
   if current in edge.vertices:
    for other in edge.vertices:
     if other in pending:pending.remove(other);group.add(other);stack.append(other)
 components.append([body.vertices[i].co.z for i in group])
upper=sorted(components,key=lambda c:max(c),reverse=True)[:2];checks['neck_head_overlap']=min(max(c) for c in upper)>max(min(c) for c in upper)
checks['hair_wraps_head']=max(v.co.z for v in bpy.data.objects['hair'].data.vertices)>max(v.co.z for v in bpy.data.objects['body'].data.vertices)
poses=[];geometry=[]
for number,frame in enumerate([1,5,9,13]):
 data=vertices('Walk',frame);geometry.append(np.concatenate(list(data.values())));sole_min={side:float(data['bottom'][indices,2].min()) for side,indices in m['shoe_vertex_indices'].items()};root=rig.pose.bones['root'];pelvis=rig.pose.bones['pelvis'];poses.append(dict(frame=frame,sole_min_z=sole_min,root_location=list(root.location),pelvis_world_y=float((rig.matrix_world@pelvis.head).y)))
checks['all_four_poses_feet_not_below_ground']=all(min(p['sole_min_z'].values())>=-.00001 for p in poses)
checks['one_planted_foot_each_pose']=all(abs(min(p['sole_min_z'].values()))<.00001 for p in poses)
checks['root_stationary']=all(max(abs(c) for c in p['root_location'])<.00001 and abs(p['pelvis_world_y'])<.00001 for p in poses)
closure=vertices('Walk',17);first=vertices('Walk',1);closure_error=float(max(np.max(np.abs(first[p]-closure[p])) for p in m['layers']));checks['walk_frame17_exactly_frame1']=closure_error<.00001
steps=[float(np.linalg.norm(geometry[(i+1)%4]-geometry[i],axis=1).max()) for i in range(4)];checks['wrap_step_not_an_outlier']=steps[-1]<=max(steps[:3])*1.10
checks['four_distinct_walk_poses']=all(np.max(np.abs(geometry[i]-geometry[j]))>.005 for i in range(4) for j in range(i))
manifest=json.loads((DOC/'render-manifest.json').read_text());checks['100_render_records']=len(manifest['images'])==100;checks['every_anchor_32_84']=all(max(abs(a-b) for a,b in zip(r['foot_anchor_px'],m['foot_anchor_px']))<.001 for r in manifest['images']);checks['every_camera_40px_per_metre']=all(abs(r['pixels_per_metre']-m['pixels_per_meter'])<.001 for r in manifest['images']);checks['source_never_saved_in_validation']=hashlib.sha256(source.read_bytes()).hexdigest()==before
checks={key:bool(value) for key,value in checks.items()}
result=dict(checks=checks,passed=all(checks.values()),triangles_by_layer=tri,bone_count=len(rig.data.bones),idle_bounds_m=[lo.tolist(),hi.tolist()],poses=poses,closure_max_vertex_error_m=closure_error,cyclic_max_step_displacements_m=steps,source_sha256=before)
(DOC/'rig-validation.json').write_text(json.dumps(result,indent=2)+'\n');print('RIG_CHECKS',checks,flush=True);assert all(checks.values());print('RESULT',len(checks),'rig/camera checks passed',flush=True)
