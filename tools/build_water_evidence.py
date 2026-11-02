from pathlib import Path
from PIL import Image,ImageChops
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--frames',type=Path,required=True)
parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'docs/screenshots')
args=parser.parse_args()
files=sorted(args.frames.glob('*.png'))
assert len(files)>=70
out=args.output
out.mkdir(parents=True,exist_ok=True)
frames=[Image.open(p).convert('RGB').resize((1120,700),Image.Resampling.LANCZOS) for p in files]
assert any(ImageChops.difference(frames[0],im).getbbox() for im in frames[1:])
frames[0].save(out/'water-game-running.gif',save_all=True,append_images=frames[1:],duration=125,loop=0,optimize=False)
gif=Image.open(out/'water-game-running.gif')
assert gif.n_frames==len(frames)
for index,name in [(24,'domestic'),(48,'export'),(80,'import')]:
 Image.open(files[min(index,len(files)-1)]).save(out/f'water-game-{name}.png')
# Actual viewport close-up of the pipe junction; retain native pixels.
closeups=[Image.open(p).convert('RGB').crop((490,330,890,500)).resize((800,340),Image.Resampling.LANCZOS) for p in files[:32]]
closeups[0].save(out/'water-flow-closeup.gif',save_all=True,append_images=closeups[1:],duration=125,loop=0,optimize=False)
print(f'{len(frames)} decoded frames, {gif.size}, { (out/"water-game-running.gif").stat().st_size} bytes')
