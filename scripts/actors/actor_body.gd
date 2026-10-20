class_name ActorBody
extends CharacterBody2D
## Shared base for the player and NPCs: movement speed kind, station usage,
## and placeholder rendering. Origin is at the feet (for Y-sort).

enum Speed { STILL, WALK, SPRINT }

@export var body_color: Color = Color(0.95, 0.95, 0.95)
@export var legs_color: Color = Color(0.15, 0.15, 0.2)
@export var hair_color: Color = Color(0.4, 0.25, 0.15)
@export var skin_color: Color = Color(0.98, 0.82, 0.68)

var facing: Vector2 = Vector2.DOWN
var speed_kind: Speed = Speed.STILL
var station: Station = null
## 0..1, drives the exercise pose while on a station.
var pose_amount: float = 0.0
var visual: ActorVisual


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	shape.position = Vector2(0, -6)
	add_child(shape)
	visual = ActorVisual.new()
	visual.actor = self
	add_child(visual)


func is_using() -> bool:
	return station != null


## Claims `st`, snaps onto its anchor. Returns false if it is taken.
func begin_use(st: Station) -> bool:
	if st == null or not st.try_claim(self):
		return false
	_attach(st)
	return true


func _attach(st: Station) -> void:
	station = st
	if not st.user_removed.is_connected(_on_station_user_removed):
		st.user_removed.connect(_on_station_user_removed)
	global_position = st.anchor_for(self)
	velocity = Vector2.ZERO
	speed_kind = Speed.STILL
	set_collision_enabled(false)
	_on_use_started()


## Leaves the current station (if any) through the station's release path.
func end_use(reason: StringName = &"left") -> void:
	if station != null and station.is_user(self):
		station.release(self, reason)
	elif station != null:
		_detach(reason)


func _on_station_user_removed(who: Node, reason: StringName) -> void:
	if who == self:
		_detach(reason)


func _detach(reason: StringName) -> void:
	var st: Station = station
	if st == null:
		return
	station = null
	if st.user_removed.is_connected(_on_station_user_removed):
		st.user_removed.disconnect(_on_station_user_removed)
	if is_instance_valid(st):
		global_position = st.exit_point()
	pose_amount = 0.0
	set_collision_enabled(true)
	_on_use_ended(reason)


func set_collision_enabled(on: bool) -> void:
	for c: Node in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred(&"disabled", not on)


func _exit_tree() -> void:
	if station != null and is_instance_valid(station) and station.is_user(self):
		station.release(self, &"removed")


func _on_use_started() -> void:
	pass


func _on_use_ended(_reason: StringName) -> void:
	pass


func _process(_delta: float) -> void:
	visual.queue_redraw()
