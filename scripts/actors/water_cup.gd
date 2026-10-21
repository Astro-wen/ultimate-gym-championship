class_name WaterCup
extends Node2D
## The player's water bottle. Carried in hand, or set down on the floor.
## Set down next to a machine, it reserves that machine for its owner
## (gym etiquette): NPCs won't claim it and leave its line.

const TEX_PATH: String = "res://assets/sprites/props/prop_water_bottle_1f_ai_v1.png"
## How close (px, to the footprint) a dropped cup must be to reserve a machine.
const RESERVE_REACH: float = 34.0

var owner_actor: Player
var carried: bool = true
var reserved: Station = null
var _tex: Texture2D
var _bob: float = 0.0


func _ready() -> void:
	_tex = LocalArt.tex(TEX_PATH)


func _process(delta: float) -> void:
	if carried and owner_actor != null and is_instance_valid(owner_actor):
		var side: float = -1.0 if owner_actor.facing.x < -0.1 else 1.0
		# a hair in front of the owner so Y-sort draws it over the body
		global_position = owner_actor.global_position + Vector2(10.0 * side, 1.0)
		visible = owner_actor.station == null
		_bob = owner_actor.visual.position.y if owner_actor.visual != null else 0.0
	queue_redraw()


## Station a cup dropped at `p` would reserve, or null.
static func station_near(p: Vector2, tree: SceneTree) -> Station:
	var best: Station = null
	var best_d: float = RESERVE_REACH
	for n: Node in tree.get_nodes_in_group(&"stations"):
		var st: Station = n as Station
		if st == null:
			continue
		var d: float = st.distance_to_point(p)
		if d <= best_d:
			best = st
			best_d = d
	return best


func drop(at: Vector2) -> Station:
	carried = false
	visible = true
	global_position = at
	reserved = station_near(at, get_tree())
	if reserved != null:
		reserved.reserve(owner_actor)
	return reserved


func pick_up() -> void:
	carried = true
	if reserved != null and is_instance_valid(reserved) and reserved.reserved_by == owner_actor:
		reserved.unreserve()
	reserved = null


func _exit_tree() -> void:
	if reserved != null and is_instance_valid(reserved) and reserved.reserved_by == owner_actor:
		reserved.unreserve()


func _draw() -> void:
	# carried: in the hand, about waist height; on the floor: standing on it
	var lift: float = 12.0 if carried else 0.0
	var base := Vector2(0, -lift + (_bob if carried else 0.0))
	if not carried:
		var pts := PackedVector2Array()
		for i: int in 12:
			var a: float = TAU * i / 12.0
			pts.append(Vector2(cos(a) * 7.0, sin(a) * 2.5))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.25))
	if _tex != null:
		var s: Vector2 = _tex.get_size()
		var scale_f: float = 0.75 if carried else 1.0
		draw_texture_rect(_tex, Rect2(base + Vector2(-s.x * 0.5, -s.y) * scale_f, s * scale_f), false)
	else:
		_draw_pixel_bottle(base, 2.0 if carried else 3.0)
	if not carried and reserved != null:
		# little "reserved" tick so the effect is readable
		var c: Vector2 = base + Vector2(0, -38)
		draw_circle(c, 6.0, Color(0.25, 0.75, 0.95))
		draw_polyline(PackedVector2Array([c + Vector2(-3, 0), c + Vector2(-1, 2), c + Vector2(3, -2)]), Color.WHITE, 1.5)


## Fallback bottle drawn on the same 3px grid as the LimeZu art.
func _draw_pixel_bottle(base: Vector2, px: float) -> void:
	var ink := Color(0.227, 0.227, 0.314)
	var body := Color(0.35, 0.72, 0.9)
	var shade := Color(0.24, 0.52, 0.72)
	var cap := Color(0.95, 0.95, 0.97)
	# 6 x 10 logical pixels, bottom-centered on `base`
	var o: Vector2 = base + Vector2(-3.0 * px, -10.0 * px)
	var rows: Array[String] = [
		"..oo..",
		".occo.",
		".occo.",
		"obbbbo",
		"obwbso",
		"obwbso",
		"obbbso",
		"obbbso",
		"obbbso",
		".oooo.",
	]
	for y: int in rows.size():
		for x: int in 6:
			var ch: String = rows[y][x]
			var col: Color
			match ch:
				"o":
					col = ink
				"c":
					col = cap
				"b":
					col = body
				"s":
					col = shade
				"w":
					col = Color(0.85, 0.95, 1.0)
				_:
					continue
			draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(px, px)), col)
