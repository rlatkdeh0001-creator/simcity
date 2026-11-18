"""Items11-13. Read-only reuse of approved members; isolated new originals.
Blender4.3.2 --background --python tools/build_center_structure_samples.py
Use -- --only ID to resume a missing sample. Never overwrites an original.
"""
import json,math,shutil,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_elevated_strips as E
import build_tunnel_sample as U
import build_transit_subway as S
OUTPUT=ROOT
F,C,T=E.F,E.C,E.T
TEMPLATES={}
IDS=['center-flyover-sample-01','center-flyover-sample-02','center-underpass-sample-01']
def height(x):return max(0,min(10,(144-abs(x))*10/128))
def template(ident):
 if ident in TEMPLATES:return TEMPLATES[ident]
 file='structure.blend' if ident=='viaduct-pier-01' else 'member.blend'
 with bpy.data.libraries.load(str(ROOT/'assets/structures'/ident/file),link=False) as (a,b):b.objects=a.objects
 result=[]
 for ob in b.objects:
  if ob.type=='MESH':
   data=ob.data.copy();data.transform(ob.matrix_world);result.append((ob.name.split('.')[0],data))
 for ob in b.objects:bpy.data.objects.remove(ob)
 TEMPLATES[ident]=result;return result

def member(ident,x,y,tag,warp):
 for name,data in template(ident):
  mesh=data.copy()
  for v in mesh.vertices:v.co=warp(name,v.co.copy())
  ob=bpy.data.objects.new(tag+'_'+name,mesh);bpy.context.scene.collection.objects.link(ob);ob.parent=E.ROOT_NODE

def wall(x,side,c,underground=False):
 def warp(n,v):
  v.x+=x;v.y+=side*(c/2-(.2 if n.startswith('Barrier') else .25))
  if underground:
   # Uncovered retaining wall: top remains at ground, bottom follows trench.
   v.z=max(v.z,-height(v.x)-.2)
  else:v.z=max(0,v.z+height(v.x))
  return v
 member('retaining-wall-01',x,0,'TrenchWall' if underground else 'RampRetaining',warp)

def deck(x,side,c):
 def warp(n,v):
  v.x+=x;v.y+=side*(c/2-(.2 if n.startswith('Barrier') else .25));v.z+=height(v.x);return v
 member('viaduct-side-01',x,0,'DeckSide',warp)

def pier(x,y):
 h=height(x)
 def warp(n,v):
  if n.startswith('PierShaft'):v.z=.3+(v.z-.3)*(h-4.3)/5.7
  elif n.startswith('PierCap'):
   v.z+=h-10
   # Sloped bearing face conforms to the underside, retaining the round head.
   v.z+=(height(x+v.x)-h)*max(0,min(1,(v.z-(h-4))/2))
  v.x+=x;v.y+=y;return v
 member('viaduct-pier-01',x,y,'Support',warp)

