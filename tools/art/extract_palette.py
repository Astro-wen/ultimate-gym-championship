"""Extract a fixed palette (colour values only) from local reference sheets.

The reference sheets are licensed and gitignored; they are read locally only.
The resulting palette.json holds nothing but RGB values and may be committed.

Usage:
  python tools/art/extract_palette.py OUT.json SHEET.png [SHEET.png ...] [--max 64] [--min-dist 10]
"""
import argparse
import json
from collections import Counter

import numpy as np
from PIL import Image


def collect(paths):
    cnt = Counter()
    for p in paths:
        a = np.asarray(Image.open(p).convert("RGBA"))
        px = a[a[..., 3] >= 128][:, :3]
        cnt.update(map(tuple, px.tolist()))
    return cnt


def pick(cnt, max_colors, min_dist):
    chosen = []
    for col, _ in cnt.most_common():
        c = np.array(col, dtype=float)
        if all(np.linalg.norm(c - np.array(o, dtype=float)) >= min_dist for o in chosen):
            chosen.append(col)
        if len(chosen) >= max_colors:
            break
    return chosen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("sheets", nargs="+")
    ap.add_argument("--max", type=int, default=64)
    ap.add_argument("--min-dist", type=float, default=10)
    a = ap.parse_args()
    cnt = collect(a.sheets)
    cols = pick(cnt, a.max, a.min_dist)
    # outline = darkest colour that is frequent in the character sheet
    outline = min(cols, key=lambda c: sum(c))
    data = {
        "note": "RGB colour values only, extracted locally from reference sheets (sheets not included).",
        "outline": "#%02x%02x%02x" % outline,
        "colors": ["#%02x%02x%02x" % c for c in cols],
    }
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    print(f"{len(cols)} colours (from {len(cnt)} unique); outline {data['outline']}")


if __name__ == "__main__":
    main()
