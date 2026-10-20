class_name ActorVisual
extends Node2D
## Draws an actor. Uses sprite sheets when available, otherwise a readable
## placeholder figure (so the game always runs without licensed art).

## Optional 3-column x 4-row RPG Maker style walk sheet (down, left, right, up).
var walk_sheet: Texture2D
var walk_cell: Vector2i = Vector2i(48, 48)
## Sheet origin (in cells) of this character inside a multi-character sheet.
var walk_origin: Vector2i = Vector2i.ZERO
var actor: ActorBody
## Draw the station's AI pose sprites (all of them are the player character).
var use_pose_art: bool = false
## NPCs reuse the player's pose art with the white shirt recolored to theirs.
var shirt_swap: bool = false
var _walk_t: float = 0.0
var _swap_on: bool = false

const SWAP_SHADER_CODE: String = """
shader_type canvas_item;
uniform bool enabled = false;
uniform vec4 shirt : source_color = vec4(1.0);
void fragment() {
	vec4 c = COLOR;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	if (enabled && c.a > 0.5 && mx > 0.72 && mx - mn < 0.12) {
		COLOR.rgb = shirt.rgb * (0.55 + 0.45 * mx);
	}
}
"""
static var _swap_shader: Shader


func _ensure_swap_material() -> void:
	if shirt_swap and material == null:
		if _swap_shader == null:
			_swap_shader = Shader.new()
			_swap_shader.code = SWAP_SHADER_CODE
		var m := ShaderMaterial.new()
		m.shader = _swap_shader
		material = m


func _process(delta: float) -> void:
	if actor == null:
		return
	_ensure_swap_material()
	var want: bool = shirt_swap and actor.station != null
	if want != _swap_on and material is ShaderMaterial:
		_swap_on = want
		var m: ShaderMaterial = material
		m.set_shader_parameter(&"enabled", want)
		m.set_shader_parameter(&"shirt", actor.body_color)
	if actor.speed_kind != ActorBody.Speed.STILL:
		_walk_t += delta * (12.0 if actor.speed_kind == ActorBody.Speed.SPRINT else 6.0)
	else:
		_walk_t = 0.0


func _draw() -> void:
	if actor == null:
		return
	draw_set_transform(Vector2.ZERO)
	# shadow
	draw_ellipse_shadow()
	if actor.station != null and is_instance_valid(actor.station):
		_draw_pose(actor.station.data)
	elif walk_sheet != null:
		_draw_walk_sheet()
	else:
		_draw_standing()
	var b: String = actor.bubble()
	if b != "":
		var font: Font = ThemeDB.fallback_font
		var top: Vector2 = Vector2(0, -84 if walk_sheet != null else -58)
		draw_circle(top, 10.0, Color.WHITE)
		draw_arc(top, 10.0, 0.0, TAU, 20, Color(0.1, 0.1, 0.15), 1.5)
		var col: Color = Color(0.9, 0.15, 0.1) if b != "?" else Color(0.9, 0.6, 0.1)
		draw_string(font, top + Vector2(-10, 6), b, HORIZONTAL_ALIGNMENT_CENTER, 20, 16, col)


func draw_ellipse_shadow() -> void:
	var pts := PackedVector2Array()
	for i: int in 16:
		var a: float = TAU * i / 16.0
		pts.append(Vector2(cos(a) * 11.0, sin(a) * 4.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.25))


func _row_for_facing() -> int:
	var f: Vector2 = actor.facing
	if absf(f.x) > absf(f.y):
		return 1 if f.x < 0.0 else 2
	return 3 if f.y < 0.0 else 0


func _draw_walk_sheet() -> void:
	var col: int = 1
	if actor.speed_kind != ActorBody.Speed.STILL:
		col = [0, 1, 2, 1][int(_walk_t) % 4]
	var cell := Vector2(walk_cell)
	var src := Rect2(Vector2((walk_origin.x + col) * walk_cell.x, (walk_origin.y + _row_for_facing()) * walk_cell.y), cell)
	draw_texture_rect_region(walk_sheet, Rect2(Vector2(-cell.x * 0.5, -cell.y + 4.0), cell), src)


func _sheet_frame(col: int, row: int, offset: Vector2 = Vector2.ZERO) -> void:
	var cell := Vector2(walk_cell)
	var src := Rect2(Vector2((walk_origin.x + col) * walk_cell.x, (walk_origin.y + row) * walk_cell.y), cell)
	draw_texture_rect_region(walk_sheet, Rect2(Vector2(-cell.x * 0.5, -cell.y + 4.0) + offset, cell), src)


## NPC poses built from their own walk sheet plus drawn props.
func _draw_pose_sheet(d: StationData, t: float) -> void:
	var iron := Color(0.22, 0.22, 0.28)
	match d.minigame:
		&"hold_release":
			_sheet_frame(1, 0)
			var y: float = lerpf(-62.0, -42.0, t)
			draw_line(Vector2(-26, y), Vector2(26, y), Color(0.75, 0.75, 0.8), 2.0)
			draw_rect(Rect2(-31, y - 7, 6, 14), iron)
			draw_rect(Rect2(25, y - 7, 6, 14), iron)
		&"alternate":
			_sheet_frame(1, 0)
			var y2: float = lerpf(-26.0, -42.0, t)
			draw_rect(Rect2(-20, y2, 8, 5), iron)
			draw_rect(Rect2(12, -26.0 - (-26.0 - y2) * 0.3, 8, 5), iron)
		&"rhythm":
			_sheet_frame([0, 1, 2, 1][int(t * 4.0) % 4], 3, Vector2(0, -absf(sin(t * TAU)) * 2.0))
		&"timing":
			_sheet_frame(1, 2)
			draw_circle(Vector2(lerpf(6.0, 18.0, t), -36), 4.0, Color(0.85, 0.15, 0.15))
		_:
			_draw_walk_sheet()


