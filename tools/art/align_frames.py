"""Align pixelized frames on a common anchor and join them into a horizontal strip.

Usage:
  python tools/art/align_frames.py OUT.png F1.png F2.png ... --cell 48x48 --anchor 24,46 [--xref feet|head|bbox]
The anchor is the ground point: the bottom opaque row of each frame lands on
anchor_y - 1 and the reference x (see artlib.anchor_of) lands on anchor_x.
"""
import argparse

from PIL import Image

from artlib import align_strip

ap = argparse.ArgumentParser()
ap.add_argument("dst"); ap.add_argument("frames", nargs="+")
ap.add_argument("--cell", default="48x48")
ap.add_argument("--anchor", default="24,46")
ap.add_argument("--xref", default="feet", choices=["feet", "head", "bbox"])
a = ap.parse_args()
cw, ch = map(int, a.cell.split("x"))
ax, ay = map(int, a.anchor.split(","))
strip, rep = align_strip([Image.open(f).convert("RGBA") for f in a.frames], cw, ch, ax, ay, a.xref)
strip.save(a.dst)
for r in rep:
    print(r)
