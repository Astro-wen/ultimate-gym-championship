class_name Patroller
extends ActorBody
## The product manager looking for you. Walks her route (the next stop is
## sometimes picked at random, per difficulty), stops and sweeps the view
## cone, turns toward loud noises. Builds awareness while seeing the player;
## once suspicious enough she follows - slower than the player walks, keeping
## her distance - searches where she lost them, then gives up.
## Stationary watchers (desks, front desk) use a look schedule instead.

signal spotted_player()

enum Mode { WALK, LOOK, INVESTIGATE, RETURN, FOLLOW, SEARCH }

@export var walk_speed: float = 55.0
@export var wait_time: float = 2.4
@export var sweep_deg: float = 50.0
@export var hearing_range: float = 320.0
@export var investigate_time: float = 2.0
## After turning toward a noise, quieter noises are ignored this long so the
## PM returns to the route instead of staring at a busy machine forever.
@export var noise_cooldown: float = 5.0
## Awareness tuning (see OPUS_BRIEF 3.7).
@export var base_rise: float = 0.5
@export var fall_rate: float = 0.4
@export var fall_delay: float = 0.6
@export var speed_factor_still: float = 0.3
@export var speed_factor_walk: float = 1.0
@export var speed_factor_sprint: float = 2.5
@export var cover_factor: float = 0.5
@export var buff_factor: float = 0.6
## Grows +5% per detection (capped at +30%).
@export var difficulty: float = 1.0
@export var view_range: float = 264.0
@export var view_angle: float = 70.0
## Difficulty multiplier on every view range (schedules included).
var range_mult: float = 1.0
## Stationary watchers (desk colleagues, receptionist): cycle through
## (look angle deg, seconds, view range px) instead of walking a route.
var look_schedule: Array[Vector3] = []
## Body painted by the level art (receptionist behind the counter).
var hide_body: bool = false
var _sched_i: int = 0
var _sched_t: float = 0.0
var _sched_range: float = 0.0
## Full look-schedule cycles at the first point before walking the route.
var schedule_loops: int = 1
var _sched_cycles: int = 0
## Seconds during which awareness cannot rise (after a detection).
var grace: float = 0.0
## Spot where the player can't be seen for `safe_t` more seconds (respawn point).
var safe_point: Vector2 = Vector2.INF
var safe_t: float = 0.0
@export var safe_radius: float = 48.0
var _noise_cd: float = 0.0

var mode: Mode = Mode.LOOK
var level: Level
var points: Array[Vector2] = []
var cone: VisionCone
var awareness: float = 0.0
var target_player: Player
var _point_i: int = 0
var _timer: float = 0.0
var _look_angle: float = PI * 0.5
var _base_angle: float = PI * 0.5
var _unseen_t: float = 0.0
var _path: PackedVector2Array = PackedVector2Array()
var _path_i: int = 0

## Following (PM only; set from Difficulty).
var can_chase: bool = false
var chase_speed: float = 50.0
## Seconds she keeps following after losing sight of the player.
var chase_give_up: float = 4.0
## Awareness at which she starts to follow.
var follow_threshold: float = 0.35
## She stops this far from the player while she can see them.
var keep_distance: float = 80.0
## Awareness rises slower while she walks after you than when she stands and
## scans (following is suspicion, not certainty).
var follow_rise_mult: float = 0.6
var search_time: float = 2.2
## Chance the next patrol stop is random instead of the next in order.
var route_randomness: float = 0.0
var rng := RandomNumberGenerator.new()
var _sees_player: bool = false
var _last_seen: Vector2 = Vector2.ZERO
var _lost_t: float = 0.0
var _repath_t: float = 0.0
var _prev_point: int = -1
var _wait_now: float = 2.4


func _ready() -> void:
	super._ready()
	add_to_group(&"npc")
	add_to_group(&"patrollers")
	collision_layer = Layers.NPC
	collision_mask = Layers.WORLD
	body_color = Color(0.3, 0.45, 0.75)
	legs_color = Color(0.25, 0.25, 0.3)
	hair_color = Color(0.12, 0.1, 0.1)
	cone = VisionCone.new()
	cone.position = Vector2(0, -8)
	cone.exclude = [get_rid()]
	cone.z_index = -1
	add_child(cone)
	Events.noise_made.connect(_on_noise)
	Events.run_started.connect(_seed_rng)
	_timer = wait_time
	_wait_now = wait_time
	if hide_body:
		visual.visible = false
	if not look_schedule.is_empty():
		_look_angle = deg_to_rad(look_schedule[0].x)
		_sched_range = look_schedule[0].z
		_sched_t = look_schedule[0].y


func reset_to_start() -> void:
	awareness = 0.0
	_point_i = 0
	mode = Mode.LOOK
	_timer = wait_time
	if not points.is_empty():
		global_position = points[0]
	Events.alert_changed.emit(0.0)


