"""Original CITIES_DO compressed-length rail fleet; Blender 4.3.2.
Run: blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/build_transit_vehicles.py
Reuses the checked-in fleet palette, geometry primitives and 8-view renderer.
Refuses to overwrite delivered source assets: use a new version ID for revisions.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_vehicle_fleet as F
C = F.C
ROWS = [
    ('train-loco-01', '기관차', 'rail_locomotive', 9.0, 3.0, 4.2),
    ('train-passenger-01', '여객용 객차', 'rail_passenger', 10.0, 3.0, 4.0),
    ('train-flatcar-01', '빈 평판차', 'rail_freight', 7.0, 2.9, 1.4),
    ('container-20ft-01', '20ft 컨테이너', 'cargo', 6.06, 2.44, 2.6),
]


def box(name, size, pos, mat, root, bevel=.02):
    return F.box(name, size, pos, mat, root, bevel)


def tube(name, points, radius, mat, root, segments=8):
    return F.finish(C.tube(name, points, radius, segments=segments), mat, root)


def roof(name, length, width, bottom, top, mat, root):
    # Closed extrusion of a gently rounded, faceted roof cross section.
    profile = [(-width/2, bottom), (width/2, bottom)]
    for i in range(9):
        a = i*math.pi/8
        profile.append((width/2*math.cos(a), bottom+(top-bottom)*math.sin(a)))
    n = len(profile)
    verts = [(x, y, z) for y in [-length/2, length/2] for x, z in profile]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    # Profile runs counterclockwise in XZ, thus its side faces need this winding.
    ob = F.mesh(name, verts, faces, mat, root)
    import bmesh
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(ob.data); bm.free()
    return ob


def couplers(root, L, m):
    for side, label in [(-1, 'Front'), (1, 'Rear')]:
        anchor = C.empty('CouplerAnchor_'+label, (0, side*L/2, 1.0))
        C.parent_keep(anchor, root)
        anchor['head_blender'] = [0, side*(L/2+.5), 1.0]
        box('CouplerShank_'+label, (.18, .40, .17), (0, side*(L/2+.20), 1), m['Dark'], root)
        box('CouplerHead_'+label, (.36, .15, .26), (0, side*(L/2+.425), 1), m['Metal'], root, .03)
        # Head end face is exactly 0.5m outside the nominal carbody.


def bogies(root, L, m, flat=False):
    r = .34 if flat else .43
    axle_spacing = .85 if flat else 1.25
    for b, center in enumerate([-L*.30, L*.30]):
        bogie = C.empty('Bogie_'+str(b), (0, center, r+.10)); C.parent_keep(bogie, root)
        box('BogieBolster', (1.9, axle_spacing+1.0, .18), (0, center, r+.17), m['Dark'], bogie)
        for y in [center-axle_spacing/2, center+axle_spacing/2]:
            F.cylinder('Axle', .08, 1.66, (0, y, r), m['Metal'], bogie, axis='X', segments=12)
            for side in [-1, 1]:
                # Gauge is between the wheel inner faces; no flange extends below rail datum.
                x = side*(1.435/2+.065)
                wheel = F.cylinder('RailWheel', r, .13, (x, y, r), m['Dark'], bogie, axis='X', segments=20)
                wheel['inner_face_x_m'] = side*1.435/2
                F.cylinder('WheelHub', r*.48, .045, (x+side*.082, y, r), m['Metal'], bogie, axis='X', segments=12)
                F.cylinder('AxleBox', .13, .12, (side*1.02, y, r), m['Metal'], bogie, axis='X', segments=12)
        for side in [-1, 1]:
            box('BogieSideFrame', (.15, axle_spacing+.65, .17), (side*1.02, center, r+.12), m['Dark'], bogie)
            for dy in [-.26, .26]:
                F.cylinder('SuspensionSpring', .11, .23, (side*1.02, center+dy, r+.31), m['Metal'], bogie, axis='Z', segments=10)
    couplers(root, L, m)


def locomotive(root, L, W, H, m):
    bogies(root, L, m)
    box('MainChassis', (2.88, L, .27), (0, 0, 1.22), m['Dark'], root)
    box('Body', (2.76, L-.24, 1.94), (0, 0, 2.34), m['Paint'], root, .10)
    # Single front cab, long equipment compartment behind it.
    F.cabin('FrontCab', 3.0, -L/2+.02, -1.6, 2.15, 3.96, m['Cream'], root, .35)
    for x in [-.68, .68]:
        verts = [(x+dx, -L/2+.02+.35*(z-2.15)/(3.96-2.15)+dy, z)
                 for dy in [-.025, -.008] for z in [3.10, 3.80] for dx in [-.57, .57]]
        F.mesh('Windscreen', verts, [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)], m['Glass'], root)
    for side in [-1, 1]:
        box('CabSideGlass', (.03, 1.23, .74), (side*1.39, -2.71, 3.39), m['Glass'], root, .04)
        box('CabDoor', (.035, .65, 1.73), (side*1.39, -1.91, 2.66), m['Cream'], root)
        box('DoorHandle', (.055, .15, .045), (side*1.42, -1.82, 2.7), m['Metal'], root, .005)
        box('FleetBand', (.035, L-.32, .22), (side*1.395, 0, 1.92), m['Cream'], root)
        for y in [-.7, .8, 2.3]:
            box('IntakeRecess', (.03, 1.10, .76), (side*1.395, y, 2.75), m['Dark'], root)
            for z in [2.46, 2.60, 2.74, 2.88, 3.02]:
                box('IntakeLouvre', (.045, 1.02, .035), (side*1.42, y, z), m['Metal'], root, 0)
        for z in [1.4, 1.64, 1.88]:
            box('CabStep', (.16, .65, .07), (side*1.42, -1.92, z), m['Metal'], root)
        tube('CabHandrail', [(side*1.46, -1.58, 1.75), (side*1.46, -1.58, 3.14)], .025, m['Metal'], root)
    roof('CabRoof', 2.65, 2.97, 3.95, 4.12, m['Cream'], root).location.y = -2.92
    box('RoofEquipmentBase', (2.2, 4.0, .18), (0, .85, 3.40), m['Metal'], root)
    for y in [-.2, 1.6]:
        F.cylinder('RoofCoolingFan', .57, .16, (0, y, 3.57), m['Dark'], root, axis='Z', segments=20)
        for dx in [-.35, 0, .35]:
            box('FanGrille', (.035, .92, .025), (dx, y, 3.66), m['Metal'], root, .003)
    for y in [2.8, 3.5]:
        F.cylinder('RoofInsulator', .10, .28, (.65, y, 3.59), m['Cream'], root, axis='Z', segments=10)
    tube('RoofPickupStowed', [(.65, 2.8, 3.73), (.65, 3.12, 4.175), (.65, 3.5, 3.73)], .025, m['Metal'], root)
    box('RoofPickupBar', (1.2, .10, .05), (0, 3.12, 4.175), m['Dark'], root)
    for x in [-.95, .95]:
        box('FrontHeadlamp', (.32, .04, .22), (x, -L/2+.01, 2.17), m['Head'], root)
        box('RearMarker', (.16, .04, .20), (x, L/2-.08, 2.0), m['Tail'], root)


def passenger(root, L, W, H, m):
    bogies(root, L, m)
    box('Underframe', (2.78, L-.14, .25), (0, 0, 1.21), m['Dark'], root)
    box('PassengerBody', (2.94, L, 2.0), (0, 0, 2.37), m['Cream'], root, .08)
    roof('RoundedRoof', L-.04, 2.98, 3.35, H, m['Cream'], root)
    for side in [-1, 1]:
        box('FleetBand', (.025, L-.12, .28), (side*1.4875, 0, 1.85), m['Paint'], root)
        for y in [-2.2, -.74, .74, 2.2]:
            box('WindowSeal', (.025, 1.26, 1.0), (side*1.475, y, 2.83), m['Dark'], root, .03)
            box('WindowGlass', (.03, 1.12, .84), (side*1.485, y, 2.83), m['Glass'], root, .04)
        for y in [-4.02, 4.02]:
            box('PassengerDoor', (.03, 1.03, 1.94), (side*1.475, y, 2.37), m['Paint'], root, .025)
            for dy in [-.245, .245]:
                box('DoorGlass', (.035, .36, .68), (side*1.4825, y+dy, 2.86), m['Glass'], root)
            box('DoorSplit', (.035, .025, 1.75), (side*1.4825, y, 2.35), m['Metal'], root, .002)
            box('BoardingStep', (.20, 1.15, .10), (side*1.39, y, 1.18), m['Metal'], root)
    for side in [-1, 1]:
        box('EndGangway', (1.05, .06, 1.98), (0, side*(L/2-.03), 2.37), m['Dark'], root)
        box('GangwayDoor', (.76, .07, 1.72), (0, side*(L/2-.035), 2.39), m['Metal'], root)
        box('GangwayGlass', (.52, .075, .55), (0, side*(L/2-.0375), 2.81), m['Glass'], root)
    for y in [-2, 2]:
        box('UnderfloorEquipment', (1.7, 1.25, .38), (0, y, .89), m['Dark'], root)


def flatcar(root, L, W, H, m):
    bogies(root, L, m, flat=True)
    box('LoadDeck', (W, L, .16), (0, 0, 1.12), m['Metal'], root, .015)
    for x in [-1.28, 1.28]:
        box('LongitudinalGirder', (.18, L-.10, .38), (x, 0, .91), m['Paint'], root)
        for y in [-2.9, -1.5, 0, 1.5, 2.9]:
            box('GirderStiffener', (.20, .10, .35), (x, y, .91), m['Metal'], root, .008)
    for y in [-2.5, -1.25, 0, 1.25, 2.5]:
        box('Crossbeam', (2.65, .13, .22), (0, y, .96), m['Dark'], root)
    for x in [-1.10, 1.10]:
        for y in [-2.85, 2.85]:
            box('ContainerTwistlockSeat', (.22, .25, .012), (x, y, 1.194), m['Head'], root, .004)
    for y in [-L/2+.07, L/2-.07]:
        box('EndSill', (W, .14, .20), (0, y, 1.30), m['Paint'], root)
        for x in [-.95, .95]:
            box('EndReflector', (.20, .15, .08), (x, y, 1.28), m['Head'], root, .004)
    anchor = C.empty('ContainerLoadOrigin', (0, 0, 1.2)); C.parent_keep(anchor, root)


def container(root, L, W, H, m):
    p = m['ContainerPaint']
    box('ContainerShell', (W-.08, L-.08, H-.08), (0, 0, H/2), p, root, .015)
    for x in [-W/2+.045, W/2-.045]:
        for y in [-L/2+.045, L/2-.045]:
            box('CornerPost', (.09, .09, H), (x, y, H/2), p, root, .008)
        for z in [.045, H-.045]:
            box('SideFrame', (.09, L, .09), (x, 0, z), p, root, .008)
        for i in range(22):
            y = -L/2+.23+i*(L-.46)/21
            box('CorrugatedSideRib', (.08, .065, H-.22), (x, y, H/2), p, root, .012)
    for y in [-L/2+.04, L/2-.04]:
        for z in [.045, H-.045]:
            box('EndFrame', (W-.12, .08, .09), (0, y, z), p, root)
    for i in range(9):
        box('RoofRib', (W-.22, .065, .055), (0, -2.5+i*.625, H-.0275), p, root, .01)
    for x in [-.58, .58]:
        box('RearDoor', (1.10, .04, H-.22), (x, L/2-.035, H/2), p, root, .01)
        F.cylinder('DoorLockRod', .024, H-.42, (x+.28, L/2-.024, H/2), p, root, axis='Z', segments=8)
        for z in [.40, H-.40]:
            box('LockRodBracket', (.13, .07, .09), (x+.28, L/2-.035, z), p, root, .008)
    for z in [.46, 1.30, 2.14]:
        for x in [-W/2+.09, W/2-.09]:
            box('DoorHinge', (.15, .09, .09), (x, L/2-.045, z), p, root, .01)


def measure():
    dg = bpy.context.evaluated_depsgraph_get(); points = []; tri = 0
    for ob in bpy.context.scene.objects:
        if ob.type != 'MESH': continue
        ev = ob.evaluated_get(dg); mesh = ev.to_mesh()
        points.extend(ev.matrix_world@v.co for v in mesh.vertices)
        mesh.calc_loop_triangles(); tri += len(mesh.loop_triangles); ev.to_mesh_clear()
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return tri, lo, hi


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--only', choices=[r[0] for r in ROWS])
    ap.add_argument('--output-root', type=Path, default=ROOT,
                    help='New empty workspace for reproduction; leaves original sources untouched.')
    ap.add_argument('--revision', help='New revision directory and export suffix; never overwrites earlier sources.')
    args = ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    output_root = args.output_root.resolve()
    built = []; rendered = []
    for ident, name, kind, L, W, H in ROWS:
        if args.only and ident != args.only: continue
        suffix = '-'+args.revision if args.revision else ''
        export_id = ident+suffix
        source_relative = Path('assets/vehicle-fleet')/ident
        if args.revision: source_relative = source_relative/args.revision
        source = output_root/source_relative
        if source.exists(): raise RuntimeError('Protected source already exists: '+str(source))
        source.mkdir(parents=True)
        C.reset_scene(); scene = bpy.context.scene
        scene.unit_settings.system = 'METRIC'; scene.unit_settings.scale_length = 1
        root = C.empty('VehicleRoot'); root['asset_id'] = ident
        root['forwardGltf'] = [0., 0., 1.]; root['units'] = 'metres'
        m = {k:F.material(k, v, .25 if k=='Metal' else 0) for k,v in {
            'Paint':'527e83','Cream':'dedbd0','Glass':'294453','Dark':'30383b',
            'Metal':'9ba9ab','Head':'e8d69d','Tail':'c95343','ContainerPaint':'a35f50'}.items()}
        {'rail_locomotive':locomotive,'rail_passenger':passenger,'rail_freight':flatcar,'cargo':container}[kind](root,L,W,H,m)
        C.update(); tri, lo, hi = measure()
        overall = [hi[1]-lo[1], hi[0]-lo[0], hi[2]-lo[2]]
        assert 2000 <= tri <= 5000, (ident, tri)
        assert abs(lo[2]) < .0001, (ident, lo)
        assert abs(overall[0]-(L if kind=='cargo' else L+1)) < .001, (ident, overall)
        assert abs(overall[1]-W) < .001 and abs(overall[2]-H) < .001, (ident, overall)
        game = output_root/'cities_do/assets/vehicles'; game.mkdir(parents=True,exist_ok=True)
        spec = {'id':ident,'name':name,'category':kind,'style':'transit_compressed_20261116',
            'body_length_m':L,'overall_length_m':overall[0],'length_m':overall[0],
            'width_m':W,'height_m':H,'measured_dimensions_lwh_m':[round(v,5) for v in overall],
            'triangles':tri,'frame_blender':{'forward':'-Y','left':'+X','up':'+Z'},
            'frame_gltf':{'forward':'+Z','left':'+X','up':'+Y'},
            'model':'res://assets/vehicles/'+export_id+'.glb',
            'source':source_relative.as_posix()+'/vehicle.blend',
            'preview':'res://assets/vehicles/sprites/'+export_id+'/045.png',
            'render':{'resolution':[430,245],'camera_elevation_deg':30,'angles_deg':list(range(0,360,45))},
            'status':'inspection_only','simulation_enabled':False,
            'reproduce':'blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/build_transit_vehicles.py -- --only '+ident+(' --revision '+args.revision if args.revision else '')+' --output-root <new-empty-workspace>'}
        if kind != 'cargo':
            spec.update({'gauge_m':1.435,'rail_top_z_m':0,'coupler_height_m':1.0,
                'coupler_anchors_blender':[[0,-L/2,1],[0,L/2,1]],
                'coupler_contact_heads_blender':[[0,-L/2-.5,1],[0,L/2+.5,1]],
                'coupled_body_gap_m':1.0,'length_compression':'User-approved game-length compression only; width and height preserved.'})
        else:
            spec.update({'tint_material':'ContainerPaint','tint_swatches':{'red':'a35f50','blue':'527b9b','green':'668274','grey':'929b9d'}})
        if kind == 'rail_freight': spec['container_load_origin_blender']=[0,0,1.2]
        F.write_json(source/'spec.json',spec)
        # All source geometry, no studio objects, in the runtime export.
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.export_scene.gltf(filepath=str(game/(export_id+'.glb')),export_format='GLB',export_extras=True,export_yup=True,export_animations=False)
        ppm = F.render_views(game/'sprites'/export_id, overall[0], W, H)
        scene.render.filepath = str(source/'preview.png')
        # Deliver the same real 045-degree view, without a second render.
        import shutil
        shutil.copy2(game/'sprites'/export_id/'045.png', source/'preview.png')
        bpy.ops.wm.save_as_mainfile(filepath=str(source/'vehicle.blend'),compress=True)
        wrapper = '"""Run from any location; dependencies remain in repository tools and .agents/skills/vehicle."""\nimport runpy, sys\nfrom pathlib import Path\nroot=next(p for p in Path(__file__).resolve().parents if (p/"tools/build_transit_vehicles.py").is_file())\nsys.argv=[str(root/"tools/build_transit_vehicles.py"),"--","--only","'+ident+'"]\nrunpy.run_path(str(root/"tools/build_transit_vehicles.py"),run_name="__main__")\n'
        (source/'build.py').write_text(wrapper,encoding='utf-8')
        if args.revision:
            wrapper = wrapper.replace('runpy.run_path(', 'sys.argv.extend(["--revision", '+repr(args.revision)+'])\nrunpy.run_path(')
            (source/'build.py').write_text(wrapper,encoding='utf-8')
        built.append(spec); rendered.append({'id':ident,'pixels_per_metre':ppm,'angles_deg':list(range(0,360,45))})
        print('TRANSIT_BUILT',ident,'LWH',overall,'TRIANGLES',tri,flush=True)
    for filename, key, additions in [('catalog.json','vehicles',built),('render_manifest.json','vehicles',rendered)]:
        path=output_root/'cities_do/assets/vehicles'/filename
        doc=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {'schema_version':1,'vehicles':[]}
        ids={e['id'] for e in doc[key]}
        if args.revision:
            replacements={e['id']:e for e in additions}
            doc[key]=[replacements.get(e['id'],e) for e in doc[key]]
            doc[key].extend(e for e in additions if e['id'] not in ids)
        else:
            assert not ids.intersection(e['id'] for e in additions), 'Already registered'
            doc[key].extend(additions)
        F.write_json(path,doc)
    print('TRANSIT_COMPLETE',len(built),flush=True)


if __name__ == '__main__': main()
