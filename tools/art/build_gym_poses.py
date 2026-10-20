"""Build the player gym-pose strips from raw AI images.

Raw images:  assets/generated/_raw/char_worker_<action>_<frame>_<raw>_raw.png   (gitignored)
Output:      assets/characters/generated/char_worker_<action>_<N>f_ai_v<V>.png

Usage (from repo root):
  uvx --with pillow --with numpy python tools/art/build_gym_poses.py [--only bench_press] [--preview DIR] [--work DIR]
"""
import argparse
import json
import pathlib

import numpy as np
from PIL import Image

from artlib import align_strip, derive_subpalette, head_width, load_palette, pixelize, preview, remove_bg

ROOT = pathlib.Path(__file__).resolve().parents[2]
RAW = ROOT / "assets/generated/_raw"
OUT = ROOT / "assets/characters/generated"

OUTLINE_MODE = "inner"  # recolour the silhouette edge with the palette outline colour (no size growth)
DARK_SHARE = 0.5        # dark line pixels win a block vote only when they cover >= 50 % of it
SUBPALETTE_K = 16       # k-means clusters for --derive-subpalette
# Frozen per-character sub-palette (all entries are palette.json colours). Quantising every
# frame of every action to the same ~10 colours stops material colours flickering between
# frames (e.g. black trousers flipping to dark brown). Re-derive with --derive-subpalette
# after changing raws, inspect, then paste the printed list here.
WORKER_SUBPALETTE = ["#3a3a50", "#f8f8f8", "#5a6775", "#af723b", "#ede0c2", "#774934",
                     "#a1adb7", "#d9a16a", "#3d457b", "#7758ab"]

# raw    = which raw generation to read
# cell   = (w, h) of one frame
# height = sprite content height in px of frame 0; norm="head" scales later frames to the same head width,
#          otherwise every frame is normalised to `height`
# anchor = (x, y) ground point in the cell: bottom opaque row lands on y-1, reference x (xref) on x
ACTIONS = {
    "bench_press": dict(frames=["a", "b"], raw="v3", cell=(64, 48), height=44, anchor=(32, 47), xref="feet", version=1),
    "dumbbell_curl": dict(frames=["a", "b"], raw="v2", cell=(48, 48), height=42, anchor=(24, 47), xref="feet", version=1),
    "treadmill": dict(frames=["1", "2", "3", "4"], raw="v2", norm="head", cell=(48, 48), height=42, anchor=(24, 47), xref="head",
                      y_offsets=[0, -1, 0, -1], version=1),
    "punching_bag": dict(frames=["a", "b"], raw="v2", norm="head", cell=(48, 48), height=42, anchor=(22, 47), xref="feet", version=1),
}

# "tall" profile: same poses at the scale of the LimeZu walk sheets (npc_walk_set*_48.png use
# 48x96 cells with ~64-66 px tall characters, feet on the cell bottom row). Written to OUT/tall/.
TALL = {
    "bench_press": dict(cell=(96, 72), height=66, anchor=(48, 71)),
    "dumbbell_curl": dict(cell=(48, 96), height=64, anchor=(24, 96)),
    "treadmill": dict(cell=(64, 96), height=64, anchor=(34, 96), y_offsets=[0, -2, 0, -2]),
    "punching_bag": dict(cell=(64, 96), height=64, anchor=(26, 96)),
}


def key_frames(name, cfg):
    out = []
    for f in cfg["frames"]:
        src = RAW / f"char_worker_{name}_{f}_{cfg['raw']}_raw.png"
        keyed, key = remove_bg(Image.open(src), cfg.get("tol", 90))
        out.append(keyed)
    return out


def build(name, cfg, keyed_frames, work, prev, pal, outline, outdir=OUT, tag=""):
    frames = []
    ref_head = None
    for f, keyed in zip(cfg["frames"], keyed_frames):
        keyed.save(work / f"{name}_{f}_keyed.png")  # same for every profile
        kw = dict(pal=pal, outline=outline, outline_mode=OUTLINE_MODE, mode="mode", dark_share=DARK_SHARE)
        if cfg.get("norm") == "head" and ref_head is not None:
            # same head size as frame 0 -> consistent body scale even when the pose changes height
            px, s = pixelize(keyed, scale=ref_head / head_width(keyed), **kw)
        else:
            px, s = pixelize(keyed, height=cfg["height"], **kw)
            ref_head = s * head_width(keyed)
        px.save(work / f"{name}_{f}_px{tag}.png")
        frames.append(px)
        print(f"  {name}/{f}: -> {px.size} (scale {s:.4f})")
    cw, ch = cfg["cell"]
    strip, rep = align_strip(frames, cw, ch, *cfg["anchor"], xref=cfg["xref"], y_offsets=cfg.get("y_offsets"))
    outdir.mkdir(parents=True, exist_ok=True)
    out = outdir / f"char_worker_{name}_{len(frames)}f_ai_v{cfg['version']}.png"
    strip.save(out)
    for r in rep:
        print(f"  frame {r['frame']}: size {r['size']} offset {r['offset']}" + ("  WARNING clipped" if r["clipped"] else ""))
    if prev:
        preview(strip, prev / f"{out.stem}{tag}_x4.png", 4)
    return {"file": out.relative_to(ROOT).as_posix(), "cell": [cw, ch], "frames": len(frames),
            "anchor": list(cfg["anchor"])}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--preview", default=None)
    ap.add_argument("--work", default=str(RAW / "_work"))
    ap.add_argument("--derive-subpalette", action="store_true",
                    help="re-derive the character sub-palette with k-means instead of WORKER_SUBPALETTE")
    a = ap.parse_args()
    work = pathlib.Path(a.work); work.mkdir(parents=True, exist_ok=True)
    prev = pathlib.Path(a.preview) if a.preview else None
    if prev:
        prev.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    pal, outline = load_palette()
    keyed = {name: key_frames(name, cfg) for name, cfg in ACTIONS.items()}
    if a.derive_subpalette:
        # derived from all actions together so the character keeps one colour set everywhere
        sub = derive_subpalette([im for ims in keyed.values() for im in ims], pal, k=SUBPALETTE_K)
        print("derived sub-palette:", ["#%02x%02x%02x" % tuple(int(v) for v in c) for c in sub])
    else:
        sub = np.array([[int(h[i:i + 2], 16) for i in (1, 3, 5)] for h in WORKER_SUBPALETTE], np.float32)
    res = {}
    for name, cfg in ACTIONS.items():
        if a.only and name not in a.only:
            continue
        print(name)
        res[name] = build(name, cfg, keyed[name], work, prev, sub, outline)
        res[name + "_tall"] = build(name, {**cfg, **TALL[name]}, keyed[name], work, prev, sub, outline,
                                    outdir=OUT / "tall", tag="_tall")
    print(json.dumps(res))


if __name__ == "__main__":
    main()
