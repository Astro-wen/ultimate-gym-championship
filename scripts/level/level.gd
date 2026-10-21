class_name Level
extends Node2D
## Base for a single-screen room. Subclasses fill the layout in _init() and
## draw their floor/walls in _draw_room(). Builds walls, furniture, cover,
## stations and the navigation grid. Actors and stations live under `world`
## (Y-sorted).

const ROOM := Vector2(960, 540)
const WALL_TOP: float = 96.0
const WALL: float = 24.0

## &"gym" | &"office" — picks HUD texts, NPC kinds and win rules.
var level_id: StringName = &""
var title: String = ""
## Short goal shown on the intro card.
var tagline: String = ""
var intro_tips: Array[String] = []
## Points needed to win (sum of finished stations' stat_gain).
var goal_points: int = 36
## Seconds for a run on this level.
var time_limit: float = 180.0
## Awareness rise rate for every watcher on this level (Patroller.base_rise).
var watch_rise: float = 0.5
## How visible standing still is, relative to walking (Patroller.speed_factor_still).
var still_factor: float = 0.3

var station_files: Array[String] = []
var station_positions: Array[Vector2] = []
## Solid furniture that also blocks sight.
var blockers: Array[Rect2] = []
## Optional art per blocker (same index): {"path": String, "region": Rect2,
## "see_through": bool (low furniture: blocks movement, not sight)}.
var blocker_art: Array[Dictionary] = []
var blocker_colors: Array[Color] = []
## Solid but see-through (glass walls).
var glass: Array[Rect2] = []
## Hiding spots that make the alert fall faster.
var covers: Array[Rect2] = []
var player_spawn: Vector2 = Vector2(120, 480)
## GymGoer spawn points (gym only).
var npc_spawns: Array[Vector2] = []
## Patroller route; it pauses and sweeps at each point.
var patrol_points: Array[Vector2] = []
## Stationary watchers: {"pos", "skin": [set, idx], "schedule": Array[Vector3]
## (look angle deg, seconds, view range px), "angle": cone degrees,
## "hide_body": bool, "name"}.
var sitters: Array[Dictionary] = []

## Navigation grid cell size and the clearance kept around solids.
var nav_cell: int = 12
var nav_clearance: float = 10.0

var world: Node2D
var stations: Array[Station] = []
var nav: AStarGrid2D


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	# actors above the floor; view cones (z -1 inside world) sit between
	world.z_index = 1
	add_child(world)
	_build_walls()
	for i: int in blockers.size():
		var art: Dictionary = blocker_art[i] if i < blocker_art.size() else {}
		# low furniture (desks) blocks movement but not sight
		var body: StaticBody2D = _add_solid(blockers[i], not bool(art.get("see_through", false)), world)
		var prop := PropBox.new()
		prop.size = blockers[i].size
		prop.color = blocker_colors[i] if i < blocker_colors.size() else Color(0.7, 0.7, 0.72)
		if art.has("path"):
			prop.texture = LocalArt.tex(String(art["path"]))
			prop.region = art.get("region", Rect2())
		body.add_child(prop)
	for r: Rect2 in glass:
		_add_solid(r, false, world)
	for r: Rect2 in covers:
		_add_cover(r)
	_build_stations()
	_build_nav()
	queue_redraw()


# --- navigation ----------------------------------------------------------

func solid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [
		Rect2(0, 0, ROOM.x, WALL_TOP),
		Rect2(0, ROOM.y - WALL, ROOM.x, WALL),
		Rect2(0, 0, WALL, ROOM.y),
		Rect2(ROOM.x - WALL, 0, WALL, ROOM.y),
	]
	out.append_array(blockers)
	out.append_array(glass)
	for st: Station in stations:
		var fp: Vector2 = st.data.footprint
		out.append(Rect2(st.position + Vector2(-fp.x * 0.5, -fp.y), fp))
	return out


func _build_nav() -> void:
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, int(ROOM.x) / nav_cell, int(ROOM.y) / nav_cell)
	nav.cell_size = Vector2(nav_cell, nav_cell)
	nav.offset = Vector2(nav_cell, nav_cell) * 0.5
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	var solids: Array[Rect2] = solid_rects()
	for y: int in nav.region.size.y:
		for x: int in nav.region.size.x:
			var c: Vector2 = nav.get_point_position(Vector2i(x, y))
			for r: Rect2 in solids:
				if r.grow(nav_clearance).has_point(c):
					nav.set_point_solid(Vector2i(x, y), true)
					break


