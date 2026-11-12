"""Original source-only work tiles in the approved smooth-grain style.
blender -b --factory-startup -t 4 -P tools/build_primary_work_tiles.py [-- --only ID]
Grain sources are preserved byte-for-byte from 6afefd8, not rebuilt here.
"""
from pathlib import Path
import bpy,sys,math,json,importlib.util,argparse
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('primary_helpers',ROOT/'tools/build_primary_industry.py');P=importlib.util.module_from_spec(sp);sp.loader.exec_module(P);G=P.G
ROWS=[('primary-tile-vegetable-01','채소·과수 밭','farm_vegetable','vegetable'),('primary-tile-pasture-01','목초지·빈 풀밭','farm_livestock','pasture'),('primary-tile-pasture-02','목초지·소 좌측','farm_livestock','pasture_left'),('primary-tile-pasture-03','목초지·소 우측','farm_livestock','pasture_right'),('primary-tile-forestry-01','벌목지','forestry','forestry'),('primary-tile-mine-iron-01','철 채굴지','mine_iron','iron'),('primary-tile-mine-coal-01','석탄 채굴지','mine_coal','coal'),('primary-tile-oil-01','시추지·펌프잭','oil','oil'),('primary-tile-oil-02','시추지·빈 작업면','oil','oil_empty'),('primary-tile-mine-uranium-01','우라늄 채굴지','mine_uranium','uranium'),('primary-tile-fishing-01','어장','fishing','fishing')]
COLORS={'soil':'a69b7c','grass':'819362','cropgreen':'608a45','croplight':'7c9a56','orchard':'779554','bark':'89684b','cream':'ece5cc','cowdark':'49463e','ironsoil':'a7775b','ironrock':'9b533c','coalsoil':'65615a','coalrock':'333b39','oilsoil':'9e947c','steel':'596b66','yellow':'cfb45c','uransoil':'8f9388','net':'6b8883','buoy':'c98043','fruit':'bc8254'}

def box(name,loc,size,mat):return G.box(name,loc,size,mat,0)
def mesh(name,vs,faces,mat):return P.mesh(name,vs,faces,mat)
def cylinder(name,loc,r,h,mat,vertices=6):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(G.M[mat]);return o

def cone(name,loc,r,h,mat,vertices=6):
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=0,depth=h,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(G.M[mat]);return o

def bar(name,a,b,width,mat):
 d=Vector(b)-Vector(a);o=box(name,(Vector(a)+Vector(b))/2,(width,width,d.length),mat);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o

def ground(mat):box('TileGround',(0,0,-.06),(4,4,.12),mat)
def rock(name,x,y,z,r,h,mat):
 # A low faceted mound with a slightly offset crown, no tiny ore fragments.
 vs=[(x+r*math.cos(i*math.tau/6),y+r*math.sin(i*math.tau/6),z) for i in range(6)]+[(x+r*.10,y-r*.07,z+h)]
 return mesh(name,vs,[tuple(reversed(range(6)))]+[(i,(i+1)%6,6) for i in range(6)],mat)

def smooth_rows():
 for ix in range(4):
  x=-1.5+ix;r=.43;h=.32+.03*(ix%2)
  section=[(-r,.006)]+[(-r*math.cos(j*math.pi/6),.04+h*math.sin(j*math.pi/6)) for j in range(7)]+[(r,.006)];n=len(section)
  vs=[(x+xx,y,z) for y in [-2,2] for xx,z in section];faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
  ob=mesh('VegetableRibbon_%02d'%ix,vs,faces,'cropgreen' if ix%2 else 'croplight');normals=[]
  for poly in ob.data.polygons:
   poly.use_smooth=True
   for li in poly.loop_indices:
    vi=ob.data.loops[li].vertex_index%n
    if poly.index<2:normal=(0,-1 if poly.index==0 else 1,0)
    elif poly.index==2:normal=(-1,0,0)
    elif poly.index==n:normal=(1,0,0)
    elif poly.index==n+1:normal=(0,0,-1)
    else:
     a=max(0,min(6,vi-1))*math.pi/6;normal=Vector((-h*math.cos(a),0,r*math.sin(a))).normalized()
    normals.append(normal)
  ob.data.normals_split_custom_set(normals)

def tree(x,y,height,r=.5,young=False):
 cylinder('TreeTrunk',(x,y,height*.25),.055 if young else .10,height*.50,'bark',6)
 cone('TreeCrown',(x,y,height*.67),r,height*.66,'orchard',6)
 cone('TreeCrownTop',(x,y,height*.85),r*.68,height*.42,'croplight',6)

def vegetable():
 ground('soil');smooth_rows()
 cylinder('TreeTrunk',(1.28,.95,.49),.08,.98,'bark',6)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(1.28,.95,1.35));crown=bpy.context.object;crown.name='OrchardCrown';crown.scale=(.52,.52,.61);crown.data.materials.append(G.M['orchard'])
 for x,y in [(1.02,.91),(1.41,.72)]:rock('OrchardFruit',x,y,1.28,.07,.10,'fruit')

