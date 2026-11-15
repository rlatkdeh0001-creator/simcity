---
name: cities-do-asset-production
description: Create, revise, render and validate CITIES_DO game art with original Blender Python geometry in the existing low-saturation isometric series. Use for buildings, vehicles, service facilities, seamless industry tiles, traffic signals and layered citizens, or when another AI needs to reproduce this project's asset workflow. Includes pinned generators, a standalone staging runner, validation and handoff contracts; no Claude login or generation API required.
compatibility: Python 3.10+ with Pillow and NumPy, Blender 4.3.2 recommended; Linux tested. No Git needed to generate. Optional Git for delivery.
---

# CITIES_DO asset production

This is an executable handoff of our **scripted 3D asset workflow**. It contains
original generators and the MIT zstack helper they use. It does not recreate an
unavailable earlier chat's image-generation prompts. A PNG from this workflow is
an actual render of the delivered Blender model. No external models, textures,
image-generation services or Claude authentication are involved.

## Read first

1. Read the current user request and, when inside the project, `AGENTS.md`,
   `mistake.md`, `docs/SKILL_HANDOFF_KO.md` and relevant asset specs. Current user
   instructions and current project contracts override historical recipes here.
2. Read [contracts](references/CONTRACTS_KO.md) and
   [recipe guide](references/RECIPES_KO.md). Choose the closest generator. For
   precise origins/revisions/adaptations see
   [source manifest](references/source-manifest.json). Do not assume every old
   asset or current game feature is included.
3. Use a **new, empty workspace** for generation. This preserves approved sources
   and prevents historical exporters from changing a live game catalog.
   Default delivery is source assets on a separate branch, without runtime
   integration or main merge. Respect a user's explicit delivery instruction.

## Quick start (any AI or a human can run this)

Let `<skill>` be the directory containing this file. Commands below run in a
terminal, using your actual absolute path. Quote paths containing spaces.

```sh
python "<skill>/scripts/assetkit.py" doctor
python "<skill>/scripts/assetkit.py" list
python "<skill>/scripts/assetkit.py" prepare --workspace "<new-output-directory>"
python "<skill>/scripts/assetkit.py" run --workspace "<new-output-directory>" --profile building-growth --only small-4x4-logistics-01
```

Install local prerequisites if needed:
`python -m pip install -r "<skill>/requirements.txt"` and install Blender 4.3.2.
Pass `--blender "/path/to/blender"` to the runner or set `BLENDER` to the executable.
On Windows this may be `C:\Program Files\Blender Foundation\Blender 4.3\blender.exe`;
on macOS `/Applications/Blender.app/Contents/MacOS/Blender`.
These platforms have not been tested here. The runner never installs anything or
uses the network by itself. `CITIES_DO_FONT` may point to a locally installed,
properly licensed open font. See recipe guide for exact font behavior.

`prepare` copies all needed script dependencies into the output directory.
Subsequent calls preserve edited scripts; use another empty directory to refresh
from the bundle. `run` regenerates its selected asset paths, so copy or commit
approved outputs before rerunning the same IDs. Never point it at a game checkout.
The runner rejects nonempty unrelated directories and its own skill directory.

## Make a NEW asset, rather than merely rerunning an example

1. `prepare`, then inspect the appropriate **staged** `tools/build_*.py` recipe,
   its data table (`FLEET`, `ROWS` or `SPECS`) and shape functions. Do not change
   vendored upstream `common.py`. Keep dimensions, coordinate frame, material
   names, source-only status and output paths explicit.
2. Add a new stable ID to the staged table and implement its silhouette using
   cubes, low-segment cylinders, simple mesh profiles and bevels. Reuse the
   palette/material/light/camera helpers from that recipe. Give object names to
   meaningful components (mirror mount, entrance, signal lamp, citizen layer).
   New variants need visibly different silhouettes, not recoloring alone.
3. Change the corresponding constraints and metadata together. Existing verifiers
   often assume the fixed original batch IDs; adapt or add checks for the new ID
   rather than claiming they validate it. For new IDs invoke the staged generator
   directly using the command template in the recipe guide; `run --only` only
   accepts the bundled catalog. Reuse `check` afterwards for generic checks.
4. Render at full delivered resolution with transparent background. Inspect actual
   PNGs at native game size and enlarged. Show front/side/rear when attachments,
   signs or entrances may be hidden. Check mirror supports physically meet the
   body, text is readable/unobstructed and parts do not float.
