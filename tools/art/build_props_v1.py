"""Small AI props (LimeZu Modern Interiors style): AI raw -> 3x3-block pixel sprite in a fixed cell.

Same pipeline as build_gym_poses_v2.py: key out the magenta background, find the AI image's own block grid,
sample one colour per block (quantised to the prop's LimeZu-derived palette), fix the height to the target
logical height (delete / double redundant rows, or resample when the AI's block count is far off), drop specks,
1 logical px outline #3a3a50, place bottom-centre on the anchor, nearest-neighbour x3.

Raw: assets/generated/_raw/props/<prop>_<frame>.png (gitignored).
Out: assets/sprites/props/prop_<prop>_<N>f_ai_v1.png

Usage: python tools/art/build_props_v1.py [--only water_bottle] [--preview DIR]
"""
import argparse
import json
import pathlib

import numpy as np
from PIL import Image

from artlib import _largest_islands, bbox, remove_bg
from build_gym_poses_v2 import S, _row_cost, add_outline, drop_specks, find_pitch, fit_rows, quantize_to, sample_grid
from props_v1_config import PROPS

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RAW = ROOT / "assets" / "generated" / "_raw" / "props"
OUT = ROOT / "assets" / "sprites" / "props"


def hex2rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


SEAM_MAX = 8


def fit_cols_inner(lg, max_w):
    """drop the most redundant inner columns (never the outermost ones) until the sprite is <= max_w wide."""
    while lg.shape[1] > max_w:
        t = lg.transpose(1, 0, 2)
        j = min((_row_cost(t, j), abs(j - (len(t) - 1) / 2), j) for j in range(1, len(t) - 1))[2]
        lg = np.delete(lg, j, 1)
    return lg


def trim(lg):
    """drop fully transparent border rows / columns (the AI's grid rarely starts exactly at the bbox)."""
    al = lg[..., 3] > 0
    ys, xs = np.nonzero(al.any(1))[0], np.nonzero(al.any(0))[0]
    return lg[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def to_logical(raw, pal, target_h, max_w):
    keyed, _ = remove_bg(raw, tol=110)
    a = np.asarray(keyed)
    alpha = _largest_islands(a[..., 3] >= 128, 0.02)
    x0, y0, x1, y1 = bbox(alpha)
    a, alpha = a[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
    rgb = quantize_to(a[..., :3], pal)
    # props are drawn with very few, very big blocks: allow a much larger pitch than the characters
    p, score = find_pitch(rgb, alpha, pmin=12.0, pmax=240.0)
    rows, cols = max(1, round(alpha.shape[0] / p)), max(1, round(alpha.shape[1] / p))
    info = {"raw_size": list(raw.size), "crop": [int(x1 - x0), int(y1 - y0)], "grid": [int(cols), int(rows)],
            "grid_score": round(float(score), 2)}
    if abs(rows - target_h) <= SEAM_MAX:
        # keep the AI's own blocks; shrink by deleting the most redundant rows / columns (a bottle body is
        # mostly repeated rows, so this keeps the cap, the spout, the band and the outline intact)
        lg = trim(fit_cols_inner(trim(sample_grid(rgb, alpha, rows, cols)), max_w))
        lg = fit_rows(lg, target_h)
        info["fitted_from"] = [int(cols), int(rows)]
    else:
        cols = min(max_w, max(1, round(alpha.shape[1] * target_h / alpha.shape[0])))
        info["resampled_to"] = [int(cols), int(target_h)]
        lg = sample_grid(rgb, alpha, target_h, cols)
    return lg, info


def build(name, prev=None):
    spec = PROPS[name]
    pal = [hex2rgb(h) for h in spec["palette"]]
    cw, ch = spec["cell"][0] // S, spec["cell"][1] // S
    ax, ay = spec["anchor"][0] / S, spec["anchor"][1] / S
    strip = np.zeros((ch, cw * spec["frames"], 4), np.uint8)
    infos = []
    for f in range(spec["frames"]):
        raw = Image.open(RAW / f"{name}_{f}.png").convert("RGB")
        lg, info = to_logical(raw, pal, spec["target_h"], spec["max_w"])
        lg = add_outline(drop_specks(lg))
        al = lg[..., 3] > 0
        ys, xs = np.nonzero(al.any(1))[0], np.nonzero(al.any(0))[0]
        lg = lg[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        h, w = lg.shape[:2]
        ox, oy = int(np.floor(ax - w / 2 + 0.5)), int(round(ay - h))
        strip[oy:oy + h, f * cw + ox:f * cw + ox + w] = lg
        info.update({"logical": [int(w), int(h)], "offset": [ox, oy]})
        infos.append(info)
    big = Image.fromarray(np.repeat(np.repeat(strip, S, 0), S, 1), "RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"prop_{name}_{spec['frames']}f_ai_v1.png"
    big.save(out)
    if prev:
        bg = Image.new("RGBA", big.size, (150, 160, 150, 255)); bg.alpha_composite(big)
        bg.resize((big.width * 8, big.height * 8), Image.NEAREST).convert("RGB").save(prev / f"{name}_qa.png")
    rel = out.relative_to(ROOT).as_posix() if out.is_relative_to(ROOT) else str(out)
    return {"file": rel, "size": big.size, "frames": infos}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--preview", default=None, help="write QA images here (keep outside the repo)")
    a = ap.parse_args()
    prev = pathlib.Path(a.preview) if a.preview else None
    if prev:
        prev.mkdir(parents=True, exist_ok=True)
    for name in PROPS:
        if a.only and name not in a.only:
            continue
        r = build(name, prev)
        print(r["file"], r["size"])
        for fr in r["frames"]:
            print("   ", json.dumps(fr))


if __name__ == "__main__":
    main()
