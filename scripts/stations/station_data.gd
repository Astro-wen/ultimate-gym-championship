class_name StationData
extends Resource
## One file per equipment type. Adding equipment = new .tres + art, no code changes.

@export var id: StringName = &""
@export var display_name: String = ""
## Seconds an NPC spends on one set (the player plays the minigame instead).
@export var use_time: float = 6.0
@export var capacity: int = 1
## Minigame kind: hold_release | alternate | rhythm | timing.
@export var minigame: StringName = &"hold_release"
@export var reps_per_set: int = 5
## Free per-minigame tuning, read by Minigame.create().
@export var minigame_params: Dictionary = {}
@export var stat: StringName = &"strength"
@export var stat_gain: int = 3
@export var buff_kind: StringName = &"stealthy"
@export var buff_duration: float = 8.0
## Noise per rep, attracts the Patroller's gaze.
@export var noise: float = 0.3
## Extra visibility multiplier while using this station.
@export var exposure: float = 1.3
@export var anim_name: StringName = &""
@export var base_texture: Texture2D
## Optional path to (possibly gitignored) art; loaded only if present.
@export var base_texture_path: String = ""
@export var base_region: Rect2 = Rect2()
@export var pose_texture: Texture2D
@export var pose_frames: int = 1
@export var pose_frame_size: Vector2i = Vector2i(48, 48)
## Ground point (feet) inside a pose frame; drawn at the user's position.
@export var pose_anchor: Vector2 = Vector2(24, 48)
## Cyclic animation (frame = floor(t * frames)) instead of a 0..1 pose blend.
@export var pose_loop: bool = false
## Where users stand/lie, relative to the station origin. One per capacity slot.
@export var anchor_offsets: Array[Vector2] = [Vector2.ZERO]
## Where users are placed when they leave.
@export var exit_offset: Vector2 = Vector2(0, 40)
## Footprint of the solid body, in pixels (centered on origin, bottom aligned).
@export var footprint: Vector2 = Vector2(40, 24)
@export var placeholder_color: Color = Color(0.4, 0.4, 0.5)
