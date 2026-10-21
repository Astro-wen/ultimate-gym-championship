# char_goer_blonde_treadmill frame 3 (v2)

Generated with `codex exec` (default image model), attempt 1. Raw output: `assets/generated/_raw/v2/goer_blonde_treadmill_3.png` (gitignored). Post-processed by `tools/art/build_gym_poses_v2.py` into `assets/characters/generated/v2/char_goer_blonde_treadmill_4f_ai_v2.png`.

Attached reference images (`codex exec -i`):

- LimeZu walk sheet npc_walk_set1_48.png, character index 3 (12 frames, nearest-neighbour x3, white background) - local temp file only, never committed
- the chosen raw of frame 0 (`assets/generated/_raw/v2/goer_blonde_treadmill_0.png`)

## Prompt

```
Generate ONE image with your image generation tool, then save it as out.png in the current working directory.

The first attached image is a LimeZu "Modern Interiors" style pixel-art character sprite sheet: one single character, 3 walking frames (columns) x 4 directions (rows: facing down/front, left, right, up/back). Draw THIS SAME CHARACTER in a new pose, in EXACTLY the same pixel-art style. The second attached image is frame 0 of this same animation, already finished: keep the character, the block (pixel) size, the proportions and the colours identical to it, and change only the pose as described below.

Character (match the reference exactly): a young woman with long, thick honey-blonde / golden caramel-orange hair: a side-swept fringe covering the forehead down to the eyebrows, the hair falls straight down to the shoulders on both sides of the face and covers the whole back of the head down to the shoulders; small blue eyes, pink blush on the cheeks, peach skin, a short-sleeved light beige / sand-coloured top, dark slate grey-blue trousers, orange-brown shoes.

Pose: RUNNING IN PLACE on a treadmill, seen from BEHIND (back view, exactly like the last row of the reference: we see the back of the head, running away from the viewer towards the top of the screen). Do NOT draw the treadmill.
Frame 3 of a 4-frame run cycle: passing position, both feet close together under the body, right foot just touching the ground, arms close to the body.
For the view, use the last row (facing up / away from the viewer, we see the back of the head) of the reference as the model for the head and body.

Style rules (very important):
- Very low resolution pixel art: the character is only about 16 pixels wide and 22 pixels tall, exactly like the reference sprite. Show it enlarged with nearest-neighbour scaling so every art pixel is a big, crisp, uniform square block (all blocks the same size, aligned on one grid). No anti-aliasing, no gradients, no fine detail smaller than one block.
- Same proportions as the reference: a huge round head that is about half of the total body height and as wide as the whole body, tiny stubby body, very short arms and legs.
- Thick dark navy-grey outline (one block wide) around the silhouette, flat colours with only 2-3 shades per material, use the same colours as the reference. Gym equipment is dark grey / black with a light grey highlight.
- Same person, same hair, same clothes, same colours as the reference.

Image rules: exactly ONE character in ONE pose, full body visible, centered, nothing cut off. Background: a single flat solid pure magenta colour (#FF00FF), no floor, no shadow, no text, no border, no other objects. Do NOT draw multiple poses, a sprite sheet, or a copy of the reference.
```
