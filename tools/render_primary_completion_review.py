"""Actual mixed-pasture Blender scene; not runtime randomization or performance proof."""
import bpy,json,random,sys,importlib.util,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
sp=importlib.util.spec_from_file_location('p',ROOT/'tools/build_primary_industry.py');P=importlib.util.module_from_spec(sp);sp.loader.exec_module(P);P.G.reset()
variants=['primary-tile-pasture-01','primary-tile-pasture-02','primary-tile-pasture-03'];templates={}
for ident in variants:
 with bpy.data.libraries.load(str(ROOT/'assets/primary-industry'/ident/(ident+'.blend')),link=False) as (src,dst):dst.objects=src.objects
 templates[ident]=[(o,o.matrix_basis.copy()) for o in dst.objects if o and o.type=='MESH']
rng=random.Random(1212);layout=[]
for ix in range(5):
 for iy in range(5):
  ident=rng.choices(variants,[.50,.25,.25])[0];turn=rng.randrange(4);transform=Matrix.Translation(Vector(((ix-2)*4,(iy-2)*4,0)))@Matrix.Rotation(turn*math.pi/2,4,'Z')
  for original,pose in templates[ident]:
   clone=original.copy();bpy.context.scene.collection.objects.link(clone);clone.matrix_world=transform@pose
  layout.append(dict(x=ix,y=iy,id=ident,quarter_turns=turn))
pts,_,_=P.bounds();P.studio(pts,(1100,900));scene=bpy.context.scene;scene.cycles.samples=48;scene.render.filepath=str(ROOT/'docs/primary-industry/completion/pasture-mixed-5x5.png');bpy.ops.render.render(write_still=True)
(ROOT/'docs/primary-industry/completion/pasture-review-layout.json').write_text(json.dumps(dict(seed=1212,layout=layout,runtime_selection_implemented=False),indent=2)+'\n')
print('MIXED_PASTURE: 25 actual tile sources, seed1212, preview only')
