"""v2 gym poses: AI raws -> LimeZu-matched pixel strips (3x3-block pixels, character's own colours).

For every char_id x action (see gym_poses_v2_config.py):
  1. key out the flat magenta background, keep the main islands, crop to the bounding box;
  2. find the AI image's own pixel grid (block pitch, from run lengths) and sample one colour per block;
     target height = the character's standing frame in the matching direction of its LimeZu walk sheet / 3;
     within SEAM_MAX blocks of it, the height is fixed by deleting / doubling the most redundant rows,
     otherwise the crop is resampled straight onto the target grid; a too-wide bench barbell loses
     redundant columns from its outer thirds;
  3. quantise to the character's own walk-sheet colours (+ a few LimeZu gym-equipment greys), binary alpha;
  4. 1 logical px outline: edge pixels that are not already a dark line colour become the walk-sheet outline;
  5. place each frame on the logical cell at the anchor (lowest pixel on the cell's last row, kept inside the cell),
     nearest-neighbour x3, join frames horizontally.

Raws are read from assets/generated/_raw/v2/<char_id>_<action>_<frame>.png (gitignored).
The LimeZu sheets (assets/sheets/, gitignored) are read from this checkout or, in a git worktree,
from the main checkout; pass --sheets to override.

Usage: python tools/art/build_gym_poses_v2.py [--only player:bench_press ...] [--preview DIR]
"""
import argparse
import json
import pathlib
import subprocess
from collections import Counter

import numpy as np
from PIL import Image

from artlib import _largest_islands, _to_lab_ish, bbox, remove_bg
from gym_poses_v2_config import ACTIONS, CHARS

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
RAW = ROOT / "assets" / "generated" / "_raw" / "v2"
OUT = ROOT / "assets" / "characters" / "generated" / "v2"
S = 3  # LimeZu: one logical pixel = 3x3 screen pixels

OUTLINE = (58, 58, 80)          # #3a3a50, the walk-sheet outline colour
LINE_COLOURS = {(58, 58, 80), (70, 70, 94)}  # dark line colours LimeZu also uses on silhouette edges
# greys of the LimeZu gym-equipment sheet (int05_gym_equipment_768.png / 3), for barbells and dumbbells
EQUIP_GREYS = [(58, 58, 80), (70, 70, 94), (86, 89, 114), (108, 110, 133), (157, 163, 183), (198, 189, 213)]

# which part of the sprite is centred on the anchor x: symmetric views use the head (stable while legs and
# arms move) or the bbox (bench: symmetric barbell); the side-view boxer uses the feet
X_REF = {"bench_press": "bbox", "dumbbell_curl": "head", "treadmill": "head", "punching_bag": "feet"}


def sheets_dir(arg):
    if arg:
        return pathlib.Path(arg)
    local = ROOT / "assets" / "sheets" / "characters"
    if local.exists():
        return local
    common = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--git-common-dir"], capture_output=True,
                            text=True).stdout.strip()
    return (ROOT / common).resolve().parent / "assets" / "sheets" / "characters"


