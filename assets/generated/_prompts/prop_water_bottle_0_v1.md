# prop_water_bottle frame 0 (v1)

Generated with `codex exec` (default image model), attempt 4 (attempts 1-3 used an earlier prompt without the ASCII layout and came out with too many, too small blocks). Raw output: `assets/generated/_raw/props/water_bottle_0.png` (gitignored). Post-processed by `tools/art/build_props_v1.py` into `assets/sprites/props/prop_water_bottle_1f_ai_v1.png`.

Attached reference image (`codex exec -i`), style only - local temp file only, never committed:

- LimeZu bottles: int16_cafe_kitchen_a_768.png (630,150)-(657,183) and (627,198)-(654,234), int05_gym_equipment_768.png (141,147)-(171,186), plus a dumbbell (339,300)-(432,336) for the line style; x6 on white

## Prompt

```
Generate ONE image with your image generation tool, then save it as out.png in the current working directory.

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
```
