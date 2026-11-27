"""Original ochre electric box locomotive. No diesel or streamlined nose.
Blender4.3.2; --output-root NEW_WORKSPACE reproduces without changing originals.
"""
import argparse,json,shutil,sys
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_vehicles as T
F=T.F;C=T.C
ID='train-loco-freight-01'
def main():
 p=argparse.ArgumentParser();p.add_argument('--output-root',type=Path,default=ROOT);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 out=a.output_root;src=out/'assets/vehicle-fleet'/ID/'v2';game=out/'cities_do/assets/vehicles'
 if src.exists():raise RuntimeError('Protected source exists')
 C.reset_scene();scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
 root=C.empty('VehicleRoot');root['asset_id']=ID;root['forwardGltf']=[0.,0.,1.];root['units']='metres'
 m={k:F.material(k,c,.25 if k=='Metal' else 0) for k,c in {'Paint':'a59160','Cream':'d6ccb5','Glass':'294453','Dark':'30383b','Metal':'9ba9ab','Running':'626e73','Louvre':'605b49','Head':'e8d69d','Tail':'c95343'}.items()}
 def box(n,size,pos,mat='Paint',bev=0):return F.box(n,size,pos,m[mat],root,bev)
 T.bogies(root,9,{**m,'Dark':m['Running']})
 box('ContinuousBoxBody',(2.94,8.94,2.15),(0,0,2.525),'Paint',.055)
 box('DarkUnderframe',(2.70,9,.18),(0,0,1.36),'Dark',.02)
 # Full-height constant-section roof with a genuine rear recess, not an overlaid panel.
 box('RoofForward',(3,6.1,.20),(0,-1.45,3.7),'Paint',.035)
 box('RoofRear',(3,1.3,.20),(0,3.85,3.7),'Paint',.035)
 for side in [-1,1]:box('RoofRecessRim',(.68,1.6,.20),(side*1.16,2.4,3.7),'Paint',.025)
 for end,label in [(-1,'Front'),(1,'Rear')]:
  for x in [-.67,.67]:
   box(label+'WindowSeal',(1.10,.025,.81),(x,end*4.475,3.05),'Dark',.035)
   box(label+'Windscreen',(1.0,.024,.70),(x,end*4.488,3.05),'Glass',.025)
   box(label+'Headlight' if end<0 else label+'Taillight',(.32,.025,.20),(x,end*4.4875,1.95),'Head' if end<0 else 'Tail',.025)
  box(label+'CreamWaistBand',(2.75,.02,.13),(0,end*4.48,2.35),'Cream')
 for side in [-1,1]:

  for y in [-3.7,3.7]:
   box('CabSideGlass',(.026,1.02,.70),(side*1.487, y,3.05),'Glass',.02)
  for y in [-2.75,2.75]:
   box('CabAccessDoor',(.02,.66,1.7),(side*1.48,y,2.3),'Cream',.015)
   box('DoorHandle',(.03,.16,.035),(side*1.485,y+.19,2.22),'Metal')
   for z in [1.18,1.38,1.58]:box('AccessStep',(.15,.65,.06),(side*1.4,y,z),'Metal')
  # One full machine-room ventilation field per side, not window-sized repeats.
  box('LargeMachineLouvrePanel',(.026,4.65,1.68),(side*1.481,0,2.55),'Dark')
  for z in [1.80+i*.14 for i in range(12)]:
   box('FullWidthVentilationBlade',(.035,4.52,.065),(side*1.482,0,z),'Louvre')
  box('HeavyElectricalCabinet',(.60,2.35,.65),(side*1.05,0,.94),'Running',.025)
  box('CabinetLatch',(.035,.18,.12),(side*1.365,0,.99),'Metal')
  for y in [-2.75,2.75]:
   T.tube('CrewHandrail',[(side*1.47,y-.40,1.55),(side*1.47,y-.40,2.85)],.025,m['Metal'],root,segments=6)
 for end in [-1,1]:
  # Split pilot leaves the centre coupling and its shank fully exposed.
  for x in [-.91,.91]:
   box('SplitProtectivePilot',(.94,.12,.55),(x,end*4.42,.97),'Running',.025)
   box('FrontCrewFootplate',(.55,.22,.07),(x,end*4.45,1.32),'Metal')
   T.tube('EndGrabRail',[(x-.24,end*4.49,1.55),(x+.24,end*4.49,1.55)],.022,m['Metal'],root,segments=6)
 box('RecessedPantographBase',(.9,1.2,.04),(0,2.4,3.65),'Dark',.01)
 for side in [-1,1]:T.tube('LowPantographArm',[(side*.32,1.86,3.67),(side*.32,2.4,3.77),(side*.32,2.98,3.67)],.012,m['Dark'],root,segments=6)
 box('PantographContactBar',(1.24,.10,.04),(0,2.4,3.78),'Dark',.006)
 C.update();tri,lo,hi=T.measure();dims=[hi[1]-lo[1],hi[0]-lo[0],hi[2]-lo[2]]
 assert 2000<=tri<=5000,(tri,dims)
 assert all(abs(x-y)<.001 for x,y in zip(dims,[10,3,3.8])) and abs(lo[2])<.001,(lo,hi)
 top=max((ob.matrix_world@v.co).z for ob in bpy.data.objects if ob.type=='MESH' and 'Pantograph' in ob.name for v in ob.data.vertices);assert abs(top-3.8)<.001
 src.mkdir(parents=True);game.mkdir(parents=True,exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(game/(ID+'-v2.glb')),export_format='GLB',export_extras=True,export_yup=True,export_animations=False)
 ppm=F.render_views(game/'sprites'/(ID+'-v2'),10,3,3.8);shutil.copy2(game/'sprites'/(ID+'-v2')/'045.png',src/'preview.png');bpy.ops.wm.save_as_mainfile(filepath=str(src/'vehicle.blend'),compress=True)
 spec={'id':ID,'version':'v2','supersedes':'train-loco-freight-01 v1 retained','name':'박스형 전기 화물 기관차','category':'rail_locomotive','style':'ochre_electric_box','body_length_m':9.,'overall_length_m':10.,'length_m':10.,'width_m':3.,'height_m':3.8,'measured_dimensions_lwh_m':[round(x,5) for x in dims],'triangles':tri,'traction':'electric','pantograph':'one low unit within roof recess, max z=3.8m','pantograph_count':1,'pantograph_top_z_m':round(top,5),'roof_recess_blender':{'x':[-.82,.82],'y':[1.6,3.2],'floor_z':3.6},'gauge_m':1.435,'rail_top_z_m':0,'coupler_height_m':1.,'coupler_anchors_blender':[[0,-4.5,1],[0,4.5,1]],'coupler_contact_heads_blender':[[0,-5,1],[0,5,1]],'coupled_body_gap_m':1.,'frame_blender':{'forward':'-Y','left':'+X','up':'+Z'},'frame_gltf':{'forward':'+Z','left':'+X','up':'+Y'},'status':'inspection_only','simulation_enabled':False,'model':'res://assets/vehicles/'+ID+'-v2.glb','source':'assets/vehicle-fleet/'+ID+'/v2/vehicle.blend','preview':'res://assets/vehicles/sprites/'+ID+'-v2/045.png','render':{'resolution':[430,245],'camera_elevation_deg':30,'angles_deg':list(range(0,360,45))},'reproduce':'blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/build_rail_freight_v2.py -- --output-root NEW_WORKSPACE'}
 F.write_json(src/'spec.json',spec)
 (src/'build.py').write_text('import runpy,sys\nfrom pathlib import Path\nr=Path(__file__).resolve().parents[4]\nrunpy.run_path(str(r/"tools/build_rail_freight_v2.py"),run_name="__main__")\n')
 for file,row in [('catalog.json',spec),('render_manifest.json',{'id':ID,'pixels_per_metre':ppm,'angles_deg':list(range(0,360,45))})]:
  path=game/file;doc=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'vehicles':[]};doc['vehicles']=[row if e['id']==ID else e for e in doc['vehicles']];F.write_json(path,doc)
 print('FREIGHT_BUILT',tri,dims,'pantograph_top',top,flush=True)
if __name__=='__main__':main()
