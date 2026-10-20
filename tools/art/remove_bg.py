"""Key a flat background colour out to transparency.

Usage: python tools/art/remove_bg.py IN.png OUT.png [--tol 90] [--key ff00ff]
"""
import argparse

from PIL import Image

from artlib import remove_bg

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--tol", type=float, default=90)
ap.add_argument("--key", default=None, help="hex rgb; default = median of border pixels")
a = ap.parse_args()
key = tuple(int(a.key[i:i + 2], 16) for i in (0, 2, 4)) if a.key else None
img, k = remove_bg(Image.open(a.src), a.tol, key)
img.save(a.dst)
print(f"{a.dst}: keyed {k}")
