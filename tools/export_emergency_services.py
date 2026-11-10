"""Read recovered emergency .blend files; export only derived game resources.
Never execute original build scripts, resave .blend, or update source metadata.
blender -b --factory-startup -t 2 -P tools/export_emergency_services.py
"""
import hashlib
import json
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/emergency-assets-validation'
GAME=ROOT/'cities_do/assets/services'
MAPPING={'fire.small':'small-fire-station','fire.standard':'fire-station','fire.regional':'regional-fire-station',
         'police.small':'small-police-station','police.standard':'police-station',
         'police.headquarters':'regional-police-station','police.prison':'prison-8x8'}

def dump(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def bounds(objects):
    graph=bpy.context.evaluated_depsgraph_get()
    points=[o.matrix_world@Vector(p) for original in objects for o in [original.evaluated_get(graph)] for p in o.bound_box]
    return [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    index=json.loads((ROOT/'docs/recovered-emergency-assets/catalog.json').read_text(encoding='utf-8'))['assets']
    slots_path=GAME/'pending_slots.json'
    slots=json.loads(slots_path.read_text(encoding='utf-8'))
    source_files=[p for group in ['fire','police','prison'] for p in (ROOT/f'assets/{group}-study').rglob('*') if p.is_file()]
    before={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files}
    catalog_path=GAME/'catalog.json'
    catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
    report=[]
    entries=[]
    for slot in slots['slots']:
        ident=MAPPING[slot['id']]
        original=next(e for e in index if e['id']==ident)
        source=ROOT/original['source']
        meta=json.loads((ROOT/original['metadata']).read_text(encoding='utf-8'))
        bpy.ops.wm.open_mainfile(filepath=str(source))
        # Convert text only in the loaded in-memory copy; retain source font attribution.
        bpy.ops.object.select_all(action='DESELECT')
        for o in bpy.context.scene.objects:
            if o.type=='FONT': o.select_set(True);bpy.context.view_layer.objects.active=o
        if bpy.context.selected_objects: bpy.ops.object.convert(target='MESH')
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
        low,high=bounds(objects)
        raw_low,raw_high=list(low),list(high)
        offset=-low[2]
        # Translate in world coordinates exactly once; never scale the geometry.
        transforms={o:o.matrix_world.copy() for o in objects}
        for o,matrix in transforms.items(): o.matrix_world=Matrix.Translation((0,0,offset))@matrix
        bpy.context.view_layer.update()
        low,high=bounds(objects)
        width,depth=map(int,meta['footprint_cells'])
        assert abs(high[0]-low[0]-width*4)<.05 and abs(high[1]-low[1]-depth*4)<.05,(ident,low,high)
        front=bpy.data.objects.new('ServiceFrontage',None)
        bpy.context.scene.collection.objects.link(front)
        front.location=(0,-depth*2,0)
        front['front_axis_gltf']=[0,0,1]
        front['source_axis_blender']='-Y'
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects+[front]: o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        model=GAME/(ident+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',use_selection=True,
                                 export_yup=True,export_apply=True,export_extras=True,
                                 export_cameras=False,export_lights=False,export_animations=False)
        png=GAME/(ident+'.png')
        png.write_bytes((ROOT/original['preview']).read_bytes())
        doors=[]
        front_features=[]
        for o in objects:
            if o.name.startswith('GarageShutter'):
                a,b=bounds([o]);doors.append({'node':o.name,'width_m':b[0]-a[0],'height_m':b[2]-a[2],'front_blender_y':(a[1]+b[1])/2})
            if any(word in o.name.lower() for word in ['door','entrance','entry','gate','lobby']):
                a,b=bounds([o]);front_features.append({'node':o.name,'center_blender':[(a[i]+b[i])/2 for i in range(3)]})
        entry=dict(id=ident,name=slot['name'],group='emergency',width=width,depth=depth,
                   metres=[width*4,depth*4],height_m=round(high[2]-low[2],6),storeys=meta.get('max_storeys',1),
                   model='res://assets/services/'+model.name,preview='res://assets/services/'+png.name,
                   source=original['source'],front_axis=[0,1],front_marker='ServiceFrontage',
                   status='asset_preview_only',simulation_enabled=False,recovered_original=True,
                   source_name=meta['name'],source_group=original['group'],
                   ground_offset_m=round(offset,6),render={'source_preview_preserved':True},
                   source_bounds_blender=[raw_low,raw_high],garage_doors=doors,
                   front_feature_node=min(front_features,key=lambda f:f['center_blender'][1])['node'] if front_features else '')
        spec=GAME/'specs'/(ident+'.json')
        dump(spec,entry)
        slot.update(status='ready',asset='res://assets/services/specs/'+spec.name)
        entries.append(entry)
        report.append(dict(slot_id=slot['id'],id=ident,name=slot['name'],lot_m=[width*4,depth*4],
                           raw_bounds_blender=[raw_low,raw_high],export_bounds_blender=[low,high],
                           size_m=[high[i]-low[i] for i in range(3)],unit_scale=bpy.context.scene.unit_settings.scale_length,
                           garage_doors=doors,front_features=front_features))
        print('EXPORTED_EMERGENCY',ident,report[-1]['size_m'],flush=True)
    ids=set(MAPPING.values())
    catalog['facilities']=[e for e in catalog['facilities'] if e['id'] not in ids]+entries
    dump(catalog_path,catalog)
    dump(slots_path,slots)
    after={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files}
    assert before==after,'Original source file changed'
    dump(OUT/'measurements.json',report)
    dump(OUT/'source-hashes.json',{'unchanged':True,'sha256':after})

if __name__=='__main__': main()