def wedge(n,a,b,y0,y1,z0,z1,t,mat):return U.wedge(n,a,b,y0,y1,z0,z1,t,mat)
def normal(n,a,b,y0,y1,top,mat):return wedge(n,a,b,y0,y1,top,top,.12 if mat!='line' else .002,mat)
def build(ident):
 global TEMPLATES
 src=OUTPUT/'assets/structures'/ident;dst=OUTPUT/'cities_do/assets/structures'/ident
 assert not src.exists() and not dst.exists(), 'Refusing overwrite: '+ident
 src.mkdir(parents=True);dst.mkdir(parents=True)
 bpy.ops.wm.read_factory_settings(use_empty=True);E.setup();TEMPLATES={};E.ROOT_NODE.name='CenterStructure';E.ROOT_NODE['frontGltf']=[0,0,1]
 E.M.update({k:F.material(k,v) for k,v in {'asphalt':'4c5659','shoulder':'c8cbc3','interior':'15181a','line':'e5dfc8','yellow':'d6b65c','fill':'7e9275'}.items()})
 wide=ident.endswith('02');under='underpass' in ident;w,c=(32,14) if wide else (20,7);aw=w*.875
 # Outer roadway strips and sidewalks retain their exact original coordinates.
 for side in [-1,1]:
  y0,y1=sorted([side*c/2,side*aw/2]);normal('GroundOuterAsphalt',-152,152,y0,y1,0,'asphalt')
  y0,y1=sorted([side*aw/2,side*w/2]);normal('OriginalSidewalk',-152,152,y0,y1,0,'shoulder')
  edge=side*(14 if wide else 7)
  normal('OriginalShoulderLine',-152,152,edge-.06,edge+.06,.003,'line')
  if wide:
   for x in range(-150,150,8):
    if abs(x)<14:continue
    normal('OriginalOuterLaneDivider',x,x+3,side*10.5-.06,side*10.5+.06,.003,'line')
 for a,b in [(-152,-144),(144,152)]:
  normal('NormalRoadCentre',a,b,-c/2,c/2,0,'asphalt')
  normal('NormalCentreLine',a,b,-.06,.06,.003,'yellow')
 # Full physical 128+32+128m centre route, closed solid floors and deck ends.
 for a in range(-144,144,4):
  b=a+4;ha,hb=height(a),height(b);za,zb=(-ha,-hb) if under else (ha,hb)
  if under:
   wedge('ClosedTrenchFloor',a,b,-c/2,c/2,za-.01,zb-.01,.19,'shoulder')
  elif max(ha,hb)<=5:
   ob=wedge('ClosedEmbankment',a,b,-c/2+.5,c/2-.5,za-.01,zb-.01,1,'fill')
   for v in ob.data.vertices:
    if v.co.z<min(za,zb)-.5:v.co.z=-.12
  else:wedge('ClosedDeckCore',a,b,-c/2+.5,c/2-.5,za-.3,zb-.3,1.7,'girder')
  wedge('ClosedSlab',a,b,-c/2+.5,c/2-.5,za-.01,zb-.01,.29 if not under else .01,'shoulder')
  inner=6.25 if wide else 3
  wedge('CentreAsphalt',a,b,-inner,inner,za,zb,.01,'asphalt')
  for yy in [-inner+.08,inner-.08]:wedge('CentreEdgeLine',a,b,yy-.045,yy+.045,za+.003,zb+.003,.002,'line')
  if wide:
   # Same barrier member, scaled across thickness only to approved centre0.5m.
   for n,data in template('viaduct-side-01'):
    if not n.startswith('Barrier'):continue
    mesh=data.copy()
    for v in mesh.vertices:v.co.x+=a+2;v.co.y*=1.25;v.co.z+=height(v.co.x)
    ob=bpy.data.objects.new('CentralBarrier_'+n,mesh);bpy.context.scene.collection.objects.link(ob);ob.parent=E.ROOT_NODE
   for yy in [-3.25,3.25]:
    if a%8==0:wedge('CentreLaneDivider',a,a+3,yy-.06,yy+.06,za+.003,height(a+3)+.003,.002,'line')
  else:wedge('CentreYellowLine',a,b,-.06,.06,za+.003,zb+.003,.002,'yellow')
  if not under:
   for side in [-1,1]:
    if max(ha,hb)<=5:wall(a+2,side,c)
    else:deck(a+2,side,c)
 # Ground median under the elevated portion, excluding the crossing road.
 positions=[]
 if not under:
  for a,b in [(-80,-10),(10,80)]:
   normal('Median',a,b,-c/2,c/2,0,'asphalt')
   for x in range(int(a)+2,int(b)-2,4):
    ob=normal('MedianHatch',x-.07,x+.07,-c/2+.3,c/2-.3,.004,'line')
    for v in ob.data.vertices:v.co.x+=v.co.y*.55
  for x in [-80,-48,-16,16,48,80]:
   for y in ([-3.5,3.5] if wide else [0]):pier(x,y);positions.append([x,y,0])
 else:
  # Exact mouth plane ±67.2, z=-6; closed cover begins behind each mouth.
  for sign in [-1,1]:
   # 76.8m exposed trench, final 0.8m member trimmed longitudinally.
   for start in [67.2]+list(range(68,144,4)):
    end=68 if start==67.2 else start+4
    for side in [-1,1]:
     def warp(n,v,start=start,end=end,sign=sign,side=side):
      v.x=sign*(start+(v.x+2)*(end-start)/4);v.y+=side*(c/2-(.2 if n.startswith('Barrier') else .25));v.z=max(v.z,-height(v.x)-.2);return v
     member('retaining-wall-01',0,0,'TrenchWall',warp)
   for off in [-1.5,1.5]:
    def portal_warp(n,v,off=off,sign=sign):
     xx=v.x*.75+off;limit=3.1 if n.startswith('Barrier') else 3
     return (sign*(67.45+v.y),max(-limit,min(limit,xx)),v.z)
    member('tunnel-portal-01',0,0,'Portal',portal_warp)
  E.box('CoverSlab',(134.4,7,.97),(0,0,-.515),'cap')
  E.box('CoverGround',(134.4,7,.03),(0,0,-.015),'fill')
  # Covered sides are finite closed walls; no open black void below the sample.
  for side in [-1,1]:
   for a in range(-64,64,4):
    z0,z1=-height(a)-.2,-height(a+4)-.2
    ob=wedge('CoveredWall',a,a+4,side*3.25-.25,side*3.25+.25,0,0,11,'wall')
    for v in ob.data.vertices:
     if v.co.z<0:v.co.z=-height(v.co.x)-.2
   for a,b in [(-67.2,-64),(64,67.2)]:
    ob=wedge('CoveredWallEnd',a,b,side*3.25-.25,side*3.25+.25,0,0,11,'wall')
    for v in ob.data.vertices:
     if v.co.z<0:v.co.z=-height(v.co.x)-.2
 # Recalculate closed faces; source libraries remain untouched.
 for ob in list(bpy.context.scene.objects):
  if ob.type=='MESH':
   bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
 C.update();tri,lo,hi=T.measure()
 assert abs(hi[0]-lo[0]-304)<.002 and abs(hi[1]-lo[1]-w)<.002,(lo,hi)
 bpy.ops.export_scene.gltf(filepath=str(dst/(ident+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(src/'sample.blend'),compress=True)
 render=S.studio(src/'preview.png',lo,hi);shutil.copy2(src/'preview.png',dst/(ident+'.png'))
 s={'id':ident,'name':{'center-flyover-sample-01':'중앙 고가차도 4차선 견본','center-flyover-sample-02':'중앙 고가차도 8차선 견본','center-underpass-sample-01':'중앙 지하차도 4차선 견본'}[ident],'kind':'structure_sample','status':'inspection_only','width':76,'depth':w/4,'metres':[304,w],'height_m':round(hi[2]-lo[2],4),'triangles':tri,'source':f'assets/structures/{ident}/sample.blend','model':f'res://assets/structures/{ident}/{ident}.glb','preview':f'res://assets/structures/{ident}/{ident}.png','bounds_blender_m':{'min':lo,'max':hi},'center_width_m':c,'inner_lane_width_m':3,'outer_lane_width_m':3.5,'outer_lane_centres_m':[-12.25,-8.75,8.75,12.25] if wide else [-5.25,5.25],'ramp_length_m':128,'road_grade':10/128,'flat_length_m':32,'normal_end_length_m':8,'deck_level_m':-10 if under else 10,'front_blender':'-Y','front_gltf':'+Z','map_placement_implemented':False,'components':['retaining-wall-01','tunnel-portal-01'] if under else ['viaduct-pier-01','viaduct-side-01','retaining-wall-01'],'component_specs':{'viaduct-pier-01':'assets/structures/viaduct-pier-01/v2/spec.json'} if not under else {},'render':render,'cross_road':'Inspection fixture only: width20m, x=-10..10; no sample footprint widening.'}
 if under:s.update(portal_road_z_m=-6,portal_mouth_top_z_m=-1.5,mouth_clear_road_m=4.5,portal_x_m=[-67.2,67.2],closed_floor_and_cover_ends=True)
 else:s.update(underdeck_clear_m=8,pier_positions_blender_m=positions)
 F.write_json(src/'spec.json',s)
 (src/'build.py').write_text('import runpy,sys\nfrom pathlib import Path\nsys.argv += ["--", "--only", "'+ident+'"]\nrunpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_center_structure_samples.py"),run_name="__main__")\n')
 cat=OUTPUT/'cities_do/assets/facilities/catalog.json';doc=json.loads(cat.read_text(encoding='utf-8'));assert not any(e['id']==ident for e in doc['facilities']);doc['facilities'].append(s);F.write_json(cat,doc)
 bpy.ops.wm.open_mainfile(filepath=str(src/'sample.blend'));C.update();assert T.measure()[0]==tri
 print('CENTER_BUILT_RELOADED',ident,tri,lo,hi,flush=True)

def main():
 global OUTPUT
 only=sys.argv[sys.argv.index('--only')+1] if '--only' in sys.argv else None
 if '--output-root' in sys.argv:
  OUTPUT=Path(sys.argv[sys.argv.index('--output-root')+1]).resolve()
  assert OUTPUT!=ROOT and not OUTPUT.exists(), 'Reproduction requires a new empty output path'
  cat=OUTPUT/'cities_do/assets/facilities/catalog.json';cat.parent.mkdir(parents=True)
  doc=json.loads((ROOT/'cities_do/assets/facilities/catalog.json').read_text(encoding='utf-8'))
  doc['facilities']=[e for e in doc['facilities'] if e['id'] not in IDS];F.write_json(cat,doc)
 for ident in IDS:
  if only is None or ident==only:build(ident)
if __name__=='__main__':main()