5. Measure **evaluated mesh vertices**, not unmodified object dimensions. Report
   W×D×H (vehicles L×W×H), triangle count, lot cells, floor count, frame and origin.
   Distinguish nominal body size from all-accessory envelope. Follow the latest
   request's budget; do not infer performance from polygon count alone.
6. Run profile-specific checks and generic `check`. Fix failures before presenting.
   Do not count `doctor`, successful Blender exit, metadata alone or an attractive
   contact sheet as verification of geometry, seam continuity or game integration.
7. Deliver the source `.blend`, generator/dependencies, PNG(s), metadata, validation
   reports and a short reproducible command. If requested, commit and push an
   asset branch with exact paths and GitHub links. Keep provenance/licenses with
   redistributed helpers. Exclude render caches, `.blend1`, unrelated files,
   credentials and machine-specific logs. Do not auto-register an asset or change
   costs/capacity/upkeep without authorization.

## Available executable recipes

| Profile | Included baseline | Output scope |
|---|---|---|
| `building-growth` | 14 accepted 2×2/4×4 growth models, corrected industry signs | `.blend`, 900×1100 PNG, metadata |
| `vehicle-fleet` | 23 scripted fleet designs | `.blend`, spec; staged GLB + 8 sprites |
| `service-vehicles` | garbage truck + supported-mirror Korean-inspired ambulance | sources, front/rear previews, geometry checks |
| `primary-grain` | grain farm + approved smooth golden ridge tile | sources, PNG, metadata |
| `primary-main` | 8 remaining industry buildings, distinct coal/iron | sources, PNG, metadata |
| `primary-tiles` | 11 remaining work tile variants | sources, PNG, metadata |
| `traffic-signals` | matching post/arm 4-lamp signals | all-off sources, on/off + lamp-state images, checks |
| `citizen` | adult pilot, shared rig, 4 tintable layers | source, 100 PNGs, depth sidecar, sheet, GIF, checks |
| `parking-parks` | 4 parks + 4 **empty** parking facilities | sources, PNGs; staged GLB/catalog |
| `road-study` | original straight 2-/4-lane art study + grass tile | source, PNG, metadata; historical widths |

Use `list --profile NAME` for exact IDs. `service-vehicles`, `traffic-signals` and
`citizen` intentionally run complete batches to satisfy their fixed verifiers.
`road-study --lanes 2` or `--lanes 4` selects a concept, not live road geometry.
Do not describe this as the full road/ramp system or all historic building assets.

## Important special contracts

- **Frame:** Blender front −Y, up +Z; glTF/Godot front +Z, up +Y. Vehicles' left +X.
  `front: +Z` in older building metadata is the **game** frame, not Blender height.
- **Cells:** 4m per cell. Ordinary growth lots 2×2, 4×4, 8×8; 8×8 is final growth
  tech only. The user removed the proposed low/medium 8×8 expansion set. Industry
  work tiles are a distinct 1×1 (4×4m) category; service parking lots may be rectangular.
- **Citizen layering:** the four PNGs are unoccluded grayscale layers. A single
  fixed draw order is wrong for swinging limbs. Preserve `layer-depths.npz` and
  the per-pixel tint/depth/alpha-over contract. Flip BOTH image and depth for
  mirrored directions. This pilot does not prove all future clothes fit.
- **Signals:** preserve separate `lamp_red`, `lamp_yellow`, `lamp_left_arrow`,
  `lamp_green`; matching on/off materials, original saved all off; arm points −X.
  A preview with four lamps on is a color test, not a valid traffic phase.
- **Seams:** match edge positions/heights/normals/materials at ±2m on work tiles.
  Check a 3×3 repetition. A generic bounds/PNG check does not prove seam continuity.
- **Roads:** right-hand traffic; ramps must join smoothly at the side; no solid
  white line across ramp entry/exit. A static road concept proves none of this logic.

## Verification and handoff honesty

`run` writes per-stage logs and `logs/run-PROFILE.json` after passing checks.
`check --workspace ...` reads generated blends and PNGs, without saving blends.
Generic checks prove finite geometry, metre scale, positive triangle count and
nonempty transparent renders with margins. Specialized signal/service/citizen
checks cover more; their precise assertions are in bundled source.

Read [verification record and limitations](references/VERIFICATION_KO.md) before
claiming support. Standalone recipe execution is tested independently of Git and
of any AI model. No claim is made that another AI model was benchmarked, that all
historical assets are recoverable, or that gameplay, traffic AI, Windows/macOS or
large-city performance has been tested by this package.