func _physics_process(delta: float) -> void:
	if level == null or points.is_empty():
		return
	if not GameState.is_running():
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
		_update_cone(delta)
		return
	if _on_schedule():
		if _run_schedule(delta) and points.size() > 1:
			# done at the seat: go for a walk (e.g. the receptionist's water run)
			_next_point()
		_update_cone(delta)
		_update_awareness(delta)
		return
	if can_chase and _sees_player and awareness >= follow_threshold and mode != Mode.FOLLOW:
		_start_follow()
	match mode:
		Mode.WALK, Mode.RETURN:
			if _follow(delta, walk_speed):
				if mode == Mode.WALK and _point_i == 0:
					_restart_schedule()
				mode = Mode.LOOK
				# how long she lingers varies (more with higher route randomness)
				_wait_now = wait_time * rng.randf_range(1.0 - 0.4 * route_randomness, 1.0 + 0.6 * route_randomness)
				_timer = _wait_now
				_base_angle = _look_angle
		Mode.LOOK:
			_timer -= delta
			# sweep: left, right, back to center over the wait
			var t: float = 1.0 - _timer / maxf(_wait_now, 0.01)
			_look_angle = _base_angle + deg_to_rad(sweep_deg) * sin(t * TAU)
			if _timer <= 0.0:
				_next_point()
		Mode.FOLLOW:
			_do_follow(delta)
		Mode.SEARCH:
			_timer -= delta
			var ts: float = 1.0 - _timer / search_time
			_look_angle = _base_angle + deg_to_rad(70.0) * sin(ts * TAU)
			if _timer <= 0.0:
				_return_to_route()
		Mode.INVESTIGATE:
			_timer -= delta
			if _timer <= 0.0:
				_path = level.find_path(global_position, points[_point_i])
				_path_i = 0
				mode = Mode.RETURN
	_update_cone(delta)
	_update_awareness(delta)


func _next_point() -> void:
	var n: int = points.size()
	var nxt: int = (_point_i + 1) % n
	if n > 2 and rng.randf() < route_randomness:
		# somewhere else on the route, but not straight back
		var options: Array[int] = []
		for i: int in n:
			if i != _point_i and i != _prev_point:
				options.append(i)
		if not options.is_empty():
			nxt = options[rng.randi() % options.size()]
	_prev_point = _point_i
	_point_i = nxt
	_path = level.find_path(global_position, points[_point_i])
	_path_i = 0
	mode = Mode.WALK


func _follow(delta: float, speed: float) -> bool:
	if _path_i >= _path.size():
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
		return true
	var to: Vector2 = _path[_path_i] - global_position
	var last: bool = _path_i == _path.size() - 1
	if to.length() < (3.0 if last else 7.0):
		_path_i += 1
		return _path_i >= _path.size()
	steer(to, speed * difficulty, last, delta)
	# look where we walk, smoothly
	_look_angle = lerp_angle(_look_angle, velocity.angle(), minf(delta * 8.0, 1.0))
	return false


func _update_cone(_delta: float) -> void:
	cone.rotation = _look_angle
	facing = Vector2.RIGHT.rotated(_look_angle)
	cone.heat = awareness
	var r: float = _sched_range if _on_schedule() else view_range
	cone.range_px = r * difficulty * range_mult
	cone.angle_deg = view_angle * minf(difficulty, 1.15)


func _on_noise(at: Vector2, loudness: float) -> void:
	if not GameState.is_running():
		return
	if global_position.distance_to(at) > hearing_range * loudness:
		return
	if _noise_cd > 0.0 and loudness < 1.0:
		return
	_noise_cd = noise_cooldown
	mode = Mode.INVESTIGATE
	_timer = investigate_time
	velocity = Vector2.ZERO
	_look_angle = (at - cone.global_position).angle()


## Player sample points on the ground plane (cone works in the same plane):
## center plus four corners of the footprint (OPUS_BRIEF 3.7).
static func sample_points(p: Node2D) -> PackedVector2Array:
	var c: Vector2 = p.global_position + Vector2(0, -8)
	return PackedVector2Array([c, c + Vector2(-7, -6), c + Vector2(7, -6), c + Vector2(-7, 6), c + Vector2(7, 6)])


func rise_rate(dist: float, kind: ActorBody.Speed, exposure: float, in_cover: bool, stealthy: bool) -> float:
	var speed_f: float = speed_factor_walk
	match kind:
		ActorBody.Speed.STILL:
			speed_f = speed_factor_still
		ActorBody.Speed.SPRINT:
			speed_f = speed_factor_sprint
	var dist_f: float = lerpf(1.6, 0.5, clampf(dist / cone.range_px, 0.0, 1.0))
	var r: float = base_rise * dist_f * speed_f * exposure * difficulty
	if in_cover:
		r *= 1.0 - cover_factor
	if stealthy:
		r *= buff_factor
	return r


