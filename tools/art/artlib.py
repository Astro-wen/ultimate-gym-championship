"""Shared helpers for the AI-sprite post-processing pipeline.

remove_bg  -> flat background colour keyed to transparency
pixelize   -> crop, downscale to a target height, palette-quantise, binarise alpha, 1px outline
align      -> place frames on equal cells at a common anchor and join into a horizontal strip
"""
import json
import pathlib

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent


# ---------------------------------------------------------------- palette
def load_palette(path=HERE / "palette.json"):
    d = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    hx = lambda s: tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))
    return np.array([hx(c) for c in d["colors"]], dtype=np.float32), np.array(hx(d["outline"]), dtype=np.uint8)


def _to_lab_ish(rgb):
    """sRGB (0-255) -> CIELAB (D65) for nearest-colour matching."""
    c = np.asarray(rgb, np.float32) / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]], np.float32)
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883], np.float32)
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    # lightness x1.5 and red-green x1.4 so near-black cloth maps to the navy darks, not to dark browns
    L = (116 * f[..., 1] - 16) * 1.5
    A = 500 * (f[..., 0] - f[..., 1]) * 1.4
    B = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, A, B], -1)


def quantize(rgb, pal):
    """rgb: (...,3) float/uint8 -> (...,3) uint8 nearest palette colour."""
    flat = rgb.reshape(-1, 3).astype(np.float32)
    a = _to_lab_ish(flat)
    p = _to_lab_ish(pal)
    out = np.empty(len(flat), dtype=np.int64)
    for i in range(0, len(flat), 65536):
        d = ((a[i:i + 65536, None, :] - p[None, :, :]) ** 2).sum(-1)
        out[i:i + 65536] = d.argmin(1)
    return pal[out].reshape(rgb.shape).astype(np.uint8)


def derive_subpalette(images, pal, k=16, seed=0, iters=25, sample=60000):
    """Pick a small per-character sub-palette so every frame maps materials to the same colours.
    Pools opaque pixels of all images, runs k-means in Lab, snaps centroids to the nearest
    palette colour. Returns (m,3) float32 array of palette colours."""
    px = []
    for im in images:
        a = np.asarray(im.convert("RGBA"))
        px.append(a[a[..., 3] >= 128][:, :3])
    px = np.concatenate(px).astype(np.float32)
    rng = np.random.default_rng(seed)
    if len(px) > sample:
        px = px[rng.choice(len(px), sample, replace=False)]
    X = _to_lab_ish(px)
    # k-means++ init
    C = [X[rng.integers(len(X))]]
    for _ in range(k - 1):
        d = np.min(((X[:, None, :] - np.array(C)[None]) ** 2).sum(-1), 1)
        C.append(X[rng.choice(len(X), p=d / d.sum())])
    C = np.array(C)
    for _ in range(iters):
        lab = ((X[:, None, :] - C[None]) ** 2).sum(-1).argmin(1)
        C = np.array([X[lab == j].mean(0) if (lab == j).any() else C[j] for j in range(k)])
    P = _to_lab_ish(pal)
    idx = sorted(set(((C[:, None, :] - P[None]) ** 2).sum(-1).argmin(1).tolist()))
    return pal[idx]


def head_width(img, top_frac=0.22):
    """Robust head width (px) of a keyed image: 90th percentile row span in the top rows."""
    al = np.asarray(img.convert("RGBA"))[..., 3] >= 128
    x0, y0, x1, y1 = bbox(al)
    rows = al[y0:y0 + max(2, int((y1 - y0) * top_frac))]
    spans = [np.ptp(np.nonzero(r)[0]) + 1 for r in rows if r.any()]
    return float(np.percentile(spans, 90))


