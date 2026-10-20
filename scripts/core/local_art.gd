class_name LocalArt
## Licensed LimeZu art lives only on the dev machine (gitignored). Everything
## that uses it must fall back to placeholders when the file is missing, so a
## clean clone still runs.

const GYM_SHEET: String = "res://assets/sheets/interiors/int05_gym_equipment_768.png"
const WALK_SHEETS: Array[String] = [
	"res://assets/sheets/characters/npc_walk_set1_48.png",
	"res://assets/sheets/characters/npc_walk_set2_48.png",
	"res://assets/sheets/characters/npc_walk_set3_48.png",
	"res://assets/sheets/characters/npc_walk_set4_48.png",
]
## RPG Maker MV layout: 4 characters per row group, 3 frames x 4 directions.
const CHAR_CELL := Vector2i(48, 96)


static func tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Character `index` (0..7) of walk sheet `set_i` (0..3), or null.
static func apply_skin(v: ActorVisual, set_i: int, index: int) -> bool:
	if set_i < 0 or set_i >= WALK_SHEETS.size():
		return false
	var t: Texture2D = tex(WALK_SHEETS[set_i])
	if t == null:
		return false
	v.walk_sheet = t
	v.walk_cell = CHAR_CELL
	v.walk_origin = Vector2i((index % 4) * 3, (index / 4) * 4)
	return true


## Per-character exercise pose strip (committed art, derived from LimeZu refs).
static func pose_path(char_id: StringName, d: StationData) -> String:
	return "res://assets/characters/generated/v2/char_%s_%s_%df_ai_v2.png" % [char_id, d.id, d.pose_frames]
