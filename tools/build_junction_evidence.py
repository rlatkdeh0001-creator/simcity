"""Build evidence from actual Godot junction_demo viewport frames (no generated imagery)."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops

parser = argparse.ArgumentParser()
parser.add_argument('--frames', type=Path, required=True)
parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'docs/screenshots')
args = parser.parse_args()
files = sorted(args.frames.glob('*.png'))
assert len(files) >= 50, 'Expected an actual traffic recording'
args.output.mkdir(parents=True, exist_ok=True)
ids = [int(p.stem) for p in files]
durations = [(ids[i + 1] - ids[i]) * 200 for i in range(len(ids) - 1)] + [200]
frames = [Image.open(p).convert('RGB').resize((1120, 700), Image.Resampling.LANCZOS) for p in files]
assert ImageChops.difference(frames[0], frames[-1]).getbbox(), 'Recording must show actual movement'
movie = args.output / 'junctions-running.gif'
frames[0].save(movie, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=False)
closeups = [Image.open(p).convert('RGB').crop((500, 220, 850, 420)).resize((700, 400), Image.Resampling.LANCZOS) for p in files]
closeup = args.output / 'junctions-closeup.gif'
closeups[0].save(closeup, save_all=True, append_images=closeups[1:], duration=durations, loop=0, optimize=False)
photo = args.output / 'junctions-game.png'
Image.open(files[len(files) // 2]).save(photo)
with Image.open(movie) as gif:
    count = gif.n_frames
    total = 0
    for i in range(count):
        gif.seek(i)
        total += gif.info.get('duration', 0)
    assert count >= 50 and total == sum(durations)
manifest = {
    'source': 'Actual Godot 4.6.3 OpenGL viewport, junction_demo.tscn',
    'source_frame_count': len(files), 'decoded_gif_frames': count,
    'duration_ms': total, 'viewport': [1600, 1000], 'gif_size': [1120, 700],
    'closeup_crop': [500, 220, 850, 420],
    'files': [{'name': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in [movie, closeup, photo]],
}
(args.output / 'junctions-evidence.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'source_frames': len(files), 'gif_frames': count, 'duration_ms': total, 'bytes': movie.stat().st_size}))
