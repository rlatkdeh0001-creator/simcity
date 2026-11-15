"""Portable, local-only font resolution; no network or proprietary bundled fonts."""
import os
from pathlib import Path


def font_paths():
    override = os.environ.get('CITIES_DO_FONT')
    if override:
        p = Path(override).expanduser()
        if not p.is_file():
            raise FileNotFoundError(f'CITIES_DO_FONT does not exist: {p}')
        yield p
    for name in (
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf',
        '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf',
        '/Library/Fonts/DejaVuSans.ttf',
    ):
        p = Path(name)
        if p.is_file():
            yield p


def load_blender_font():
    import bpy
    path = next(font_paths(), None)
    if path:
        return bpy.data.fonts.load(str(path))
    curve = bpy.data.curves.new('AssetKitBuiltinFontProbe', 'FONT')
    font = curve.font
    bpy.data.curves.remove(curve)
    return font


def pil_font(size):
    from PIL import ImageFont
    override = os.environ.get('CITIES_DO_FONT')
    cjk = Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
    path = next(font_paths(), None) if override or not cjk.is_file() else cjk
    return ImageFont.truetype(str(path), size) if path else ImageFont.load_default(size=size)