def pasture(variant=0):
 ground('grass')
 if variant==0:return
 before=set(bpy.context.scene.objects)
 # One original, simple block cow. Four legs and distinct dark patches establish the type.
 box('CowBody',(-.25,0,.93),(1.35,.65,.60),'cream')
 for x in [-.72,.23]:
  for y in [-.24,.24]:box('CowLeg',(x,y,.36),(.14,.14,.72),'cream');box('CowHoof',(x,y,.07),(.16,.16,.14),'cowdark')
 box('CowHead',(.61,-.02,1.06),(.48,.45,.46),'cream');box('CowMuzzle',(.88,-.02,.94),(.20,.48,.20),'cowdark')
 for y in [-.33,.33]:box('CowEar',(.60,y,1.24),(.23,.18,.08),'cowdark')
 for x in [-.60,-.02]:box('CowPatch',(x,-.329,1.02),(.30,.009,.31),'cowdark')
 box('CowBackPatch',(-.38,0,1.235),(.46,.45,.01),'cowdark')
 bar('CowTail',(-.94,.05,1.13),(-1.04,.08,.49),.055,'cowdark')

 offset,angle=([-.60,.50,0],math.radians(28)) if variant==1 else ([.55,-.48,0],math.radians(-66))
 bpy.context.view_layer.update()
 transform=Matrix.Translation(Vector(offset))@Matrix.Rotation(angle,4,'Z')
 for ob in set(bpy.context.scene.objects)-before:ob.matrix_world=transform@ob.matrix_world

def forestry():
 ground('grass');tree(-.98,.82,2.25,.60);tree(.83,1.06,1.74,.52);tree(.97,-.93,.72,.27,True)
 for x,y in [(-.94,-.94),(.02,-.22)]:
  cylinder('TreeStump',(x,y,.17),.22,.34,'bark',6)
  cylinder('StumpCut',(x,y,.345),.195,.012,'wood',6)

def pit(kind):
 mat='ironsoil' if kind=='iron' else 'coalsoil';ore='ironrock' if kind=='iron' else 'coalrock'
 # One constant low floor, not a per-tile hole. Parallel open benches cross +/-Y.
 box('MineFloor',(0,0,-.36),(4,4,.12),mat)
 box('ContinuousBench',(.86,0,-.267),(.66,4,.066),mat)
 box('ContinuousBenchTop',(.91,0,-.218),(.38,4,.032),mat)
 # Low ore ridge continues through the tile edge; it never encloses a crater.
 section=[(-.39,-.30),(-.25,-.255),(0,-.17),(.22,-.235),(.39,-.30)]
 vs=[(x-.86,y,z) for y in [-2,2] for x,z in section];n=len(section)
 mesh('ContinuousOreBerm',vs,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)],ore)

def oil(empty=False):
 ground('oilsoil')
 if empty:
  cylinder('CappedWell',(0,0,.09),.21,.18,'steel',8)
  box('WellCap',(0,0,.21),(.48,.48,.08),'yellow')
  for x in [-1.0,1.0]:box('DisusedFooting',(x,.50,.025),(.34,.65,.05),'stone')
  return
 box('PumpFoundation',(0,0,.06),(2.8,1.45,.12),'stone')
 for y in [-.34,.34]:bar('PumpLeg',(-.16,y,.12),(.16,y,1.32),.12,'steel')
 bar('WalkingBeam',(-1.02,0,1.56),(1.12,0,1.13),.17,'steel')
 bar('PumpRod',(-1.04,0,.15),(-1.04,0,1.61),.045,'steel')
 # Horse-head plate is a single low-poly silhouette, not a detailed mechanism.
 poly=[(-1.20,1.68),(-.90,1.64),(-.84,1.38),(-1.10,1.14),(-1.31,1.18)]
 vs=[(x,y,z) for y in [-.15,.15] for x,z in poly];faces=[tuple(reversed(range(5))),tuple(range(5,10))]+[(j,(j+1)%5,(j+1)%5+5,j+5) for j in range(5)]
 mesh('PumpHorseHead',vs,faces,'yellow')
 box('MotorHousing',(.92,0,.37),(.60,.60,.51),'steel')
 wheel=cylinder('Counterwheel',(.91,-.34,.52),.34,.12,'yellow',8);wheel.rotation_euler[0]=math.pi/2
 bar('CrankRod',(.91,-.42,.53),(.72,-.42,1.24),.075,'steel')
 box('Counterweight',(.96,0,1.12),(.36,.39,.20),'yellow')

