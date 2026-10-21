class_name Player
extends ActorBody
## The office worker. Slow walk by default, Shift to run (louder, more visible).
## E near a machine: use it if it's your turn, otherwise join its line (first
## in line may shove the user off). F: put down / pick up the water cup; a cup
## next to a machine reserves it. Q leaves a machine.

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
## After leaving a machine, it can't be re-mounted for this long (mashing E
## through the last rep shouldn't put you straight back on).
@export var remount_delay: float = 0.8
## Walking further than this from the machine you're queued for leaves the line.
@export var queue_leave_dist: float = 120.0
## Once it's your turn, the slot is held this long before you lose your place.
@export var turn_hold: float = 5.0
## How far in front of the feet the cup is set down / can be picked up from.
@export var cup_reach: float = 34.0

const MINIGAME_ACTIONS: Array[StringName] = [&"interact", &"move_left", &"move_right", &"move_up", &"move_down"]

var minigame: Minigame = null
var input_enabled: bool = true
## Station highlighted for interaction (nearest in reach, or the one queued for).
var focus_station: Station = null
## Machine whose line we're standing in (null = none).
var queued: Station = null
var cup: WaterCup = null
var _buffer_t: float = 0.0
var _remount_t: float = 0.0
var _turn_t: float = 0.0
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
	if not input_enabled:
		# scripted (cutscene): whoever disabled input drives speed_kind/facing
		velocity = Vector2.ZERO
		_set_focus(null)
		return
	if not GameState.is_running():
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
		_set_focus(null)
		return
	if minigame != null:
		_drive_minigame(delta)
		return
	_move(delta)
	_update_queue(delta)
	_set_focus(_find_focus_station())
	_buffer_t = maxf(_buffer_t - delta, 0.0)
	_remount_t = maxf(_remount_t - delta, 0.0)
	if Input.is_action_just_pressed(&"cup"):
		toggle_cup()
	if Input.is_action_just_pressed(&"leave") and queued != null:
		leave_queue()
		Events.toast.emit("离开了队伍", &"info")
	if Input.is_action_just_pressed(&"interact"):
		_buffer_t = interact_buffer
	if _buffer_t > 0.0 and focus_station != null and interact(focus_station):
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
	var best: Station = _nearest_station_in_reach()
	# stay on the machine we're queued for, unless one in reach is free for us
	if queued != null and (best == null or best == queued or not best.is_turn_of(self)):
		return queued
	return best


func _nearest_station_in_reach() -> Station:
	var best: Station = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"stations"):
		var st: Station = n as Station
		if st == null or (st == last_station and _remount_t > 0.0):
			continue
		# footprint distance, or distance to where you stand to use it (whichever
		# is closer): the standing spot must always be in reach
		var d: float = minf(st.distance_to_point(global_position), global_position.distance_to(st.interact_point()))
		# prefer the one we're facing when two are in reach
		if facing.dot(st.global_position - global_position) > 0.0:
			d -= 6.0
		if d <= reach and d < best_d:
			best = st
			best_d = d
	return best


# --- queue -------------------------------------------------------------------

func _update_queue(delta: float) -> void:
	if queued == null:
		return
	if not is_instance_valid(queued) or queued.queue_position(self) == -1:
		queued = null
		return
	if global_position.distance_to(queued.interact_point()) > queue_leave_dist:
		leave_queue()
		return
	if queued.is_turn_of(self):
		_turn_t += delta
		if _turn_t > turn_hold:
			leave_queue()
			Events.toast.emit("没及时上器械，排队作废了", &"warn")
	else:
		_turn_t = 0.0


func leave_queue() -> void:
	if queued != null and is_instance_valid(queued):
		queued.leave_queue(self)
	queued = null
	_turn_t = 0.0


## What E does at `st`, as a short label for the HUD (empty = nothing).
func interact_label(st: Station) -> String:
	if st == null or st.is_locked_for(self):
		return ""
	var name_s: String = st.data.display_name
	if st.is_turn_of(self):
		return ("轮到你了！上%s" if queued == st else "开始%s") % name_s
	if st.is_reserved_against(self):
		return ""
	if queued == st:
		if st.queue_position(self) == 0 and _pushable_user(st) != null:
			return "挤开对方抢%s" % name_s
		return ""
	if st.queue_size() >= st.max_queue:
		return ""
	return "排队等%s" % name_s


