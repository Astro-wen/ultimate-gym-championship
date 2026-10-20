class_name Player
extends ActorBody
## The office worker. Slow walk by default, Shift to run (louder, more visible).
## E near a station claims it and starts its minigame; Q leaves.

signal minigame_changed(game: Minigame)

@export var walk_speed: float = 70.0
@export var sprint_speed: float = 160.0
## px/s² — reach walking speed in ~0.08s, stop in ~0.06s: responsive but not twitchy.
@export var accel: float = 900.0
@export var decel: float = 1200.0
## How far (px) from a station's footprint E still reaches it.
@export var reach: float = 30.0
## An E pressed this long before coming into reach still counts.
@export var interact_buffer: float = 0.18

const MINIGAME_ACTIONS: Array[StringName] = [&"interact", &"move_left", &"move_right", &"move_up", &"move_down"]

var minigame: Minigame = null
var input_enabled: bool = true
## Station highlighted for interaction (nearest in reach).
var focus_station: Station = null
var _buffer_t: float = 0.0
## Last seen pressed state per minigame action. Edges are derived from this
## instead of just_pressed so nothing is lost across pauses or frame hiccups,
## and a key still held from mounting doesn't count as a new press.
var _down: Dictionary = {}


func _ready() -> void:
	super._ready()
	add_to_group(&"player")
	visual.use_pose_art = true
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.NPC
	var meter := MinigameMeter.new()
	meter.player = self
	add_child(meter)


func _physics_process(delta: float) -> void:
	if not input_enabled or not GameState.is_running():
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
		_set_focus(null)
		return
	if minigame != null:
		_drive_minigame(delta)
		return
	_move(delta)
	_set_focus(_find_focus_station())
	_buffer_t = maxf(_buffer_t - delta, 0.0)
	if Input.is_action_just_pressed(&"interact"):
		_buffer_t = interact_buffer
	if _buffer_t > 0.0 and focus_station != null and try_use(focus_station):
		_buffer_t = 0.0


func _move(delta: float) -> void:
	var dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var sprinting: bool = Input.is_action_pressed(&"sprint")
	var target: Vector2 = dir * (sprint_speed if sprinting else walk_speed)
	var rate: float = accel if target.length() >= velocity.length() else decel
	velocity = velocity.move_toward(target, rate * delta)
	if dir != Vector2.ZERO:
		facing = dir
	if velocity.length() < 4.0:
		speed_kind = Speed.STILL
	elif sprinting and dir != Vector2.ZERO:
		speed_kind = Speed.SPRINT
	else:
		speed_kind = Speed.WALK
	move_and_slide()


func _set_focus(st: Station) -> void:
	if st == focus_station:
		return
	if focus_station != null and is_instance_valid(focus_station):
		focus_station.set_focused(false)
	focus_station = st
	if st != null:
		st.set_focused(true)


func _find_focus_station() -> Station:
	var best: Station = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		var st: Station = n as Station
		if st == null:
			continue
		var d: float = st.distance_to_point(global_position)
		# prefer the one we're facing when two are in reach
		if facing.dot(st.global_position - global_position) > 0.0:
			d -= 6.0
		if d <= reach and d < best_d:
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
	_set_focus(null)
	minigame = Minigame.create(station.data)
	minigame.rep_done.connect(_on_rep_done)
	# keys already held when mounting (the E that mounted us) are not presses
	_down.clear()
	for a: StringName in MINIGAME_ACTIONS:
		_down[a] = Input.is_action_pressed(a)
	minigame_changed.emit(minigame)


func _on_use_ended(_reason: StringName) -> void:
	visual.z_index = 0
	minigame = null
	velocity = Vector2.ZERO
	facing = Vector2.DOWN
	minigame_changed.emit(null)


func _on_rep_done(good: bool) -> void:
	if station == null:
		return
	Events.rep_completed.emit(station, self, good)
	var head: Vector2 = global_position + Vector2(0, -station.data.pose_anchor.y - 26.0)
	FloatText.spawn(get_parent(), head, "漂亮" if good else "失误", Color(0.6, 1.0, 0.6) if good else Color(1.0, 0.65, 0.4), 11, 16.0, 0.6)
	if good:
		Events.noise_made.emit(global_position, station.data.noise)


func _drive_minigame(delta: float) -> void:
	velocity = Vector2.ZERO
	speed_kind = Speed.STILL
	if Input.is_action_just_pressed(&"leave"):
		end_use(&"left")
		return
	for a: StringName in MINIGAME_ACTIONS:
		var now: bool = Input.is_action_pressed(a)
		if now != bool(_down.get(a, false)):
			_down[a] = now
			minigame.handle_input(a, now)
			if minigame == null:
				return
	minigame.tick(delta)
	pose_amount = minigame.pose()
	if minigame.is_finished() and station != null:
		var d: StationData = station.data
		FloatText.spawn(get_parent(), global_position + Vector2(0, -d.pose_anchor.y - 30.0), "+%d %s" % [d.stat_gain, Hud.STAT_NAMES.get(d.stat, String(d.stat))], Color(1.0, 0.9, 0.4), 14, 30.0, 1.2)
		station.finish_use(self)


## How visible the player is right now (stealth multiplier).
func exposure() -> float:
	if station != null:
		return station.data.exposure
	return 1.0