func _draw_standing() -> void:
	var bob: float = 0.0
	var step: float = 0.0
	if actor.speed_kind != ActorBody.Speed.STILL:
		bob = -absf(sin(_walk_t * PI * 0.5)) * 2.0
		step = sin(_walk_t * PI * 0.5) * 3.0
	# legs
	draw_rect(Rect2(-6, -12 + bob, 5, 12 - step * 0.3), actor.legs_color)
	draw_rect(Rect2(1, -12 + bob, 5, 12 + step * 0.3), actor.legs_color)
	# torso
	draw_rect(Rect2(-8, -26 + bob, 16, 15), actor.body_color)
	draw_rect(Rect2(-8, -26 + bob, 16, 15), Color(0.1, 0.1, 0.15), false, 1.0)
	_draw_head(Vector2(0, -33 + bob))


func _draw_head(c: Vector2) -> void:
	draw_circle(c, 8.0, actor.skin_color)
	var hair_y: float = 3.0 if actor.facing.y < -0.5 else 0.0
	draw_rect(Rect2(c.x - 8, c.y - 9, 16, 6 + hair_y * 2.0), actor.hair_color)
	if actor.facing.y >= -0.5:
		var dx: float = signf(actor.facing.x) * 2.0
		draw_rect(Rect2(c.x - 4 + dx, c.y, 2, 3), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(c.x + 2 + dx, c.y, 2, 3), Color(0.1, 0.1, 0.1))


func _draw_pose(d: StationData) -> void:
	var t: float = clampf(actor.pose_amount, 0.0, 1.0)
	if use_pose_art and d.pose_texture != null and d.pose_frames > 0:
		var n: int = d.pose_frames
		var frame: int = (int(t * n) % n) if d.pose_loop else clampi(int(round(t * float(n - 1))), 0, n - 1)
		var fs := Vector2(d.pose_frame_size)
		draw_texture_rect_region(d.pose_texture, Rect2(-d.pose_anchor, fs), Rect2(Vector2(frame * fs.x, 0), fs))
		return
	if walk_sheet != null:
		_draw_pose_sheet(d, t)
		return
	var outline := Color(0.1, 0.1, 0.15)
	match d.minigame:
		&"hold_release":
			# lying on the bench, seen from above: head at top
			draw_rect(Rect2(-8, -18, 16, 18), actor.body_color)
			draw_rect(Rect2(-7, 0, 14, 14), actor.legs_color)
			_draw_head(Vector2(0, -24))
			var bar_y: float = lerpf(-20.0, -36.0, t)
			draw_line(Vector2(-7, -14), Vector2(-9, bar_y), actor.skin_color, 3.0)
			draw_line(Vector2(7, -14), Vector2(9, bar_y), actor.skin_color, 3.0)
			draw_line(Vector2(-22, bar_y), Vector2(22, bar_y), Color(0.75, 0.75, 0.8), 2.0)
			draw_rect(Rect2(-26, bar_y - 6, 5, 12), outline)
			draw_rect(Rect2(21, bar_y - 6, 5, 12), outline)
		&"alternate":
			_draw_standing()
			var left_up: float = t if int(Time.get_ticks_msec() / 400) % 2 == 0 else 0.0
			var right_up: float = t - left_up
			draw_line(Vector2(-9, -22), Vector2(-11, lerpf(-10.0, -24.0, left_up)), actor.skin_color, 3.0)
			draw_line(Vector2(9, -22), Vector2(11, lerpf(-10.0, -24.0, right_up)), actor.skin_color, 3.0)
			draw_rect(Rect2(-15, lerpf(-12.0, -26.0, left_up), 8, 4), outline)
			draw_rect(Rect2(7, lerpf(-12.0, -26.0, right_up), 8, 4), outline)
		&"rhythm":
			var b: float = -absf(sin(t * TAU)) * 3.0
			var s: float = sin(t * TAU) * 5.0
			draw_line(Vector2(-2, -12 + b), Vector2(-2 + s, 0), actor.legs_color, 5.0)
			draw_line(Vector2(2, -12 + b), Vector2(2 - s, 0), actor.legs_color, 5.0)
			draw_rect(Rect2(-7, -26 + b, 14, 15), actor.body_color)
			draw_line(Vector2(0, -22 + b), Vector2(-s, -14 + b), actor.skin_color, 3.0)
			_draw_head(Vector2(2, -33 + b))
		&"timing":
			_draw_standing()
			var reach: float = lerpf(4.0, 18.0, t)
			draw_line(Vector2(6, -22), Vector2(6 + reach, -22), actor.skin_color, 3.0)
			draw_circle(Vector2(8 + reach, -22), 3.5, Color(0.85, 0.15, 0.15))
		_:
			_draw_standing()
