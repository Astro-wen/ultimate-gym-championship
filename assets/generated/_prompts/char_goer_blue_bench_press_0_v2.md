# char_goer_blue_bench_press frame 0 (v2)

Generated with `codex exec` (default image model), attempt 4. Raw output: `assets/generated/_raw/v2/goer_blue_bench_press_0.png` (gitignored). Post-processed by `tools/art/build_gym_poses_v2.py` into `assets/characters/generated/v2/char_goer_blue_bench_press_2f_ai_v2.png`.

Attached reference images (`codex exec -i`):

- LimeZu walk sheet npc_walk_set4_48.png, character index 0 (12 frames, nearest-neighbour x3, white background) - local temp file only, never committed
- the chosen raw of frame 1 (`assets/generated/_raw/v2/goer_blue_bench_press_1.png`)

## Prompt

```
Generate ONE image with your image generation tool, then save it as out.png in the current working directory.

The first attached image is a LimeZu "Modern Interiors" style pixel-art character sprite sheet: one single character, 3 walking frames (columns) x 4 directions (rows: facing down/front, left, right, up/back). Draw THIS SAME CHARACTER in a new pose, in EXACTLY the same pixel-art style. The second attached image is frame 1 of this same animation, already finished: keep the character, the block (pixel) size, the proportions and the colours identical to it, and change only the pose as described below.

Character (match the reference exactly): a girl with dark slate-blue hair and two small tied tufts sticking up on top of her head like little antennae, small green eyes, peach skin, a white T-shirt under a sky-blue sleeveless sporty top / dungarees, white legs (white shorts / socks), grey-blue shoes.

Pose: BENCH PRESS, seen from directly above (top-down camera). The character lies flat on his/her back on a weight bench, but do NOT draw the bench: only the character and the barbell. The head is at the TOP of the image and the feet at the BOTTOM, legs straight and together; the face looks up at the viewer (face visible, like the front-facing row of the reference). Both hands grip a long horizontal steel barbell with SMALL round dark-grey weight plates at both ends; the whole barbell is about 30 blocks wide (about twice the body width), each plate is small: only about 3 blocks wide and 7 blocks tall, and there is a visible stretch of thin bar between each hand and its plate.
Frame 0 - TOP of the lift: arms locked straight up towards the camera, so the hands and the barbell are held high above the shoulders / neck, the bar crosses the image just below the chin (the whole face with both eyes stays clearly visible above the bar); the arms are foreshortened and mostly hidden under the hands, NO elbows sticking out.
For the view, use the first row (facing the viewer) of the reference as the model for the head and body.

Style rules (very important):
- Very low resolution pixel art: the character is only about 16 pixels wide and 22 pixels tall, exactly like the reference sprite. Show it enlarged with nearest-neighbour scaling so every art pixel is a big, crisp, uniform square block (all blocks the same size, aligned on one grid). No anti-aliasing, no gradients, no fine detail smaller than one block.
- Same proportions as the reference: a huge round head that is about half of the total body height and as wide as the whole body, tiny stubby body, very short arms and legs.
- Thick dark navy-grey outline (one block wide) around the silhouette, flat colours with only 2-3 shades per material, use the same colours as the reference. Gym equipment is dark grey / black with a light grey highlight.
- Same person, same hair, same clothes, same colours as the reference.

Image rules: exactly ONE character in ONE pose, full body visible, centered, nothing cut off. Background: a single flat solid pure magenta colour (#FF00FF), no floor, no shadow, no text, no border, no other objects. Do NOT draw multiple poses, a sprite sheet, or a copy of the reference.
```
