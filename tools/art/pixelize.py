"""Crop -> downscale -> palette-quantise -> binary alpha -> 1px dark outline.

Input must already have a transparent background (see remove_bg.py).
Usage: python tools/art/pixelize.py IN.png OUT.png --height 42 [--mode mode|box] [--outline inner|outer|none]
"""
import argparse

from PIL import Image

from artlib import load_palette, pixelize

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--height", type=int, default=42, help="final content height (incl. outline)")
ap.add_argument("--mode", default="mode", choices=["mode", "box"])
ap.add_argument("--outline", default="inner", choices=["inner", "outer", "none"])
ap.add_argument("--dark-share", type=float, default=0.5)
a = ap.parse_args()
pal, outline = load_palette()
img, s = pixelize(Image.open(a.src), height=a.height, pal=pal, outline=outline,
                  outline_mode=a.outline, mode=a.mode, dark_share=a.dark_share)
img.save(a.dst)
print(f"{a.dst}: {img.size} scale {s:.4f}")
