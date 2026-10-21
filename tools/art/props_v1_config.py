"""Config for small AI props in the LimeZu Modern Interiors style (build_props_v1.py).

Cells / anchors are in final (x3) pixels; LOGICAL sizes are /3. The style reference images are crops of
LimeZu interiors sheets (assets/sheets/, gitignored) and only ever live in a local temp dir.
"""

PROPS = {
    "water_bottle": {
        "cell": (24, 36), "anchor": (12, 36),  # bottom-centre of the bottle; lowest opaque px on row 35
        "target_h": 10,                         # logical height incl. outline
        "max_w": 6,                             # logical width incl. outline
        "frames": 1,
        # LimeZu colours: outline + the water-bottle / gym-bottle colours of int16 / int05 (logical px)
        "palette": ["#3a3a50", "#46465e", "#565972", "#738ca8", "#a4bbd5", "#bad2e0", "#cce6ec", "#f8f8f8",
                    "#d8d0e0", "#c6bdd5", "#90c7de", "#50a7e8", "#4995e3", "#4280dd", "#374fa6",
                    "#6daec3", "#3fa7b0", "#2e7f8f"],
        "style_ref": "LimeZu bottles: int16_cafe_kitchen_a_768.png (630,150)-(657,183) and (627,198)-(654,234), "
                     "int05_gym_equipment_768.png (141,147)-(171,186), plus a dumbbell (339,300)-(432,336) for the "
                     "line style; x6 on white",
    },
}

PROMPT_WATER_BOTTLE = """Generate ONE image with your image generation tool, then save it as out.png in the current working directory.

The attached image shows a few small objects from the LimeZu "Modern Interiors" pixel-art tileset (two plastic water bottles, a bottle with a blue band, a dumbbell), enlarged with nearest-neighbour scaling. They are a STYLE reference only: do not copy them.

Draw ONE new object in exactly that pixel-art style: a gym SPORTS WATER BOTTLE (a reusable plastic squeeze bottle for the gym). It stands upright, seen from the front and slightly above like the reference objects. Details:
- body: a straight, slightly rounded cylinder of translucent light sky-blue / cyan plastic, with a lighter vertical highlight stripe on the left side and a slightly darker blue band (grip) around the middle;
- lid: a white / light-grey screw cap on top, a bit narrower than the body, with a small dark sports spout (push-pull nozzle) sticking up in the middle of the cap.

Style rules (very important):
- EXTREMELY low resolution pixel art, as tiny as the reference bottles: the whole bottle is exactly 6 pixels wide and 10 pixels tall INCLUDING its outline. Roughly this layout (O = dark outline, W = white cap, G = light grey cap shade, L = light highlight, B = light blue plastic, D = darker blue band, . = background):
    ..OO..
    .OWWO.
    .OGGO.
    OLBBBO
    OLBBBO
    ODDDDO
    OLBBBO
    OLBBBO
    OBBBBO
    .OOOO.
  Show it enlarged with nearest-neighbour scaling so every art pixel is a big, crisp, uniform square block (all blocks the same size, about 1/16 of the image height, aligned on one grid). No anti-aliasing, no gradients, no detail smaller than one block.
- A dark navy-grey outline (#3a3a50), exactly one block wide, all around the silhouette, like the reference objects. Flat colours, 2-3 shades per material.

Image rules: exactly ONE bottle, centered, nothing cut off. Background: a single flat solid pure magenta colour (#FF00FF), no floor, NO shadow, no text, no border, no other objects. Do NOT draw several bottles or a copy of the reference.
"""
