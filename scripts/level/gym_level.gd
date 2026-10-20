class_name GymLevel
extends Node2D
## The demo's single room. Built in code from the exported layout so the
## scene file stays trivial. All actors and stations live under `world`
## (Y-sorted).

const ROOM := Vector2(960, 540)
const WALL_TOP: float = 96.0
const WALL: float = 24.0

@export var station_files: Array[String] = [
	"res://data/stations/bench_press.tres",
	"res://data/stations/dumbbell_curl.tres",
	"res://data/stations/treadmill.tres",
	"res://data/stations/treadmill.tres",
	"res://data/stations/punching_bag.tres",
]
@export var station_positions: Array[Vector2] = [
	Vector2(170, 200),
	Vector2(420, 170),
	Vector2(650, 190),
	Vector2(740, 190),
	Vector2(870, 360),
]
## Solid furniture that also blocks sight: Rect2 in room pixels.
@export var blockers: Array[Rect2] = [
	Rect2(24, 250, 44, 150),    # lockers
	Rect2(300, 330, 40, 40),    # pillar
	Rect2(560, 330, 40, 40),    # pillar
	Rect2(880, 120, 56, 40),    # water cooler + shelf
]
## Hiding spots that make the alert fall faster.
@export var covers: Array[Rect2] = [
	Rect2(68, 250, 40, 150),
	Rect2(290, 370, 60, 40),
	Rect2(550, 370, 60, 40),
]
@export var player_spawn: Vector2 = Vector2(120, 480)
@export var npc_spawns: Array[Vector2] = [Vector2(480, 470), Vector2(620, 470), Vector2(760, 470)]
## Patroller route; it pauses and sweeps at each point.
@export var patrol_points: Array[Vector2] = [
	Vector2(480, 120), Vector2(200, 300), Vector2(480, 450), Vector2(800, 300),
]

var world: Node2D
var stations: Array[Station] = []


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	_build_walls()
	for i: int in blockers.size():
		var body: StaticBody2D = _add_solid(blockers[i], true, world)
		var prop := PropBox.new()
		prop.size = blockers[i].size
		prop.color = Color(0.45, 0.55, 0.65) if i == 0 else Color(0.7, 0.7, 0.72)
		body.add_child(prop)
	for r: Rect2 in covers:
		_add_cover(r)
	_build_stations()
	queue_redraw()


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


func _draw() -> void:
	# floor: rubber gym tiles
	var a := Color(0.32, 0.33, 0.38)
	var b := Color(0.29, 0.30, 0.35)
	var t: int = Layers.TILE
	for y: int in range(int(WALL_TOP), int(ROOM.y), t):
		for x: int in range(0, int(ROOM.x), t):
			draw_rect(Rect2(x, y, t, t), a if ((x + y) / t) % 2 == 0 else b)
	# training mat
	draw_rect(Rect2(760, 300, 160, 120), Color(0.55, 0.22, 0.24))
	# walls
	draw_rect(Rect2(0, 0, ROOM.x, WALL_TOP), Color(0.82, 0.80, 0.74))
	draw_rect(Rect2(0, WALL_TOP - 12, ROOM.x, 12), Color(0.55, 0.52, 0.48))
	draw_rect(Rect2(0, 0, ROOM.x, 8), Color(0.25, 0.25, 0.3))
	# mirror strip and glass door on the back wall
	draw_rect(Rect2(140, 22, 300, 52), Color(0.70, 0.85, 0.92))
	draw_rect(Rect2(140, 22, 300, 52), Color(0.4, 0.5, 0.6), false, 2.0)
	draw_rect(Rect2(450, 30, 60, 66), Color(0.55, 0.75, 0.85, 0.8))
	draw_rect(Rect2(450, 30, 60, 66), Color(0.3, 0.35, 0.45), false, 2.0)
	draw_rect(Rect2(0, ROOM.y - WALL, ROOM.x, WALL), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(0, 0, WALL, ROOM.y), Color(0.25, 0.25, 0.3))
	draw_rect(Rect2(ROOM.x - WALL, 0, WALL, ROOM.y), Color(0.25, 0.25, 0.3))
	# entrance door (bottom-left)
	draw_rect(Rect2(84, ROOM.y - WALL, 72, WALL), Color(0.6, 0.45, 0.3))
	# cover hints
	for r: Rect2 in covers:
		draw_rect(r, Color(0.4, 0.8, 0.5, 0.10))