## E at a machine: use it if it's our turn, shove if first in line and allowed,
## otherwise join the line.
func interact(st: Station) -> bool:
	if st.is_locked_for(self):
		return false
	if st.is_turn_of(self):
		return try_use(st)
	if queued == st:
		if st.queue_position(self) == 0:
			var victim: Node = _pushable_user(st)
			if victim != null:
				return shove(st, victim)
		return false
	if st.join_queue(self):
		if queued != null and queued != st:
			queued.leave_queue(self)
		queued = st
		_turn_t = 0.0
		Events.toast.emit("开始排队：%s（前面 %d 人）" % [st.data.display_name, st.queue_position(self) + (0 if st.is_free() else 1)], &"info")
		return true
	return false


func _pushable_user(st: Station) -> Node:
	for u: Node in st.users():
		if u != self and st.can_push(self, u):
			return u
	return null


## Claim the station if free (used when it's our turn, and by tools/tests).
func try_use(st: Station) -> bool:
	if begin_use(st):
		if queued == st:
			queued = null
		return true
	return false


## Shove `victim` off `st` and take it. Loud, and it hits hard.
func shove(st: Station, victim: Node) -> bool:
	var from: Vector2 = global_position
	if not st.push(self, victim):
		return false
	queued = null
	_attach(st)
	Events.shoved.emit(self, victim, (from + st.global_position) * 0.5)
	return true


# --- water cup -----------------------------------------------------------------

## Station the cup would reserve if dropped now (for the HUD), or null.
func cup_drop_target() -> Station:
	if cup == null or not cup.carried:
		return null
	return WaterCup.station_near(_cup_drop_point(), get_tree())


func can_pick_up_cup() -> bool:
	return cup != null and not cup.carried and global_position.distance_to(cup.global_position) <= cup_reach


func _cup_drop_point() -> Vector2:
	var dir: Vector2 = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	return global_position + dir * 16.0


func toggle_cup() -> void:
	if cup == null:
		return
	if cup.carried:
		var st: Station = cup.drop(_cup_drop_point())
		Events.cup_moved.emit(false)
		if st != null:
			Events.toast.emit("水杯放在%s旁：别人不会来占" % st.data.display_name, &"good")
	elif can_pick_up_cup():
		cup.pick_up()
		Events.cup_moved.emit(true)


# --- using a machine -------------------------------------------------------------

func _on_use_started() -> void:
	# seated at a desk: stay behind it (the desk hides the legs)
	visual.z_index = 0 if station.data.sheet_pose == &"seated" else 1
	_set_focus(null)
	if station.data.sheet_pose == &"back":
		facing = Vector2.UP
	if queued != null:
		leave_queue()
	minigame = Minigame.create(station.data)
	minigame.rep_done.connect(_on_rep_done)
	# keys already held when mounting (the E that mounted us) are not presses
	_down.clear()
	for a: StringName in MINIGAME_ACTIONS:
		_down[a] = Input.is_action_pressed(a)
	# "hold E" tasks: keeping E held from the mounting press starts the hold
	if bool(station.data.minigame_params.get("start_held", false)):
		_down[&"interact"] = false
	minigame_changed.emit(minigame)


func _on_use_ended(_reason: StringName) -> void:
	visual.z_index = 0
	_remount_t = remount_delay
	_buffer_t = 0.0
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


func on_footstep(running: bool) -> void:
	Events.footstep.emit(global_position, running)
	if running:
		DustPuff.spawn(get_parent(), global_position + Vector2(0, -1), -velocity * 0.15)


## Why E does nothing at a gated task (HUD hint), or "" if it isn't gated.
func locked_reason(st: Station) -> String:
	if st == null or not st.is_locked_for(self):
		return ""
	if st.data.once and GameState.sets_done.has(st.data.id):
		return "%s已完成" % st.data.display_name
	for req: StringName in st.data.requires:
		if not GameState.sets_done.has(req):
			var other: Station = null
			for n: Node in get_tree().get_nodes_in_group(&"stations"):
				if (n as Station).data.id == req:
					other = n
			return "先完成：%s" % (other.data.display_name if other != null else String(req))
	return ""
