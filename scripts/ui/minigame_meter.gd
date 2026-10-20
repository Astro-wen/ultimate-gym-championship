class_name MinigameMeter
extends Node2D
## Compact minigame gauge drawn above the player's head, so the eyes can stay
## on the character instead of the bottom panel.

var player: Player


func _ready() -> void:
	z_index = 10
	z_as_relative = false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.minigame == null or player.station == null:
		return
	var g: Minigame = player.minigame
	var d: StationData = player.station.data
	var top: float = -d.pose_anchor.y - 10.0 if d.pose_texture != null else -70.0
	var w: float = 46.0
	var bar := Rect2(-w * 0.5, top - 8.0, w, 7.0)
	var ink := Color(0.1, 0.1, 0.15)
	if d.minigame == &"alternate":
		var a: AlternateGame = g as AlternateGame
		var left_on: bool = a.expected == &"move_left"
		_key(Vector2(-12, top - 5), "◀", left_on)
		_key(Vector2(12, top - 5), "▶", not left_on)
	else:
		draw_rect(bar.grow(1.0), ink)
		draw_rect(bar, Color(0.22, 0.22, 0.28))
		var z: Vector2 = g.zone()
		var v: float = clampf(g.meter(), 0.0, 1.0)
		var in_zone: bool = v >= z.x and v <= z.y
		var zr := Rect2(bar.position.x + w * z.x, bar.position.y, w * (z.y - z.x), bar.size.y)
		draw_rect(zr, Color(0.25, 0.55, 0.32))
		draw_rect(Rect2(bar.position, Vector2(w * v, bar.size.y)), Color(0.55, 1.0, 0.55, 0.9) if in_zone else Color(0.95, 0.7, 0.3, 0.9))
		# zone outline on top so it stays visible under the fill
		draw_rect(zr.grow(1.0), Color(0.4, 1.0, 0.5), false, 1.0)
		draw_rect(Rect2(bar.position.x + w * v - 1.0, bar.position.y - 2.0, 2.0, bar.size.y + 4.0), Color.WHITE)
	# rep pips
	var n: int = g.target_reps
	var gap: float = 6.0
	var x0: float = -(n - 1) * gap * 0.5
	for i: int in n:
		var c := Vector2(x0 + i * gap, top + 4.0)
		draw_circle(c, 2.5, ink)
		draw_circle(c, 1.6, Color(0.4, 0.95, 0.5) if i < g.reps else Color(0.35, 0.35, 0.4))


func _key(c: Vector2, label: String, lit: bool) -> void:
	var r := Rect2(c - Vector2(8, 8), Vector2(16, 16))
	draw_rect(r, Color(0.98, 0.95, 0.8) if lit else Color(0.35, 0.35, 0.4))
	draw_rect(r, Color(0.1, 0.1, 0.15), false, 1.5)
	draw_string(ThemeDB.fallback_font, c + Vector2(-8, 5), label, HORIZONTAL_ALIGNMENT_CENTER, 16, 11, Color(0.1, 0.1, 0.15))
