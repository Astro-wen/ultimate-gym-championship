"""Shared config for the v2 gym poses (LimeZu-matched characters).

Used by build_gym_poses_v2.py (post-processing) and for writing the codex prompts.
The LimeZu walk sheets themselves are NOT in the repo (assets/sheets/ is gitignored);
they are only read locally to measure height / colours and to make reference images.
"""

# npc_walk_set{N}_48.png: 576x768, 48x96 cells, 8 characters per sheet.
# character i: origin column (i%4)*3, row (i//4)*4; 3 frames x 4 directions (down, left, right, up);
# column 1 (middle) is the standing frame.
CHARS = {
    "player": {
        "set": 1, "index": 6,
        "desc": "a young man with short, slightly spiky medium-brown hair (darker brown shading, a few dark strands on the "
                "forehead), peach skin, tiny dark eyes, a long-sleeved light grey shirt with dark grey-blue horizontal "
                "stripes, blue jeans, dark brown shoes",
    },
    "goer_red": {
        "set": 1, "index": 0,
        "desc": "a boy with a round, full bowl-cut of auburn / reddish-brown hair covering the forehead, small blue eyes, "
                "peach skin, a bright red short-sleeved T-shirt, tan / light-brown trousers, dark brown shoes",
    },
    "goer_green": {
        "set": 1, "index": 2,
        "desc": "a man with smooth, short dark slate grey-blue hair shaped like a helmet (a thin light greyish-brown line "
                "at the hairline), small green eyes, peach skin, a green T-shirt with a lighter green horizontal band "
                "across the chest, grey-blue trousers, orange-brown shoes",
    },
    "goer_blue": {
        "set": 4, "index": 0,
        "desc": "a girl with dark slate-blue hair and two small tied tufts sticking up on top of her head like little "
                "antennae, small green eyes, peach skin, a white T-shirt under a sky-blue sleeveless sporty top / "
                "dungarees, white legs (white shorts / socks), grey-blue shoes",
    },
    # crowd / cup regulars (round 2)
    "goer_blonde": {
        "set": 1, "index": 3,
        "desc": "a young woman with long, thick honey-blonde / golden caramel-orange hair: a side-swept fringe covering "
                "the forehead down to the eyebrows, the hair falls straight down to the shoulders on both sides of the "
                "face and covers the whole back of the head down to the shoulders; small blue eyes, pink blush on the "
                "cheeks, peach skin, a short-sleeved light beige / sand-coloured top, dark slate grey-blue trousers, "
                "orange-brown shoes",
        # her bench press kept coming out with ~37 rows of tiny blocks (eyes lost when resampled to 23 rows)
        "notes": {"bench_press": "Keep the blocks BIG: from the top of the hair to the shoes the character is only "
                                 "about 23 blocks tall (each block about 1/30 of the image height), the barbell bar "
                                 "is exactly one block thick, and each eye is one whole blue block."},
    },
    "goer_sky": {
        "set": 1, "index": 7,
        "desc": "a young man with short, rounded light-brown hair (lighter caramel on top, darker brown at the sides, "
                "a straight fringe over the forehead), small blue eyes, peach skin, a long-sleeved sky-blue sweater "
                "with dark navy-blue horizontal stripes, mustard-yellow / olive trousers, dark brown shoes",
    },
    "goer_brown": {
        "set": 3, "index": 2,
        "desc": "a man with dark brown skin and very short, close-cropped dark charcoal-grey hair (a rounded crew cut), "
                "small dark eyes, a dark red / maroon short-sleeved open shirt or jacket with a white undershirt "
                "showing as a narrow white stripe down the middle of the chest, dark slate grey trousers, dark red "
                "shoes",
    },
}

# reference-sheet row used for each view
VIEW_ROW = {"front": "the first row (facing down / towards the viewer)",
            "back": "the last row (facing up / away from the viewer, we see the back of the head)",
            "right": "the third row (facing right)",
            "top": "the first row (facing the viewer)"}

