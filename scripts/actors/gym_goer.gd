class_name GymGoer
extends ActorBody
## Competing gym regular. Picks a station, walks there, queues if taken
## (with patience), does a set, rests, repeats. Gets angry when pushed.
## Never holds a station while not standing on it; never waits forever.

enum Mode { CHOOSE, WALK, QUEUE, USE, REST, ANGRY }

@export var walk_speed: float = 60.0
@export var patience: float = 6.0
@export var rest_time: Vector2 = Vector2(1.5, 4.0)
@export var angry_time: float = 2.0
@export var stuck_timeout: float = 3.0

var mode: Mode = Mode.CHOOSE
var level: GymLevel
var target: Station = null
var rng := RandomNumberGenerator.new()
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _timer: float = 0.0
var _last_station: Station = null
var _stuck_t: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _use_t: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(&"npc")
	add_to_group(&"gym_goers")
	collision_layer = Layers.NPC
	collision_mask = Layers.WORLD
	_set_mode(Mode.REST)
	_timer = rng.randf_range(0.2, 1.5)


func _physics_process(delta: float) -> void:
	if level == null:
		return
	match mode:
		Mode.CHOOSE:
			_choose()
		Mode.WALK:
			_walk(delta)
		Mode.QUEUE:
			_queue(delta)
		Mode.USE:
			_use(delta)
		Mode.REST, Mode.ANGRY:
			velocity = Vector2.ZERO
			speed_kind = Speed.STILL
			_timer -= delta
			if _timer <= 0.0:
				_set_mode(Mode.CHOOSE)


func _set_mode(m: Mode) -> void:
	if mode == Mode.QUEUE and m != Mode.QUEUE and target != null and is_instance_valid(target):
		target.leave_queue(self)
	mode = m
	_stuck_t = 0.0
	match m:
		Mode.REST:
			_timer = rng.randf_range(rest_time.x, rest_time.y)
			target = null
		Mode.ANGRY:
			_timer = angry_time
			target = null
		Mode.QUEUE:
			_timer = patience


func _choose() -> void:
	var free: Array[Station] = []
	var busy: Array[Station] = []
	for st: Station in level.stations:
		if st == _last_station and level.stations.size() > 1:
			continue
		if st.is_free():
			free.append(st)
		else:
			busy.append(st)
	var pick: Station = null
	if not free.is_empty():
		pick = free[rng.randi() % free.size()]
	elif not busy.is_empty():
		pick = busy[rng.randi() % busy.size()]
	if pick == null:
		_set_mode(Mode.REST)
		return
	target = pick
	_go_to(target.interact_point())
	_set_mode(Mode.WALK)


func _go_to(p: Vector2) -> void:
	_path = level.find_path(global_position, p)
	_path_i = 0
	_last_pos = global_position


## Follows the current path. Returns true once arrived.
func _follow(delta: float) -> bool:
	if _path_i >= _path.size():
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
		return true
	var next: Vector2 = _path[_path_i]
	var to: Vector2 = next - global_position
	if to.length() < 3.0:
		_path_i += 1
		return _path_i >= _path.size()
	var dir: Vector2 = to.normalized()
	velocity = dir * walk_speed
	facing = dir
	speed_kind = Speed.WALK
	move_and_slide()
	# stuck detection
	if global_position.distance_to(_last_pos) < 0.5 * walk_speed * delta:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	return false


func _walk(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_set_mode(Mode.CHOOSE)
		return
	var arrived: bool = _follow(delta)
	if _stuck_t > stuck_timeout:
		_last_station = target
		_set_mode(Mode.REST)
		return
	if arrived:
		if target.is_turn_of(self) and begin_use(target):
			return
		target.join_queue(self)
		_set_mode(Mode.QUEUE)
		var pos: int = maxi(target.queue_position(self), 0)
		_go_to(level.nearest_walkable(target.interact_point() + Vector2(26.0 * (pos + 1), 10.0)))


func _queue(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_set_mode(Mode.CHOOSE)
		return
	_follow(delta)
	if target.is_turn_of(self):
		if global_position.distance_to(target.interact_point()) > 6.0 and _path_i >= _path.size():
			_go_to(target.interact_point())
		if global_position.distance_to(target.interact_point()) <= 6.0 and begin_use(target):
			return
	_timer -= delta
	if _timer <= 0.0:
		_last_station = target
		_set_mode(Mode.CHOOSE)


func _on_use_started() -> void:
	mode = Mode.USE
	_use_t = 0.0
	visual.z_index = 1


func _use(delta: float) -> void:
	velocity = Vector2.ZERO
	speed_kind = Speed.STILL
	if station == null:
		_set_mode(Mode.REST)
		return
	_use_t += delta
	pose_amount = 0.5 + 0.5 * sin(_use_t * TAU * 0.8)
	if station.data.minigame == &"rhythm":
		pose_amount = fmod(_use_t * 1.6, 1.0)
	if _use_t >= station.data.use_time:
		_last_station = station
		station.finish_use(self)


func _on_use_ended(reason: StringName) -> void:
	visual.z_index = 0
	if reason == &"pushed":
		_set_mode(Mode.ANGRY)
	else:
		_set_mode(Mode.REST)


func is_angry() -> bool:
	return mode == Mode.ANGRY


func bubble() -> String:
	return "怒" if mode == Mode.ANGRY else ""