# ---------------------------------------------------------------- remove_bg
def remove_bg(img, tol=90, key=None):
    """Key out a flat background. The key colour is the median of the border pixels
    unless given. Only pixels connected to the border are removed (flood fill), plus
    any isolated pocket that is very close to the key colour (e.g. between legs)."""
    a = np.asarray(img.convert("RGBA")).astype(np.int32)
    rgb = a[..., :3]
    h, w = rgb.shape[:2]
    if key is None:
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        key = np.median(border, axis=0)
    dist = np.sqrt(((rgb - np.asarray(key)) ** 2).sum(-1))
    bgish = dist < tol
    # flood fill from border through bg-ish pixels
    from collections import deque
    seen = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bgish[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if bgish[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and bgish[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    mask = seen | (dist < tol * 0.5)
    out = a.copy().astype(np.uint8)
    out[..., 3] = np.where(mask, 0, a[..., 3]).astype(np.uint8)
    # despill: pull magenta fringe toward neutral on remaining pixels near the key
    near = (~mask) & (dist < tol * 1.6)
    if near.any():
        px = out[..., :3].astype(np.float32)
        g = px[..., 1]
        px[..., 0] = np.where(near, np.minimum(px[..., 0], g + 40), px[..., 0])
        px[..., 2] = np.where(near, np.minimum(px[..., 2], g + 40), px[..., 2])
        out[..., :3] = px.astype(np.uint8)
    return Image.fromarray(out, "RGBA"), tuple(int(v) for v in key)


# ---------------------------------------------------------------- pixelize
def bbox(arr_alpha):
    ys, xs = np.nonzero(arr_alpha)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def _largest_islands(alpha, min_frac=0.01):
    """Pure-numpy connected components (4-neighbour) keeping islands >= min_frac of opaque area."""
    h, w = alpha.shape
    lab = np.zeros((h, w), np.int32)
    cur = 0
    sizes = {}
    from collections import deque
    for y0, x0 in zip(*np.nonzero(alpha)):
        if lab[y0, x0]:
            continue
        cur += 1
        lab[y0, x0] = cur
        q = deque([(y0, x0)]); n = 0
        while q:
            y, x = q.popleft(); n += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and alpha[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = cur; q.append((ny, nx))
        sizes[cur] = n
    total = alpha.sum()
    keep = [k for k, s in sizes.items() if s >= total * min_frac]
    return np.isin(lab, keep)


def pixelize(img, scale=None, height=None, pal=None, outline=None, outline_mode="outer",
             mode="mode", min_island=0.01, dark_share=0.34):
    """img: RGBA with transparent background.
    scale: final px per source px (wins over height). height: target content height
    in px *including* the 1px outline when outline_mode == 'outer'.
    outline_mode: 'outer' = add a 1px ring outside the silhouette (grows by 1px per side),
                  'inner' = recolour the silhouette's own edge pixels, 'none'.
    mode: 'mode' = per-block majority palette colour (dark line pixels win at >= dark_share),
          'box'  = Lanczos downscale then palette quantise."""
    a = np.asarray(img.convert("RGBA"))
    alpha = a[..., 3] >= 128
    if min_island:
        alpha = _largest_islands(alpha, min_island)
    x0, y0, x1, y1 = bbox(alpha)
    a = a[y0:y1, x0:x1].copy()
    alpha = alpha[y0:y1, x0:x1]
    sh, sw = alpha.shape
    add_outline = outline_mode == "outer"
    pad = 2 if add_outline else 0
    if scale is None:
        scale = (height - pad) / sh
    th, tw = max(1, round(sh * scale)), max(1, round(sw * scale))
    out = np.zeros((th, tw, 4), np.uint8)
    ys = np.linspace(0, sh, th + 1).round().astype(int)
    xs = np.linspace(0, sw, tw + 1).round().astype(int)
    dark_thr = 200  # sum of rgb below which a colour counts as "line"
    # mode: quantise at full res first so block voting works on palette colours
    rgb = quantize(a[..., :3], pal) if (pal is not None and mode != "box") else a[..., :3]
    for j in range(th if mode != "box" else 0):
        for i in range(tw):
            blk_a = alpha[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
            if blk_a.size == 0 or blk_a.mean() < 0.5:
                continue
            blk = rgb[ys[j]:ys[j + 1], xs[i]:xs[i + 1]][blk_a]
            cols, counts = np.unique(blk.reshape(-1, 3), axis=0, return_counts=True)
            # keep thin dark line work: if dark pixels are a decent minority, prefer them
            dark = cols.sum(1) < dark_thr
            share = counts[dark].sum() / counts.sum()
            if dark.any() and share >= dark_share:
                k = np.argmax(np.where(dark, counts, -1))
            else:
                k = np.argmax(counts)
            c = cols[k]
            out[j, i, :3] = c
            out[j, i, 3] = 255
    if mode == "box":
        # Lanczos on premultiplied colour, then binarise alpha and quantise
        pm = a.astype(np.float32)
        pm[..., :3] = rgb.astype(np.float32) * alpha[..., None]
        pm[..., 3] = alpha * 255.0
        small = np.stack([np.asarray(Image.fromarray(pm[..., c]).resize((tw, th), Image.LANCZOS)) for c in range(4)], -1)
        al = small[..., 3] >= 127.5
        col = small[..., :3] / np.maximum(small[..., 3:4] / 255.0, 1e-3)
        col = np.clip(col, 0, 255)
        out[al, :3] = quantize(col[al], pal) if pal is not None else col[al].astype(np.uint8)
        out[al, 3] = 255
        out[~al] = 0
    oc = outline if outline is not None else np.array([58, 58, 80], np.uint8)
    res = out
    if outline_mode == "outer":
        res = np.zeros((th + 2, tw + 2, 4), np.uint8)
        res[1:-1, 1:-1] = out
        op = res[..., 3] > 0
        ring = np.zeros_like(op)
        ring[1:, :] |= op[:-1, :]; ring[:-1, :] |= op[1:, :]
        ring[:, 1:] |= op[:, :-1]; ring[:, :-1] |= op[:, 1:]
        ring &= ~op
        res[ring, :3] = oc
        res[ring, 3] = 255
    elif outline_mode == "inner":
        op = res[..., 3] > 0
        pad_op = np.pad(op, 1)
        inner = op & ~(pad_op[:-2, 1:-1] & pad_op[2:, 1:-1] & pad_op[1:-1, :-2] & pad_op[1:-1, 2:])
        res = res.copy()
        res[inner, :3] = oc
    return Image.fromarray(res, "RGBA"), scale


# ---------------------------------------------------------------- align
def anchor_of(img, xref="feet", feet_rows=4):
    """Return (ax, ay) anchor in sprite pixel coords.
    ay = bottom opaque row (+1, i.e. the ground line).
    xref: 'feet' = centre of the opaque span in the bottom `feet_rows` rows,
          'head' = centre of the opaque span in the top 30% of rows,
          'bbox' = bounding-box centre."""
    al = np.asarray(img)[..., 3] > 0
    x0, y0, x1, y1 = bbox(al)
    ay = y1
    if xref == "bbox":
        ax = (x0 + x1) / 2
    elif xref == "head":
        rows = al[y0:y0 + max(1, int((y1 - y0) * 0.3))]
        cx = np.nonzero(rows.any(0))[0]
        ax = (cx.min() + cx.max() + 1) / 2
    else:
        rows = al[y1 - feet_rows:y1]
        cx = np.nonzero(rows.any(0))[0]
        ax = (cx.min() + cx.max() + 1) / 2
    return ax, ay


def align_strip(frames, cell_w, cell_h, anchor_x, anchor_y, xref="feet", y_offsets=None):
    """Place each frame so its anchor lands on (anchor_x, anchor_y) of its cell."""
    strip = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    report = []
    for k, f in enumerate(frames):
        ax, ay = anchor_of(f, xref)
        dy = (y_offsets[k] if y_offsets else 0)
        ox = int(round(anchor_x - ax))
        oy = int(round(anchor_y - ay)) + dy
        cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        cell.alpha_composite(f, (max(ox, 0), max(oy, 0)), (max(-ox, 0), max(-oy, 0)))
        clipped = (ox < 0 or oy < 0 or ox + f.width > cell_w or oy + f.height > cell_h)
        strip.alpha_composite(cell, (k * cell_w, 0))
        report.append({"frame": k, "size": f.size, "offset": (ox, oy), "clipped": clipped})
    return strip, report


def preview(img, path, factor=4, bg=(120, 140, 120)):
    big = img.resize((img.width * factor, img.height * factor), Image.NEAREST)
    base = Image.new("RGBA", big.size, bg + (255,))
    base.alpha_composite(big)
    base.convert("RGB").save(path)
