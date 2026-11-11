"""Check only signs 10/13/14 against the original asset commit; read-only models."""
import bpy,json,hashlib,subprocess,tempfile
from pathlib import Path
from mathutils import Vector
r=Path(__file__).resolve().parents[1];ids=['medium-2x2-electronics-02','small-4x4-logistics-01','small-4x4-metalshop-02'];rows=[]
before_ref='491784a0791783b91c2310855d8d4559d1a95ebd'
temporary=tempfile.TemporaryDirectory(prefix='cities-sign-before-')
for ident in ids:
 old=Path(temporary.name)/(ident+'.blend')
 old.write_bytes(subprocess.check_output(['git','show',before_ref+':assets/industrial-growth/'+ident+'/'+ident+'.blend'],cwd=r))
 variants={}
 for version,path in [('before',old),('after',r/f'assets/industrial-growth/{ident}/{ident}.blend')]:
  bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update();scene=bpy.context.scene;dg=bpy.context.evaluated_depsgraph_get();direction=scene.camera.matrix_world.to_quaternion()@Vector((0,0,1));non_sign=[];total=0;visible=0
  for obj in scene.objects:
   if obj.type not in ['MESH','FONT']:continue
   eval=obj.evaluated_get(dg);mesh=eval.to_mesh()
   if obj.type=='FONT':
    for poly in mesh.polygons:
     normal=eval.matrix_world.to_3x3()@poly.normal
     if normal.dot(direction)<.5:continue
     point=eval.matrix_world@poly.center
     hit,loc,norm,idx,hitobj,matrix=scene.ray_cast(dg,point+direction*100,-direction,distance=100.05)
     total+=1
     if hit and hitobj.name==obj.name:visible+=1
   elif 'SignBacking' not in obj.name:
    points=sorted(tuple(round(v,5) for v in eval.matrix_world@p.co) for p in mesh.vertices)
    non_sign.append((obj.name,points,[mat.name for mat in mesh.materials]))
   eval.to_mesh_clear()
  digest=hashlib.sha256(json.dumps(sorted(non_sign),sort_keys=True).encode()).hexdigest()
  variants[version]={'visible_letter_faces':visible,'tested_letter_faces':total,'visible_fraction':visible/max(1,total),'non_sign_geometry_sha256':digest}
 backing=[o for o in scene.objects if 'SignBacking' in o.name]
 assert len(backing)==1
 textobj=next(o for o in scene.objects if o.type=='FONT')
 def luminance(o):
  color=o.data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value
  return .2126*color[0]+.7152*color[1]+.0722*color[2]
 bright=luminance(textobj);dark=luminance(backing[0]);ratio=(max(bright,dark)+.05)/(min(bright,dark)+.05)
 variants['after']['material_luminance_contrast_ratio']=ratio
 assert ratio>=4.5
 assert variants['after']['non_sign_geometry_sha256']==variants['before']['non_sign_geometry_sha256'],ident+' non-sign geometry changed'
 assert variants['after']['visible_fraction']>=.98,(ident,variants)
 rows.append({'id':ident,**variants,'non_sign_geometry_unchanged':True});print('SIGN_CHECK',ident,variants,flush=True)
out=r/'docs/growth-14/sign-fix-validation.json';out.write_text(json.dumps(rows,indent=2)+'\n')
print('RESULT 3/3 sign visibility and non-sign geometry preservation checks passed')