func _update_awareness(delta: float) -> void:
	var p: Player = target_player
	if p == null or not is_instance_valid(p):
		return
	grace = maxf(grace - delta, 0.0)
	safe_t = maxf(safe_t - delta, 0.0)
	_noise_cd = maxf(_noise_cd - delta, 0.0)
	var at_safe: bool = (safe_t > 0.0 and p.global_position.distance_to(safe_point) <= safe_radius) or level.is_in_safe_zone(p.global_position)
	var seen: bool = grace <= 0.0 and not at_safe and cone.visible_fraction(sample_points(p)) > 0.0
	_sees_player = seen
	if seen:
		_unseen_t = 0.0
		var stealthy: bool = GameState.has_buff(&"stealthy")
		# standing in a line you blend in with the crowd: counts as cover
		var in_cover: bool = level.is_in_cover(p.global_position) or p.queued != null
		awareness += rise_rate(global_position.distance_to(p.global_position), p.speed_kind, p.exposure(), in_cover, stealthy) * delta * (follow_rise_mult if mode == Mode.FOLLOW else 1.0)
	else:
		_unseen_t += delta
		if _unseen_t >= fall_delay:
			var mult: float = 2.0 if level.is_in_cover(p.global_position) or p.queued != null else 1.0
			awareness -= fall_rate * mult * delta
	awareness = clampf(awareness, 0.0, 1.0)
	if awareness >= 1.0:
		spotted_player.emit()


func bubble() -> String:
	if awareness >= 0.7:
		return "!"
	if awareness > 0.15 or mode == Mode.INVESTIGATE or is_following():
		return "?"
	return ""


## Watching from the first route point (a desk or the front desk).
func _on_schedule() -> bool:
	return not look_schedule.is_empty() and mode == Mode.LOOK and _point_i == 0


func _restart_schedule() -> void:
	_sched_i = 0
	_sched_cycles = 0
	_sched_t = look_schedule[0].y if not look_schedule.is_empty() else 0.0


## Turn smoothly to each scheduled direction and hold it. Returns true once
## `schedule_loops` full cycles are done (ignored with a one-point route).
func _run_schedule(delta: float) -> bool:
	velocity = Vector2.ZERO
	speed_kind = Speed.STILL
	_sched_t -= delta
	if _sched_t <= 0.0:
		_sched_i = (_sched_i + 1) % look_schedule.size()
		_sched_t = look_schedule[_sched_i].y
		if _sched_i == 0:
			_sched_cycles += 1
	var target: float = deg_to_rad(look_schedule[_sched_i].x)
	_look_angle = lerp_angle(_look_angle, target, minf(delta * 6.0, 1.0))
	_sched_range = lerpf(_sched_range, look_schedule[_sched_i].z, minf(delta * 6.0, 1.0))
	if _sched_cycles >= schedule_loops:
		_sched_cycles = 0
		return true
	return false


## Seconds until the current look direction changes (for tells/tests).
func schedule_time_left() -> float:
	return _sched_t


## Typing at the desk while looking at the screen (short view range).
func busy_motion() -> float:
	return 0.6 if _on_schedule() and _sched_range < 110.0 else 0.0


# --- following ---------------------------------------------------------------

func _seed_rng() -> void:
	rng.seed = hash(String(name)) ^ GameState.run_seed


func _start_follow() -> void:
	mode = Mode.FOLLOW
	_lost_t = 0.0
	_repath_t = 0.0
	if target_player != null:
		_last_seen = target_player.global_position
	if String(name) == "ProductManager":
		Events.toast.emit("产品经理起疑了，正往你这边走！", &"warn")


## Walk toward where the player was last seen; hold back while she can see
## them up close; lose interest after `chase_give_up` seconds without sight.
func _do_follow(delta: float) -> void:
	var p: Player = target_player
	if p != null and _sees_player:
		_last_seen = p.global_position
		_lost_t = 0.0
	else:
		_lost_t += delta
	var to_last: Vector2 = _last_seen - global_position
	_look_angle = lerp_angle(_look_angle, (_last_seen - cone.global_position).angle(), minf(delta * 6.0, 1.0))
	if _sees_player and to_last.length() <= keep_distance:
		# close enough: stand and stare instead of bumping into you
		velocity = velocity.move_toward(Vector2.ZERO, steer_accel * delta)
		speed_kind = Speed.STILL
	else:
		_repath_t -= delta
		if _repath_t <= 0.0:
			_repath_t = 0.4
			_path = level.find_path(global_position, _last_seen)
			_path_i = 0
		var arrived: bool = _follow(delta, chase_speed)
		if arrived and not _sees_player:
			_start_search()
			return
	if _lost_t >= chase_give_up:
		_start_search()


func _start_search() -> void:
	mode = Mode.SEARCH
	_timer = search_time
	_base_angle = _look_angle
	velocity = Vector2.ZERO
	speed_kind = Speed.STILL


## Back to the nearest point of the route.
func _return_to_route() -> void:
	var best: int = 0
	var best_d: float = INF
	for i: int in points.size():
		var d: float = global_position.distance_to(points[i])
		if d < best_d:
			best_d = d
			best = i
	_point_i = best
	_path = level.find_path(global_position, points[_point_i])
	_path_i = 0
	mode = Mode.RETURN


## Called after a detection: forget the chase.
func stop_chase() -> void:
	_sees_player = false
	if mode == Mode.FOLLOW or mode == Mode.SEARCH:
		_return_to_route()


func is_following() -> bool:
	return mode == Mode.FOLLOW or mode == Mode.SEARCH