def radiation(x,y,z):
 # Yellow plate and an original geometric trefoil on its -Y face.
 box('WarningPlate',(x,y,z),(.46,.04,.44),'yellow')
 for a in [math.pi/2,math.pi/2+math.tau/3,math.pi/2+2*math.tau/3]:
  pts=[(x+.055*math.cos(a-.42),y-.023,z+.055*math.sin(a-.42)),(x+.19*math.cos(a-.42),y-.023,z+.19*math.sin(a-.42)),(x+.19*math.cos(a+.42),y-.023,z+.19*math.sin(a+.42)),(x+.055*math.cos(a+.42),y-.023,z+.055*math.sin(a+.42))]
  mesh('RadiationTrefoil',pts,[(0,1,2,3)],'cowdark')

def uranium():
 ground('uransoil')
 for x,y in [(-1.20,-1.14),(1.13,.99)]:
  box('WarningStake',(x,y,.44),(.07,.07,.88),'steel');radiation(x,y,.85)
 for x,y,r,h in [(-.15,.15,.48,.23),(.62,-.40,.33,.18)]:rock('UraniumOreMass',x,y,.004,r,h,'roof')

def fishing():
 # Props only: no water plane, opaque ground or opaque bounding rectangle.
 for coord in [-1.5,-.5,.5,1.5]:
  mesh('NetAlongY',[(coord-.012,-2,-.035),(coord+.012,-2,-.035),(coord+.012,2,-.035),(coord-.012,2,-.035)],[(0,1,2,3)],'net')
  mesh('NetAlongX',[(-2,coord-.012,-.033),(2,coord-.012,-.033),(2,coord+.012,-.033),(-2,coord+.012,-.033)],[(0,1,2,3)],'net')
 for x in [-1,1]:
  for y in [-1,1]:
   cylinder('FishingBuoy',(x,y,.105),.14,.27,'buoy',6)
   cone('BuoyCap',(x,y,.29),.14,.10,'cream',6)
 for x,y in [(-1,-1),(1,1)]:
  box('BuoyMast',(x,y,.50),(.025,.025,.54),'steel')
  mesh('BuoyFlag',[(x,y,.76),(x+.27,y,.67),(x,y,.59)],[(0,1,2)],'yellow')

BUILDERS={'vegetable':vegetable,'pasture':pasture,'pasture_left':lambda:pasture(1),'pasture_right':lambda:pasture(2),'forestry':forestry,'iron':lambda:pit('iron'),'coal':lambda:pit('coal'),'oil':oil,'oil_empty':lambda:oil(True),'uranium':uranium,'fishing':fishing}

def build(row):
 ident,name,industry,style=row;G.COLORS.update(COLORS);G.reset();BUILDERS[style]();points,bounds,tri=P.bounds()
 assert all(bounds[0][i]>=-2-.0001 and bounds[1][i]<=2+.0001 for i in [0,1]),(ident,bounds)
 assert 0<tri<=300,(ident,tri)
 cam=P.studio(points,(900,900));out=P.OUT/ident;out.mkdir(parents=True,exist_ok=True)
 m=dict(id=ident,name=name,kind='primary_work_tile',industry=industry,footprint_cells=[1,1],cell_meters=4,lot_meters=[4,4],floors=0,footprint_status='user-specified',front='-Y (Blender) / +Z (Godot)',front_blender='-Y',front_godot='+Z',vertex_bounds_m=bounds,measured_dimensions_m=[bounds[1][i]-bounds[0][i] for i in range(3)],triangles=tri,mesh_objects=sum(o.type=='MESH' for o in bpy.context.scene.objects),camera_elevation_degrees=30,game_registered=False,approval_status='pending-user-review',style_reference='6afefd8 smooth grain ribbon tile',edge_period_m=[4,4],ground_surface_z_m=None if style=='fishing' else (-.30 if style in ['iron','coal'] else 0),water_surface_included=False,minimum_terrain_z_m=-.30 if style in ['iron','coal'] else 0,source='original scripted Blender geometry; no external models, textures, fonts or generation APIs')
 if style in ['iron','coal']:m.update(floor_mode='uniform low floor; edge-continuous open benches',requires_outer_boundary_transition=True)
 if style.startswith('pasture'):m.update(variant_family='pasture',cow_count=0 if style=='pasture' else 1,cow_pose='none' if style=='pasture' else ('left, yaw28' if style=='pasture_left' else 'right, yaw-66'))
 (out/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
 bpy.ops.wm.save_as_mainfile(filepath=str(out/(ident+'.blend')))
 scene=bpy.context.scene;scene.render.filepath=str(out/'tile.png');bpy.ops.render.render(write_still=True)
 originals=[o for o in scene.objects if o.type=='MESH']
 for dx in [-4,0,4]:
  for dy in [-4,0,4]:
   if dx==dy==0:continue
   for ob in originals:
    cp=ob.copy();scene.collection.objects.link(cp);cp.location=ob.location+Vector((dx,dy,0))
 cam.data.ortho_scale*=3;scene.render.filepath=str(out/'tile-3x3.png');bpy.ops.render.render(write_still=True)
 print('WORK_TILE_DONE',ident,m['measured_dimensions_m'],tri,flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--only',choices=[r[0] for r in ROWS]);a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 for row in ROWS:
  if not a.only or a.only==row[0]:build(row)