# ------------------------------------------------------------------ reference (walk sheet)
def walk_block(sheets, cid):
    c = CHARS[cid]
    sh = Image.open(sheets / f"npc_walk_set{c['set']}_48.png").convert("RGBA")
    c0, r0 = (c["index"] % 4) * 3, (c["index"] // 4) * 4
    return np.asarray(sh.crop((c0 * 48, r0 * 96, c0 * 48 + 144, r0 * 96 + 384)))


def char_palette(block):
    lg = block[::S, ::S]
    cols = {tuple(int(v) for v in p[:3]) for p in lg.reshape(-1, 4) if p[3] > 0}
    return sorted(cols | set(EQUIP_GREYS))


def stand_height(block, direction):
    """logical height of the standing frame (middle column) for direction 0..3 (down, left, right, up)."""
    f = block[direction * 96:(direction + 1) * 96, 48:96, 3] > 0
    ys = np.nonzero(f.any(1))[0]
    return (ys.max() + 1 - ys.min()) // S


def stand_frame(block, direction):
    return Image.fromarray(block[direction * 96:(direction + 1) * 96, 48:96].copy())


# ------------------------------------------------------------------ AI raw -> logical sprite
def quantize_to(rgb, pal):
    p = np.array(pal, np.float32)
    uniq, inv = np.unique(rgb.reshape(-1, 3), axis=0, return_inverse=True)
    d = ((_to_lab_ish(uniq.astype(np.float32))[:, None, :] - _to_lab_ish(p)[None]) ** 2).sum(-1)
    return p[d.argmin(1)][inv.ravel()].reshape(rgb.shape).astype(np.uint8)


def _runs(lab):
    """lengths of horizontal runs of one label in a 2-D int array (label -1 = transparent, ignored)."""
    out = []
    for row in lab:
        cut = np.nonzero(np.diff(row))[0] + 1
        starts = np.concatenate([[0], cut]); ends = np.concatenate([cut, [len(row)]])
        out += [e - s for s, e in zip(starts, ends) if row[s] >= 0]
    return np.array(out, np.float32)


def find_pitch(q, alpha, pmin=12.0, pmax=90.0):
    """Block size of the AI's own pixel grid, from run lengths of the quantised image.
    Runs of a flat colour are whole multiples of the block size; the largest pitch that explains
    (almost) as many runs as the best one wins, so sub-multiples (p/2, p/3) are not picked."""
    _, lab = np.unique(q.reshape(-1, 3), axis=0, return_inverse=True)
    lab = lab.reshape(alpha.shape).astype(np.int64)
    lab[~alpha] = -1
    r = np.concatenate([_runs(lab), _runs(lab.T)])
    r = r[r >= pmin * 0.6]
    ps = np.arange(pmin, pmax, 0.25)
    sc = []
    for p in ps:
        k = np.round(r / p)
        ok = (k >= 1) & (np.abs(r - k * p) <= 0.15 * p)
        sc.append((ok * r).sum() / r.sum())  # long runs count more
    sc = np.array(sc)
    good = np.nonzero(sc >= 0.93 * sc.max())[0]
    i = good.max()
    return float(ps[i]), float(sc[i])


def find_grid(q, alpha):
    """Return (rows, cols, score): the AI image's own block grid inside the cropped bbox."""
    h, w = alpha.shape
    p, score = find_pitch(q, alpha)
    return max(1, round(h / p)), max(1, round(w / p)), score

def sample_grid(rgb, alpha, rows, cols):
    h, w = alpha.shape
    out = np.zeros((rows, cols, 4), np.uint8)
    ys = np.linspace(0, h, rows + 1); xs = np.linspace(0, w, cols + 1)
    for j in range(rows):
        for i in range(cols):
            # central 50% of the block avoids the AI's soft block edges
            y0, y1 = ys[j] + (ys[j + 1] - ys[j]) * .25, ys[j] + (ys[j + 1] - ys[j]) * .75
            x0, x1 = xs[i] + (xs[i + 1] - xs[i]) * .25, xs[i] + (xs[i + 1] - xs[i]) * .75
            sl = (slice(int(y0), max(int(y0) + 1, int(np.ceil(y1)))), slice(int(x0), max(int(x0) + 1, int(np.ceil(x1)))))
            a = alpha[sl]
            if a.mean() < 0.5:
                continue
            px = rgb[sl][a].reshape(-1, 3)
            cols_, cnt = np.unique(px, axis=0, return_counts=True)
            out[j, i, :3] = cols_[cnt.argmax()]
            out[j, i, 3] = 255
    return out


def to_logical(raw, pal, target_h, key=None):
    """raw RGB(A) AI image -> (logical RGBA uint8 array, info dict)."""
    keyed, k = remove_bg(raw, tol=110, key=key)
    a = np.asarray(keyed)
    alpha = _largest_islands(a[..., 3] >= 128, 0.004)
    x0, y0, x1, y1 = bbox(alpha)
    a, alpha = a[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
    # quantise at full resolution so block sampling votes on final colours
    rgb = quantize_to(a[..., :3], pal)
    rows, cols, score = find_grid(rgb, alpha)
    info = {"raw_size": list(raw.size), "crop": [int(x1 - x0), int(y1 - y0)], "grid": [int(cols), int(rows)],
            "grid_score": round(float(score), 2), "target_h": int(target_h)}
    if abs(rows - target_h) <= SEAM_MAX:
        # AI already drew (almost) the right block count: keep its pixels, fix the height by
        # removing / doubling the most redundant rows (pixel-art friendly, keeps eyes and outlines)
        lg = fit_rows(sample_grid(rgb, alpha, rows, cols), target_h)
        if rows != target_h:
            info["rows_fixed"] = int(rows - target_h)
        return lg, info
    # otherwise resample the crop straight onto the target grid (same aspect as the AI's own blocks)
    cols = max(1, round(alpha.shape[1] * target_h / alpha.shape[0]))  # square blocks
    info["resampled_to"] = [int(cols), int(target_h)]
    return sample_grid(rgb, alpha, target_h, cols), info


SEAM_MAX = 6


def _row_cost(lg, j):
    """how much information is lost if row j is merged into a neighbour."""
    def diff(a, b):
        return int((np.any(a != b, -1)).sum())
    c = []
    if j > 0:
        c.append(diff(lg[j], lg[j - 1]))
    if j < len(lg) - 1:
        c.append(diff(lg[j], lg[j + 1]))
    return min(c)


def fit_rows(lg, target):
    """remove/duplicate whole rows (never the outermost ones) until the sprite is `target` rows tall."""
    while len(lg) > target:
        costs = [(_row_cost(lg, j), abs(j - len(lg) * 0.6), j) for j in range(1, len(lg) - 1)]
        j = min(costs)[2]
        lg = np.delete(lg, j, 0)
    while len(lg) < target:
        costs = [(_row_cost(lg, j), abs(j - len(lg) * 0.6), j) for j in range(1, len(lg) - 1)]
        j = min(costs)[2]
        lg = np.insert(lg, j, lg[j], 0)
    return lg


def fit_cols(lg, max_w):
    """too wide (e.g. a long barbell): drop the most redundant columns, alternately from the left and
    right outer thirds (never the body in the middle third), so the sprite stays symmetric."""
    side = 0
    while lg.shape[1] > max_w:
        t = lg.transpose(1, 0, 2)
        w = len(t)
        rng = range(1, w // 3) if side == 0 else range(w - w // 3, w - 1)
        j = min((_row_cost(t, j), j) for j in rng)[1]
        lg = np.delete(lg, j, 1)
        side ^= 1
    return lg


def add_outline(lg):
    """1 logical px outline: silhouette edge pixels that are not a dark line colour become OUTLINE."""
    op = lg[..., 3] > 0
    pad = np.pad(op, 1)
    edge = op & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    out = lg.copy()
    for y, x in zip(*np.nonzero(edge)):
        if tuple(int(v) for v in out[y, x, :3]) not in LINE_COLOURS:
            out[y, x, :3] = OUTLINE
    return out


def drop_specks(lg):
    """remove opaque logical pixels with no 4-neighbour (single-pixel noise)."""
    op = lg[..., 3] > 0
    pad = np.pad(op, 1)
    lone = op & ~(pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
    out = lg.copy(); out[lone] = 0
    return out


def x_anchor(lg, ref):
    al = lg[..., 3] > 0
    ys = np.nonzero(al.any(1))[0]
    y0, y1 = ys.min(), ys.max() + 1
    if ref == "head":
        rows = al[y0:y0 + max(1, int((y1 - y0) * 0.35))]
    elif ref == "feet":
        rows = al[y1 - 2:y1]
    else:
        rows = al
    xs = np.nonzero(rows.any(0))[0]
    return (xs.min() + xs.max() + 1) / 2, y1


def place(frames, cell, anchor, ref, x_shift=None):
    cw, ch = cell[0] // S, cell[1] // S
    ax, ay = anchor[0] / S, anchor[1] / S
    strip = np.zeros((ch, cw * len(frames), 4), np.uint8)
    rep = []
    for k, lg in enumerate(frames):
        fx, fy = x_anchor(lg, ref)
        ox = int(np.floor(ax - fx + 0.5)) + (x_shift[k] if x_shift else 0)
        oy = int(round(ay - fy))
        h, w = lg.shape[:2]
        if w <= cw:  # keep the whole sprite inside the cell (wide barbells / long punches)
            ox = min(max(ox, 0), cw - w)
        clipped = ox < 0 or oy < 0 or ox + w > cw or oy + h > ch
        sx0, sy0 = max(0, -ox), max(0, -oy)
        dx0, dy0 = max(0, ox), max(0, oy)
        dx1, dy1 = min(cw, ox + w), min(ch, oy + h)
        strip[dy0:dy1, k * cw + dx0:k * cw + dx1] = lg[sy0:sy0 + dy1 - dy0, sx0:sx0 + dx1 - dx0]
        rep.append({"frame": k, "logical": [w, h], "offset": [ox, oy], "clipped": bool(clipped)})
    big = np.repeat(np.repeat(strip, S, 0), S, 1)
    return Image.fromarray(big, "RGBA"), rep


def qa_sheet(path, strip, cell, stand, n):
    """frames next to the walk-sheet standing frame, x4, on a mid grey."""
    cw, ch = cell
    W = 48 + 8 + strip.width
    H = max(96, ch)
    img = Image.new("RGBA", (W, H), (150, 160, 150, 255))
    img.alpha_composite(stand, (0, H - 96))
    img.alpha_composite(strip, (56, H - ch))
    img.resize((W * 4, H * 4), Image.NEAREST).convert("RGB").save(path)


def build(cid, action, sheets, prev):
    spec = ACTIONS[action]
    block = walk_block(sheets, cid)
    pal = char_palette(block)
    th = stand_height(block, spec["walk_dir"])
    frames, infos = [], []
    for f in range(spec["frames"]):
        raw = Image.open(RAW / f"{cid}_{action}_{f}.png").convert("RGB")
        # target height; never taller than the cell (goer_blue's hair tufts make her 25 tall)
        lg, info = to_logical(raw, pal, min(th + spec.get("extra_h", 0), spec["cell"][1] // S))
        if spec.get("fit_width") and lg.shape[1] > spec["cell"][0] // S:
            info["cols_removed"] = int(lg.shape[1] - spec["cell"][0] // S)
            lg = fit_cols(lg, spec["cell"][0] // S)
        lg = add_outline(drop_specks(lg))
        frames.append(lg); infos.append(info)
    strip, rep = place(frames, spec["cell"], spec["anchor"], X_REF[action])
    out = OUT / f"char_{cid}_{action}_{spec['frames']}f_ai_v2.png"
    OUT.mkdir(parents=True, exist_ok=True)
    strip.save(out)
    used = Counter(tuple(int(v) for v in p[:3]) for p in np.asarray(strip).reshape(-1, 4)[::1] if p[3])
    if prev:
        qa_sheet(prev / f"{cid}_{action}_qa.png", strip, spec["cell"], stand_frame(block, spec["walk_dir"]),
                 spec["frames"])
    for i, r in zip(infos, rep):
        r.update(i)
    return {"file": out.relative_to(ROOT).as_posix(), "size": strip.size, "cell": spec["cell"],
            "anchor": spec["anchor"], "target_h": int(th), "colours": len(used), "frames": rep}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="char_id:action items")
    ap.add_argument("--sheets", default=None, help="dir with npc_walk_set*_48.png (LimeZu, not in git)")
    ap.add_argument("--preview", default=None, help="write QA sheets here (keep outside the repo)")
    a = ap.parse_args()
    sheets = sheets_dir(a.sheets)
    prev = pathlib.Path(a.preview) if a.preview else None
    if prev:
        prev.mkdir(parents=True, exist_ok=True)
    res = []
    for cid in CHARS:
        for action in ACTIONS:
            if a.only and f"{cid}:{action}" not in a.only:
                continue
            r = build(cid, action, sheets, prev)
            res.append(r)
            print(r["file"], r["size"], "target_h", r["target_h"], "colours", r["colours"])
            for fr in r["frames"]:
                print("   ", json.dumps(fr))


if __name__ == "__main__":
    main()
