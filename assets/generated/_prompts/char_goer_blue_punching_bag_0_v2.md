# char_goer_blue_punching_bag frame 0 (v2)

Generated with `codex exec` (default image model), attempt 2. Raw output: `assets/generated/_raw/v2/goer_blue_punching_bag_0.png` (gitignored). Post-processed by `tools/art/build_gym_poses_v2.py` into `assets/characters/generated/v2/char_goer_blue_punching_bag_2f_ai_v2.png`.

Attached reference images (`codex exec -i`):

- LimeZu walk sheet npc_walk_set4_48.png, character index 0 (12 frames, nearest-neighbour x3, white background) - local temp file only, never committed

## Prompt

```
Generate ONE image with your image generation tool, then save it as out.png in the current working directory.

The first attached image is a LimeZu "Modern Interiors" style pixel-art character sprite sheet: one single character, 3 walking frames (columns) x 4 directions (rows: facing down/front, left, right, up/back). Draw THIS SAME CHARACTER in a new pose, in EXACTLY the same pixel-art style.

Character (match the reference exactly): a girl with dark slate-blue hair and two small tied tufts sticking up on top of her head like little antennae, small green eyes, peach skin, a white T-shirt under a sky-blue sleeveless sporty top / dungarees, white legs (white shorts / socks), grey-blue shoes.

Pose: BOXING (hitting a punching bag, but do NOT draw the bag). Side view facing RIGHT, exactly like the third row of the reference, standing with feet slightly apart.
Frame 0 - guard stance: both fists raised in front of the face, elbows bent, ready to punch.
For the view, use the third row (facing right) of the reference as the model for the head and body.

Style rules (very important):
- Very low resolution pixel art: the character is only about 16 pixels wide and 22 pixels tall, exactly like the reference sprite. Show it enlarged with nearest-neighbour scaling so every art pixel is a big, crisp, uniform square block (all blocks the same size, aligned on one grid). No anti-aliasing, no gradients, no fine detail smaller than one block.
- Same proportions as the reference: a huge round head that is about half of the total body height and as wide as the whole body, tiny stubby body, very short arms and legs.
- Thick dark navy-grey outline (one block wide) around the silhouette, flat colours with only 2-3 shades per material, use the same colours as the reference. Gym equipment is dark grey / black with a light grey highlight.
- Same person, same hair, same clothes, same colours as the reference.

Image rules: exactly ONE character in ONE pose, full body visible, centered, nothing cut off. Background: a single flat solid pure magenta colour (#FF00FF), no floor, no shadow, no text, no border, no other objects. Do NOT draw multiple poses, a sprite sheet, or a copy of the reference.
```