# action -> spec. cell/anchor in final (x3) pixels. walk_dir = which walk-sheet row gives the height reference.
ACTIONS = {
    "bench_press": {
        "cell": (96, 72), "anchor": (48, 72), "frames": 2, "view": "top", "walk_dir": 0, "fit_width": True, "extra_h": 1,
        "pose": "BENCH PRESS, seen from directly above (top-down camera). The character lies flat on his/her back on a "
                "weight bench, but do NOT draw the bench: only the character and the barbell. The head is at the TOP of "
                "the image and the feet at the BOTTOM, legs straight and together; the face looks up at the viewer "
                "(face visible, like the front-facing row of the reference). Both hands grip a long horizontal steel "
                "barbell with SMALL round dark-grey weight plates at both ends; the whole barbell is about 30 blocks "
                "wide (about twice the body width), each plate is small: only about 3 blocks wide and 7 blocks tall, "
                "and there is a visible stretch of thin bar between each hand and its plate.",
        "frame": [
            "Frame 0 - TOP of the lift: arms locked straight up towards the camera, so the hands and the barbell are "
            "held high above the shoulders / neck, the bar crosses the image just below the chin (the whole face with "
            "both eyes stays clearly visible above the bar); the arms are "
            "foreshortened and mostly hidden under the hands, NO elbows sticking out.",
            "Frame 1 - BOTTOM of the lift: elbows bent and pointing out to the left and right sides, the barbell is "
            "lowered onto the middle of the chest (lower than in frame 0); the bent upper arms are visible sticking "
            "out sideways from the shoulders.",
        ],
    },
    "dumbbell_curl": {
        "cell": (48, 96), "anchor": (24, 96), "frames": 2, "view": "front", "walk_dir": 0,
        "pose": "DUMBBELL CURL. Front view (facing the viewer, exactly like the first row of the reference), standing "
                "straight, feet together. One small dark-grey dumbbell in each hand.",
        "frame": [
            "Frame 0 - arms down: both arms hang straight down at the sides, each hand holding its dumbbell next to the "
            "hip.",
            "Frame 1 - curled up: both elbows bent, forearms raised so each dumbbell is lifted up right next to the "
            "shoulder (the dumbbells are at shoulder height, beside the chin).",
        ],
    },
    "treadmill": {
        "cell": (72, 96), "anchor": (36, 96), "frames": 4, "view": "back", "walk_dir": 3,
        "pose": "RUNNING IN PLACE on a treadmill, seen from BEHIND (back view, exactly like the last row of the "
                "reference: we see the back of the head, running away from the viewer towards the top of the screen). "
                "Do NOT draw the treadmill.",
        "frame": [
            "Frame 0 of a 4-frame run cycle: LEFT knee lifted high (left foot off the ground, raised), right leg "
            "planted, right arm swung forward/up and left arm back.",
            "Frame 1 of a 4-frame run cycle: passing position, both feet close together under the body, left foot "
            "just touching the ground, arms close to the body.",
            "Frame 2 of a 4-frame run cycle: RIGHT knee lifted high (right foot off the ground, raised), left leg "
            "planted, left arm swung forward/up and right arm back (mirror of frame 0).",
            "Frame 3 of a 4-frame run cycle: passing position, both feet close together under the body, right foot "
            "just touching the ground, arms close to the body.",
        ],
    },
    "punching_bag": {
        "cell": (72, 96), "anchor": (30, 96), "frames": 2, "view": "right", "walk_dir": 2,
        "pose": "BOXING (hitting a punching bag, but do NOT draw the bag). Side view facing RIGHT, exactly like the "
                "third row of the reference, standing with feet slightly apart.",
        "frame": [
            "Frame 0 - guard stance: both fists raised in front of the face, elbows bent, ready to punch.",
            "Frame 1 - straight punch: the front arm is fully extended straight out horizontally to the RIGHT at "
            "shoulder height, fist far in front of the face (the arm is long and clearly visible); the other fist "
            "stays up at the chin.",
        ],
    },
}

PROMPT = """Generate ONE image with your image generation tool, then save it as out.png in the current working directory.

The first attached image is a LimeZu "Modern Interiors" style pixel-art character sprite sheet: one single character, 3 walking frames (columns) x 4 directions (rows: facing down/front, left, right, up/back). Draw THIS SAME CHARACTER in a new pose, in EXACTLY the same pixel-art style.{extra_ref}

Character (match the reference exactly): {desc}.

Pose: {pose}
{frame}
For the view, use {view_row} of the reference as the model for the head and body.

Style rules (very important):
- Very low resolution pixel art: the character is only about 16 pixels wide and 22 pixels tall, exactly like the reference sprite. Show it enlarged with nearest-neighbour scaling so every art pixel is a big, crisp, uniform square block (all blocks the same size, aligned on one grid). No anti-aliasing, no gradients, no fine detail smaller than one block.
- Same proportions as the reference: a huge round head that is about half of the total body height and as wide as the whole body, tiny stubby body, very short arms and legs.
- Thick dark navy-grey outline (one block wide) around the silhouette, flat colours with only 2-3 shades per material, use the same colours as the reference. Gym equipment is dark grey / black with a light grey highlight.
- Same person, same hair, same clothes, same colours as the reference.{note}

Image rules: exactly ONE character in ONE pose, full body visible, centered, nothing cut off. Background: a single flat solid pure magenta colour (#FF00FF), no floor, no shadow, no text, no border, no other objects. Do NOT draw multiple poses, a sprite sheet, or a copy of the reference.
"""

EXTRA_REF = (" The second attached image is frame {ref} of this same animation, already finished: keep the character, "
             "the block (pixel) size, the proportions and the colours identical to it, and change only the pose as "
             "described below.")


def prompt_for(char_id, action, frame, ref_frame=None):
    """ref_frame: index of an already finished frame attached as 2nd image (default: frame 0 for frames > 0)."""
    if ref_frame is None and frame > 0:
        ref_frame = 0
    c, a = CHARS[char_id], ACTIONS[action]
    return PROMPT.format(extra_ref=EXTRA_REF.format(ref=ref_frame) if ref_frame is not None else "", desc=c["desc"], pose=a["pose"],
                         frame=a["frame"][frame], view_row=VIEW_ROW[a["view"]],
                         note=("\n- " + c["notes"][action]) if action in c.get("notes", {}) else "")


if __name__ == "__main__":
    # write all prompts:  python gym_poses_v2_config.py OUT_DIR
    import pathlib
    import sys
    out = pathlib.Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    for cid in CHARS:
        for act, spec in ACTIONS.items():
            for f in range(spec["frames"]):
                (out / f"{cid}_{act}_{f}.txt").write_text(prompt_for(cid, act, f), encoding="utf-8")
                if f == 0 and spec["frames"] > 1:  # frame 0 redone against a finished frame 1
                    (out / f"{cid}_{act}_0_ref1.txt").write_text(prompt_for(cid, act, 0, 1), encoding="utf-8")
    print("wrote", len(list(out.glob("*.txt"))), "prompts to", out)
