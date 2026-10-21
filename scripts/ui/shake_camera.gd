class_name ShakeCamera
extends Camera2D
## Follows the player during a run (slight zoom, look-ahead in the walking
## direction, clamped to the room) and shows the whole room otherwise.
## Trauma-based shake for impacts.

@export var max_offset: float = 6.0
@export var decay: float = 2.5
## Zoom while playing (1 = whole room).
@export var play_zoom: float = 1.3
## How far ahead of the player the camera leads, in seconds of velocity.
@export var look_ahead: float = 0.35
## Follow stiffness (higher = snappier).
@export var follow_rate: float = 5.0

var target: Node2D
var room: Vector2 = Vector2(960, 540)
var _trauma: float = 0.0
var _t: float = 0.0
var _lead: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_detected.connect(func(_by: Node) -> void: add_trauma(0.8))
	Events.station_use_finished.connect(func(_s: Node, who: Node) -> void:
		if who.is_in_group(&"player"):
			add_trauma(0.35))
	Events.rep_completed.connect(func(s: Node, who: Node, good: bool) -> void:
		if good and who.is_in_group(&"player") and (s as Station).data.minigame == &"timing":
			add_trauma(0.3))
	Events.shoved.connect(func(_p: Node, _v: Node, _at: Vector2) -> void: add_trauma(0.75))
	position = room * 0.5


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var playing: bool = GameState.is_running() and target != null and is_instance_valid(target)
	var want_zoom: float = play_zoom if playing else 1.0
	var z: float = lerpf(zoom.x, want_zoom, minf(delta * 3.0, 1.0))
	zoom = Vector2(z, z)
	var goal: Vector2 = room * 0.5
	if playing:
		var body: CharacterBody2D = target as CharacterBody2D
		var vel: Vector2 = body.velocity if body != null else Vector2.ZERO
		_lead = _lead.lerp(vel * look_ahead, minf(delta * 3.0, 1.0))
		goal = target.global_position + Vector2(0, -24) + _lead
	# keep the view inside the room
	var half: Vector2 = get_viewport_rect().size * 0.5 / z
	goal.x = clampf(goal.x, half.x, room.x - half.x) if half.x * 2.0 < room.x else room.x * 0.5
	goal.y = clampf(goal.y, half.y, room.y - half.y) if half.y * 2.0 < room.y else room.y * 0.5
	position = position.lerp(goal, minf(delta * follow_rate, 1.0))


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	_trauma = maxf(_trauma - decay * delta, 0.0)
	var s: float = _trauma * _trauma * max_offset
	offset = Vector2(sin(_t * 47.0), cos(_t * 39.0)) * s
