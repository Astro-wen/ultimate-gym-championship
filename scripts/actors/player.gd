class_name Player
extends ActorBody
## The office worker. Slow walk by default, Shift to run (louder, more visible).
## E near a station claims it and starts its minigame; Q leaves.

signal minigame_changed(game: Minigame)

@export var walk_speed: float = 70.0
@export var sprint_speed: float = 160.0
@export var push_reach: float = 52.0

const MINIGAME_ACTIONS: Array[StringName] = [&"interact", &"move_left", &"move_right", &"move_up", &"move_down"]

var minigame: Minigame = null
var input_enabled: bool = true
## Station currently highlighted for interaction (nearest in reach).
var focus_station: Station = null


func _ready() -> void:
	super._ready()
	add_to_group(&"player")
	visual.use_pose_art = true
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.NPC


func _physics_process(delta: float) -> void:
	if not input_enabled or not GameState.is_running():
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
		if minigame == null:
			return
	if minigame != null:
		_drive_minigame(delta)
		return
	_move()
	focus_station = _find_focus_station()
	if Input.is_action_just_pressed(&"interact") and focus_station != null:
		try_use(focus_station)


func _move() -> void:
	var dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if dir == Vector2.ZERO:
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
	else:
		var sprinting: bool = Input.is_action_pressed(&"sprint")
		velocity = dir * (sprint_speed if sprinting else walk_speed)
		speed_kind = Speed.SPRINT if sprinting else Speed.WALK
		facing = dir
	move_and_slide()


func _find_focus_station() -> Station:
	var best: Station = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		var st: Station = n as Station
		if st == null:
			continue
		var d: float = global_position.distance_to(st.interact_point())
		if d <= st.interact_radius and d < best_d:
			best = st
			best_d = d
	return best


## Claim the station, or shove its current (NPC) user off if allowed.
func try_use(st: Station) -> bool:
	if begin_use(st):
		return true
	for u: Node in st.users():
		if u != self and st.can_push(self, u):
			if st.push(self, u):
				_attach(st)
				return true
	return false


func _on_use_started() -> void:
	visual.z_index = 1
	minigame = Minigame.create(station.data)
	minigame.rep_done.connect(_on_rep_done)
	minigame_changed.emit(minigame)


func _on_use_ended(_reason: StringName) -> void:
	visual.z_index = 0
	minigame = null
	minigame_changed.emit(null)


func _on_rep_done(good: bool) -> void:
	if station == null:
		return
	Events.rep_completed.emit(station, self, good)
	if good:
		Events.noise_made.emit(global_position, station.data.noise)


func _drive_minigame(delta: float) -> void:
	velocity = Vector2.ZERO
	if GameState.is_running() and input_enabled:
		if Input.is_action_just_pressed(&"leave"):
			end_use(&"left")
			return
		for a: StringName in MINIGAME_ACTIONS:
			if Input.is_action_just_pressed(a):
				minigame.handle_input(a, true)
			elif Input.is_action_just_released(a):
				minigame.handle_input(a, false)
		minigame.tick(delta)
	if minigame == null:
		return
	pose_amount = minigame.pose()
	if minigame.is_finished() and station != null:
		station.finish_use(self)


## How visible the player is right now (stealth multiplier).
func exposure() -> float:
	if station != null:
		return station.data.exposure
	return 1.0
