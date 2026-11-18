"""Original symmetric white metro car; 3 materials, <=1500 triangles."""
import argparse,json,shutil,sys
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_transit_vehicles as T
F=T.F;C=T.C

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output-root',type=Path,default=ROOT);out=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []).output_root
    ident='subway-car-01';folder=out/'assets/vehicle-fleet'/ident
    if folder.exists():raise RuntimeError('Protected source exists: '+str(folder))
    C.reset_scene();bpy.context.preferences.filepaths.save_version=0;bpy.context.scene.unit_settings.system='METRIC'
    root=C.empty('SubwayCarRoot');root['asset_id']=ident;root['forwardGltf']=[0.,0.,1.]
    white=F.material('White','eeeFec');dark=F.material('Dark','30383b');glass=F.material('WindowBand','294453')
    m={'Dark':dark,'Metal':dark}
    # Reuse exact authored bogie/coupler positions with process-local low-poly primitives.
    original_cylinder,original_box=F.cylinder,F.box
    def cylinder(*args,**kw):kw['segments']=8;return original_cylinder(*args,**kw)
    def box(name,size,pos,mat,parent,bevel=.02):return original_box(name,size,pos,mat,parent,0)
    F.cylinder,F.box=cylinder,box
    try:T.bogies(root,15.,m)
    finally:F.cylinder,F.box=original_cylinder,original_box
    F.box('SimpleUnderbody',(2.5,14.4,.32),(0,0,1.10),dark,root,0)
    F.box('WhiteSymmetricBody',(2.78,15.,2.48),(0,0,2.36),white,root,.10)
    for sign in [-1,1]:F.box('SingleDarkWindowBand',(.02,13.7,.70),(sign*1.39,0,2.73),glass,root,0)
    C.update();tri,lo,hi=T.measure();dims=[hi[1]-lo[1],hi[0]-lo[0],hi[2]-lo[2]]
    assert tri<=1500,(tri,dims)
    assert all(abs(a-b)<.001 for a,b in zip(dims,[16,2.8,3.6])) and abs(lo[2])<.001,(lo,hi)
    folder.mkdir(parents=True);game=out/'cities_do/assets/vehicles';game.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(game/(ident+'.glb')),export_format='GLB',export_extras=True,export_animations=False)
    ppm=F.render_views(game/'sprites'/ident,16,2.8,3.6);shutil.copy2(game/'sprites'/ident/'045.png',folder/'preview.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'vehicle.blend'),compress=True)
    spec={'id':ident,'name':'지하철 차량','category':'rail_metro','style':'plain_white_symmetric','body_length_m':15,'overall_length_m':16,'length_m':16,'width_m':2.8,'height_m':3.6,'measured_dimensions_lwh_m':dims,'triangles':tri,'material_count':3,'gauge_m':1.435,'rail_top_z_m':0,'coupler_height_m':1,'coupler_anchors_blender':[[0,-7.5,1],[0,7.5,1]],'coupler_contact_heads_blender':[[0,-8,1],[0,8,1]],'coupled_body_gap_m':1,'frame_blender':{'forward':'-Y','left':'+X','up':'+Z'},'frame_gltf':{'forward':'+Z','left':'+X','up':'+Y'},'model':'res://assets/vehicles/'+ident+'.glb','source':'assets/vehicle-fleet/'+ident+'/vehicle.blend','preview':'res://assets/vehicles/sprites/'+ident+'/045.png','render':{'resolution':[430,245],'camera_elevation_deg':30,'angles_deg':list(range(0,360,45))},'status':'inspection_only','simulation_enabled':False,'underground_rail_top_world_m':-12.7,'groove_width_m':3.3,'platform_gap_m':.25,'consist_cars':4,'consist_overall_length_m':64}
    F.write_json(folder/'spec.json',spec)
    (folder/'build.py').write_text('import runpy\nfrom pathlib import Path\nrunpy.run_path(str(Path(__file__).resolve().parents[3]/"tools/build_rail_subway_car.py"),run_name="__main__")\n',encoding='utf-8')
    for name,row in [('catalog.json',spec),('render_manifest.json',{'id':ident,'pixels_per_metre':ppm,'angles_deg':list(range(0,360,45))})]:
        path=game/name;doc=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'vehicles':[]};assert not any(e['id']==ident for e in doc['vehicles']);doc['vehicles'].append(row);F.write_json(path,doc)
    print('SUBWAY_CAR_BUILT',tri,dims,flush=True)
if __name__=='__main__':main()
