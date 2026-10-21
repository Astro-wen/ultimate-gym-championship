class_name Patroller
extends ActorBody
## The product manager looking for you. Walks a fixed route, stops at each
## point and sweeps the view cone (predictable, learnable). Turns toward
## loud noises. Builds awareness of the player while seeing them.

signal spotted_player()

enum Mode { WALK, LOOK, INVESTIGATE, RETURN }

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
## Seconds during which awareness cannot rise (after a detection).
var grace: float = 0.0
## Spot where the player can't be seen for `safe_t` more seconds (respawn point).
var safe_point: Vector2 = Vector2.INF
var safe_t: float = 0.0
@export var safe_radius: float = 48.0
var _noise_cd: float = 0.0

var mode: Mode = Mode.LOOK
var level: GymLevel
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
	_timer = wait_time


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
	match mode:
		Mode.WALK, Mode.RETURN:
			if _follow():
				mode = Mode.LOOK
				_timer = wait_time
				_base_angle = _look_angle
		Mode.LOOK:
			_timer -= delta
			# sweep: left, right, back to center over the wait
			var t: float = 1.0 - _timer / wait_time
			_look_angle = _base_angle + deg_to_rad(sweep_deg) * sin(t * TAU)
			if _timer <= 0.0:
				_next_point()
		Mode.INVESTIGATE:
			_timer -= delta
			if _timer <= 0.0:
				_path = level.find_path(global_position, points[_point_i])
				_path_i = 0
				mode = Mode.RETURN
	_update_cone(delta)
	_update_awareness(delta)


func _next_point() -> void:
	_point_i = (_point_i + 1) % points.size()
	_path = level.find_path(global_position, points[_point_i])
	_path_i = 0
	mode = Mode.WALK


func _follow() -> bool:
	if _path_i >= _path.size():
		velocity = Vector2.ZERO
		speed_kind = Speed.STILL
		return true
	var to: Vector2 = _path[_path_i] - global_position
	if to.length() < 3.0:
		_path_i += 1
		return _path_i >= _path.size()
	var dir: Vector2 = to.normalized()
	velocity = dir * walk_speed * difficulty
	facing = dir
	speed_kind = Speed.WALK
	# look where we walk, smoothly
	_look_angle = lerp_angle(_look_angle, dir.angle(), 0.2)
	move_and_slide()
	return false


func _update_cone(_delta: float) -> void:
	cone.rotation = _look_angle
	facing = Vector2.RIGHT.rotated(_look_angle)
	cone.heat = awareness
	cone.range_px = view_range * difficulty
	cone.angle_deg = 70.0 * minf(difficulty, 1.15)


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
	var at_safe: bool = safe_t > 0.0 and p.global_position.distance_to(safe_point) <= safe_radius
	var seen: bool = grace <= 0.0 and not at_safe and cone.visible_fraction(sample_points(p)) > 0.0
	if seen:
		_unseen_t = 0.0
		var stealthy: bool = GameState.has_buff(&"stealthy")
		var in_cover: bool = level.is_in_cover(p.global_position)
		awareness += rise_rate(global_position.distance_to(p.global_position), p.speed_kind, p.exposure(), in_cover, stealthy) * delta
	else:
		_unseen_t += delta
		if _unseen_t >= fall_delay:
			var mult: float = 2.0 if level.is_in_cover(p.global_position) else 1.0
			awareness -= fall_rate * mult * delta
	awareness = clampf(awareness, 0.0, 1.0)
	if awareness >= 1.0:
		spotted_player.emit()


func bubble() -> String:
	if awareness >= 0.7:
		return "!"
	if awareness > 0.15 or mode == Mode.INVESTIGATE:
		return "?"
	return ""