func _cell_of(p: Vector2) -> Vector2i:
	var c := Vector2i(int(p.x) / nav_cell, int(p.y) / nav_cell)
	return c.clamp(nav.region.position, nav.region.end - Vector2i.ONE)


func is_walkable(p: Vector2) -> bool:
	return not nav.is_point_solid(_cell_of(p))


## Closest walkable point to `p` (searches outward in rings).
func nearest_walkable(p: Vector2) -> Vector2:
	var c0: Vector2i = _cell_of(p)
	if not nav.is_point_solid(c0):
		return p
	for r: int in range(1, 20):
		var best: Vector2i = Vector2i(-1, -1)
		var best_d: float = INF
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c: Vector2i = c0 + Vector2i(dx, dy)
				if nav.is_in_boundsv(c) and not nav.is_point_solid(c):
					var d: float = nav.get_point_position(c).distance_squared_to(p)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return nav.get_point_position(best)
	return p


## Walkable path from `from` to `to` (world points). Empty if unreachable.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a: Vector2i = _cell_of(nearest_walkable(from))
	var b: Vector2i = _cell_of(nearest_walkable(to))
	var path: PackedVector2Array = nav.get_point_path(a, b)
	if path.size() > 0:
		path[path.size() - 1] = nearest_walkable(to)
	return path


# --- building --------------------------------------------------------------

func _build_walls() -> void:
	var walls := Node2D.new()
	walls.name = "Walls"
	add_child(walls)
	_add_solid(Rect2(0, 0, ROOM.x, WALL_TOP), true, walls)
	_add_solid(Rect2(0, ROOM.y - WALL, ROOM.x, WALL), true, walls)
	_add_solid(Rect2(0, 0, WALL, ROOM.y), true, walls)
	_add_solid(Rect2(ROOM.x - WALL, 0, WALL, ROOM.y), true, walls)


func _add_solid(r: Rect2, blocks_sight: bool, parent: Node) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD | (Layers.VISION_BLOCKER if blocks_sight else 0)
	body.collision_mask = 0
	# origin at the bottom edge so it Y-sorts against actors correctly
	body.position = Vector2(r.position.x + r.size.x * 0.5, r.end.y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = Vector2(0, -r.size.y * 0.5)
	body.add_child(shape)
	parent.add_child(body)
	return body


func _add_cover(r: Rect2) -> void:
	var area := Area2D.new()
	area.collision_layer = Layers.COVER
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group(&"cover")
	area.position = r.get_center()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	area.add_child(shape)
	add_child(area)


func _build_stations() -> void:
	for i: int in mini(station_files.size(), station_positions.size()):
		var d: StationData = load(station_files[i]) as StationData
		if d == null:
			push_error("Station data missing: %s" % station_files[i])
			continue
		var st := Station.new()
		st.name = "%s_%d" % [d.id, i]
		st.data = d
		st.position = station_positions[i]
		world.add_child(st)
		stations.append(st)


## True if `p` is inside a cover rect.
func is_in_cover(p: Vector2) -> bool:
	for r: Rect2 in covers:
		if r.has_point(p):
			return true
	return false


func station_by_id(id: StringName) -> Station:
	for st: Station in stations:
		if st.data.id == id:
			return st
	return null


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	_draw_room()
	for r: Rect2 in covers:
		draw_rect(r, Color(0.4, 0.8, 0.5, 0.10))


## Floor, walls and wall decorations. Overridden per level.
func _draw_room() -> void:
	draw_rect(Rect2(Vector2.ZERO, ROOM), Color(0.3, 0.3, 0.35))


## Shared helper: checker floor between the top wall and the bottom.
func _draw_floor(a: Color, b: Color) -> void:
	var t: int = Layers.TILE
	for y: int in range(int(WALL_TOP), int(ROOM.y), t):
		for x: int in range(0, int(ROOM.x), t):
			draw_rect(Rect2(x, y, t, t), a if ((x + y) / t) % 2 == 0 else b)


## Shared helper: back wall band and the three dark border walls.
func _draw_walls(wall: Color, trim: Color) -> void:
	draw_rect(Rect2(0, 0, ROOM.x, WALL_TOP), wall)
	draw_rect(Rect2(0, WALL_TOP - 12, ROOM.x, 12), trim)
	draw_rect(Rect2(0, 0, ROOM.x, 8), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(0, ROOM.y - WALL, ROOM.x, WALL), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(0, 0, WALL, ROOM.y), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(ROOM.x - WALL, 0, WALL, ROOM.y), Color(0.25, 0.25, 0.3))
