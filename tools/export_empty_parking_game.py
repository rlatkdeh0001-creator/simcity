"""Selective read-only export of the four approved empty parking sources.
Blender --background --factory-startup --disable-autoexec -t 2 --python tools/export_empty_parking_game.py
Never execute the full builder or save a source .blend/spec/preview.
"""
import ast,hashlib,json,math
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/empty-parking-game-validation'
IDS=['parking-small-2x4','parking-medium-4x4','parking-large-4x8','parking-tower-4x4-4f']
PREFIXES=('ParkedCarBody','ParkedCarCabin','ParkedCarRoof','ParkedCarWheel','CarBody','CarCabin')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    # Reuse only the approved studio function, as in empty_parking_sources.py.
    tree=ast.parse((ROOT/'tools/build_facilities.py').read_text())
    studio=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='render')
    code=compile(ast.fix_missing_locations(ast.Module(body=[studio],type_ignores=[])),'approved_facility_studio','exec')
    report=[]
    for ident in IDS:
        folder=ROOT/'assets/facilities'/ident
        source=folder/'facility.blend';before=digest(source)
        spec=json.loads((folder/'spec.json').read_text())
        bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
        bpy.context.scene.cycles.device='CPU'
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
        assert meshes and not any(o.name.startswith(PREFIXES) for o in meshes),ident
        bpy.ops.object.select_all(action='DESELECT')
        for obj in meshes:obj.select_set(True)
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join();bpy.context.object.name='FacilityCombinedMesh'
        target=ROOT/'cities_do/assets/facilities'/ident
        bpy.ops.export_scene.gltf(filepath=str(target.with_suffix('.glb')),export_format='GLB',export_extras=True,export_animations=False)
        scope=dict(bpy=bpy,math=math,Vector=Vector,spec=spec,W=spec['width']*4,D=spec['depth']*4)
        exec(code,scope)
        calibration=scope['render'](target.with_suffix('.png'))
        assert calibration==spec['render'],(ident,'camera calibration changed')
        assert digest(source)==before,(ident,'source changed')
        report.append(dict(id=ident,source_sha256=before,source_unchanged=True,remaining_source_meshes=len(meshes),calibration=calibration,model_sha256=digest(target.with_suffix('.glb')),preview_sha256=digest(target.with_suffix('.png'))))
        (OUT/'export.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
        print('EMPTY_GAME_EXPORTED',ident,'SOURCE_UNCHANGED',flush=True)
if __name__=='__main__':main()
