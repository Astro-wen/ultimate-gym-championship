class_name Station
extends Node2D
## A piece of gym equipment. Owns the occupancy rules:
## - try_claim() is atomic; one actor holds at most one station at a time.
## - every way of leaving goes through release(); _exit_tree releases everyone.
## - push() swaps users with a protection window so actors can't ping-pong.

signal user_removed(who: Node, reason: StringName)

@export var data: StationData
## Seconds after claiming during which a user can't be pushed off.
@export var push_protect: float = 3.0
@export var interact_radius: float = 44.0

## instance_id -> Station, shared by every station so one actor can't hold two.
static var _claims: Dictionary = {}

var _users: Array[Node] = []
var _claimed_at: Dictionary = {}     # instance_id -> float (seconds, station clock)
var _exit_hooks: Dictionary = {}     # instance_id -> Callable
var _queue: Array[Node] = []
var _clock: float = 0.0
var _body: StaticBody2D
var _tex: Texture2D


static func station_of(who: Node) -> Station:
	if who == null:
		return null
	var s: Variant = _claims.get(who.get_instance_id())
	if s == null or not is_instance_valid(s):
		_claims.erase(who.get_instance_id())
		return null
	return s as Station


static func clear_all_claims() -> void:
	_claims.clear()


func _ready() -> void:
	add_to_group(&"stations")
	if data != null and data.base_texture == null and data.base_texture_path != "":
		_tex = LocalArt.tex(data.base_texture_path)
	y_sort_enabled = false
	_build_body()
	queue_redraw()


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_clock += delta


func _exit_tree() -> void:
	for who: Node in _users.duplicate():
		release(who, &"removed")
	_queue.clear()


# --- occupancy ---------------------------------------------------------

func capacity() -> int:
	return data.capacity if data != null else 0


func users() -> Array[Node]:
	return _users.duplicate()


func is_free() -> bool:
	return data != null and _users.size() < data.capacity


func is_user(who: Node) -> bool:
	return who != null and _users.has(who)


func slot_of(who: Node) -> int:
	return _users.find(who)


func try_claim(who: Node) -> bool:
	if who == null or data == null or not is_instance_valid(who):
		return false
	if station_of(who) != null:
		return false
	if _users.size() >= data.capacity:
		return false
	var id: int = who.get_instance_id()
	_users.append(who)
	_claims[id] = self
	_claimed_at[id] = _clock
	var hook: Callable = _on_user_exiting.bind(who)
	_exit_hooks[id] = hook
	who.tree_exiting.connect(hook)
	leave_queue(who)
	Events.station_claimed.emit(self, who)
	return true


func release(who: Node, reason: StringName = &"left") -> bool:
	if who == null or not _users.has(who):
		return false
	var id: int = who.get_instance_id()
	_users.erase(who)
	if _claims.get(id) == self:
		_claims.erase(id)
	_claimed_at.erase(id)
	var hook: Variant = _exit_hooks.get(id)
	if hook != null and is_instance_valid(who) and who.tree_exiting.is_connected(hook):
		who.tree_exiting.disconnect(hook)
	_exit_hooks.erase(id)
	user_removed.emit(who, reason)
	Events.station_released.emit(self, who)
	return true


## Completes a set for `who`. Rewards apply only to the player, once per claim.
func finish_use(who: Node) -> bool:
	if not is_user(who):
		return false
	Events.station_use_finished.emit(self, who)
	if who.is_in_group(&"player"):
		GameState.record_set(data.id, data.stat, data.stat_gain)
		GameState.apply_buff(data.buff_kind, data.buff_duration)
	release(who, &"finished")
	return true


func can_push(pusher: Node, victim: Node) -> bool:
	if pusher == null or victim == null or pusher == victim:
		return false
	if not is_user(victim) or station_of(pusher) != null:
		return false
	var since: float = _clock - float(_claimed_at.get(victim.get_instance_id(), _clock))
	return since >= push_protect


## Shoves `victim` off and gives the slot to `pusher`. Loud.
func push(pusher: Node, victim: Node) -> bool:
	if not can_push(pusher, victim):
		return false
	release(victim, &"pushed")
	var ok: bool = try_claim(pusher)
	if ok:
		Events.noise_made.emit(global_position, 1.0)
	return ok


func _on_user_exiting(who: Node) -> void:
	release(who, &"removed")


# --- queue (NPCs only) ---------------------------------------------------

func join_queue(who: Node) -> void:
	if who != null and not _queue.has(who) and not _users.has(who):
		_queue.append(who)


func leave_queue(who: Node) -> void:
	_queue.erase(who)


func queue_position(who: Node) -> int:
	_prune_queue()
	return _queue.find(who)


func _prune_queue() -> void:
	for i: int in range(_queue.size() - 1, -1, -1):
		var n: Variant = _queue[i]
		if not is_instance_valid(n):
			_queue.remove_at(i)


## True if `who` may claim now: a slot is free and nobody is ahead in line.
func is_turn_of(who: Node) -> bool:
	if not is_free():
		return false
	_prune_queue()
	var pos: int = _queue.find(who)
	var free_slots: int = data.capacity - _users.size()
	return pos == -1 and _queue.is_empty() or pos >= 0 and pos < free_slots


# --- geometry ------------------------------------------------------------

func anchor_for(who: Node) -> Vector2:
	var slot: int = maxi(slot_of(who), 0)
	var offs: Array[Vector2] = data.anchor_offsets
	var off: Vector2 = offs[slot] if slot < offs.size() else Vector2.ZERO
	return global_position + off


func exit_point() -> Vector2:
	return global_position + data.exit_offset


func interact_point() -> Vector2:
	return exit_point()


func _build_body() -> void:
	if data == null or data.footprint == Vector2.ZERO:
		return
	_body = StaticBody2D.new()
	_body.collision_layer = Layers.WORLD
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = data.footprint
	shape.shape = rect
	shape.position = Vector2(0, -data.footprint.y * 0.5)
	_body.add_child(shape)
	add_child(_body)


func _draw() -> void:
	if data == null:
		return
	var tex: Texture2D = data.base_texture if data.base_texture != null else _tex
	if tex != null:
		var tex_size: Vector2 = data.base_region.size if data.base_region.has_area() else tex.get_size()
		var dst := Rect2(Vector2(-tex_size.x * 0.5, -tex_size.y), tex_size)
		if data.base_region.has_area():
			draw_texture_rect_region(tex, dst, data.base_region)
		else:
			draw_texture_rect(tex, dst, false)
	else:
		var fp: Vector2 = data.footprint
		draw_rect(Rect2(Vector2(-fp.x * 0.5, -fp.y - 16), Vector2(fp.x, fp.y + 16)), data.placeholder_color)
		draw_rect(Rect2(Vector2(-fp.x * 0.5, -fp.y - 16), Vector2(fp.x, fp.y + 16)), Color(0.1, 0.1, 0.15), false, 2.0)
