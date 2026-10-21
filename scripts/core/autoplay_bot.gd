class_name AutoplayBot
extends Node
## Plays the game through real input actions (Input.action_press), for
## balance checks and soak tests. Runs before the player each physics frame.

var player: Player
var level: GymLevel
## Leave a station when the strongest awareness passes this.
var flee_alert: float = 0.55
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0
var _target: Station = null
var _held: Dictionary = {}
var _tap_cd: float = 0.0
var _repath_t: float = 0.0


func _ready() -> void:
	process_physics_priority = -100
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _exit_tree() -> void:
	for a: StringName in _held.keys():
		Input.action_release(a)
	_held.clear()


## Like a human, a key state lasts at least MIN_FRAMES physics frames
## (the player reads input with a frame of latency relative to the bot).
const MIN_FRAMES: int = 3
var _changed_at: Dictionary = {}   # StringName -> physics frame


func _can_change(a: StringName) -> bool:
	return Engine.get_physics_frames() - int(_changed_at.get(a, -1000)) >= MIN_FRAMES


func _press(a: StringName) -> void:
	if _held.has(a) or not _can_change(a):
		return
	Input.action_press(a)
	_held[a] = true
	_changed_at[a] = Engine.get_physics_frames()


func _release(a: StringName) -> void:
	if not _held.has(a) or not _can_change(a):
		return
	Input.action_release(a)
	_held.erase(a)
	_changed_at[a] = Engine.get_physics_frames()


func _tap(a: StringName) -> void:
	if _held.has(a):
		_release(a)
	else:
		_press(a)


func _release_moves() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"sprint", &"leave", &"cup"]:
		if _held.has(a):
			_release(a)


func _alert() -> float:
	var a: float = 0.0
	for n: Node in get_tree().get_nodes_in_group(&"patrollers"):
		a = maxf(a, (n as Patroller).awareness)
	return a


func _physics_process(delta: float) -> void:
	if player == null or not GameState.is_running():
		return
	_tap_cd -= delta
	if player.minigame != null:
		_release_moves()
		if _alert() > flee_alert:
			_press(&"leave")
			return
		_play(player.minigame, delta)
		return
	if _held.has(&"interact"):
		_release(&"interact")
	_navigate(delta)


func _play(g: Minigame, _delta: float) -> void:
	if g is HoldReleaseGame:
		var h: HoldReleaseGame = g
		var z: Vector2 = h.zone()
		if not _held.has(&"interact"):
			_press(&"interact")
		elif h.holding and h.charge >= (z.x + z.y) * 0.5:
			_release(&"interact")
		elif not h.holding and Engine.get_physics_frames() - int(_changed_at.get(&"interact", 0)) > 20:
			# our press was eaten (e.g. lockout): let go and retry
			_release(&"interact")
	elif g is AlternateGame:
		var a: AlternateGame = g
		if _tap_cd <= 0.0:
			var other: StringName = &"move_right" if a.expected == &"move_left" else &"move_left"
			if _held.has(other):
				_release(other)
			if _held.has(a.expected):
				_release(a.expected)
			else:
				_press(a.expected)
			_tap_cd = 0.15
	elif g is RhythmGame:
		var r: RhythmGame = g
		if _held.has(&"interact"):
			_release(&"interact")
		elif _tap_cd <= 0.0 and r.speed < (r.zone().x + r.zone().y) * 0.5:
			_press(&"interact")
			_tap_cd = 0.12
	elif g is TimingGame:
		var tg: TimingGame = g
		var z2: Vector2 = tg.zone()
		if _held.has(&"interact"):
			_release(&"interact")
		elif tg.phase >= z2.x + 0.02 and tg.phase <= z2.y - 0.02:
			_press(&"interact")


func _navigate(delta: float) -> void:
	if _fetch_cup():
		return
	_repath_t -= delta
	if _target_unusable():
		_target = null
		_pick_target()
	elif _repath_t <= 0.0:
		# keep the target (no dithering), just refresh the path
		_path = level.find_path(player.global_position, _target.interact_point())
		_path_i = 0
		_repath_t = 1.0
	if _target == null:
		_release_moves()
		return
	var goal: Vector2 = _target.interact_point()
	if player.global_position.distance_to(goal) < 8.0:
		_release_moves()
		# no shoving: only press E to claim or to join the line
		var waiting: bool = player.queued == _target and not _target.is_turn_of(player)
		# busy machine: set the cup down to reserve it (regulars then leave the line)
		if waiting and player.cup != null and player.cup.carried and player.cup_drop_target() == _target:
			_tap(&"cup")
		if player.focus_station == _target and not waiting and not _held.has(&"interact"):
			_press(&"interact")
		return
	while _path_i < _path.size() and player.global_position.distance_to(_path[_path_i]) < 4.0:
		_path_i += 1
	var next: Vector2 = goal if _path_i >= _path.size() else _path[_path_i]
	var d: Vector2 = next - player.global_position
	_set_move(&"move_right", d.x > 2.0)
	_set_move(&"move_left", d.x < -2.0)
	_set_move(&"move_down", d.y > 2.0)
	_set_move(&"move_up", d.y < -2.0)


func _set_move(a: StringName, on: bool) -> void:
	if on and not _held.has(a):
		_press(a)
	elif not on and _held.has(a):
		_release(a)


func _pick_target() -> void:
	var best: Station = player.queued
	if best == null:
		# nearest machine we can use now; otherwise the shortest line
		var best_score: float = INF
		for st: Station in level.stations:
			if st.is_reserved_against(player) or st == player.last_station:
				continue
			var d: float = player.global_position.distance_to(st.interact_point())
			var score: float = d
			if not st.is_turn_of(player):
				if st.queue_size() >= st.max_queue:
					continue
				score += 400.0 + 300.0 * st.queue_size()
			if score < best_score:
				best_score = score
				best = st
	if best != _target or _path.is_empty():
		_target = best
		_path = level.find_path(player.global_position, best.interact_point()) if best != null else PackedVector2Array()
		_path_i = 0


## After a set on the machine our cup reserved, walk back and pick it up.
## Returns true while busy with that.
func _fetch_cup() -> bool:
	var cup: WaterCup = player.cup
	if cup == null or cup.carried:
		return false
	if cup.reserved != null and player.last_station != cup.reserved:
		return false   # still waiting to use the machine it holds
	if player.can_pick_up_cup():
		_release_moves()
		_tap(&"cup")
		return true
	var d: Vector2 = cup.global_position + Vector2(0, 14) - player.global_position
	_set_move(&"move_right", d.x > 2.0)
	_set_move(&"move_left", d.x < -2.0)
	_set_move(&"move_down", d.y > 2.0)
	_set_move(&"move_up", d.y < -2.0)
	return true


## Re-pick only when the current machine can't work out: just used it,
## someone else's cup holds it, or its line is full and we're not in it.
func _target_unusable() -> bool:
	if _target == null:
		return true
	if player.queued == _target:
		return false
	if player.last_station == _target and player.station == null:
		return true
	if _target.is_reserved_against(player):
		return true
	return not _target.is_turn_of(player) and _target.queue_size() >= _target.max_queue
