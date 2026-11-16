# child — verified asset batch

Parts: 13; additional base: 1; native PNG: 425. Rig checks: 406; sprite checks: 140; mirror cases: 210. All passed.

All combinations: 72 ×25poses; minimum joint alpha 248; minimum head/top gap 0.02000m. Evaluated waist vertices stay inside the common12-sided top envelope in all5poses.

[Actual Godot combination sheet](combinations.png) / [validation](validation-results.json) / [all combinations](combination-checks.json) / [persistent12 IDs and tint palettes](preview-samples.json). Above: live game scale at zoom1; below: native1x and whole-character2x. Four gray layers,64x96/40px/m/foot(32,84),5stored directions+3RGBA/depth mirrors,Idle+Walk4,14named bones.

Geometry authored directly in `tools/build_citizen_remaining.py`, reuse of original scripted pilot only. No external models/textures/generation APIs. Uniform uses adult body and ages12–17; child clothes are separate0–11 models. Optional bind GLBs loaded by actual Godot GLTFDocument with14bones and source-matching bounds; not3D animated gameplay. Live game code/population/fees untouched, no push/main.

Child has a distinct1.10m archetype: trunk/limb bone lengths and animation translations0.60×, head0.78× with moved centre for a proportionally larger head. Neck/hands and cuffs are broadened locally for native-resolution joint coverage; the skin remains one shared layer. Original adult validators remain unchanged; temporary child validators parameterize ONLY height1.10, waist overlap.042 and anatomical anchor positions. Alpha240/error1e-5/bone/material/foot/loop/camera rules are unchanged. Skin is still one head/neck/hands layer; no facial details.

Source scripts and .blend are retained per part; published sources are never overwritten. `build.py` calls the central generator with a fixed batch/ID; supply explicit scratch `--cache` and a fresh output root inside this checkout for replay. The remaining pipeline uses the approved D:Pillow11.3.0 target and existing Blender4.3.2 Python3.11/NumPy1.24.3, with process-local PYTHONPATH only. Run `tools/run_citizen_remaining.py --batch child --phase verify-existing --cache <agent-scratch> --blender <absolute-exe> --godot <absolute-exe>` with that Python to recheck existing PNGs without rerender.

Economic proposal: appearance data has no independent construction/upkeep/production/capacity; no economic implementation. Review mode self-review; final evidence only, raw render/temp resolved views removed after delivery.
