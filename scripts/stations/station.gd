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
## Longest line a machine allows.
@export var max_queue: int = 3
@export var queue_spacing: float = 34.0

## instance_id -> Station, shared by every station so one actor can't hold two.
static var _claims: Dictionary = {}

## Who holds this machine with a water cup (null = nobody).
var reserved_by: Node = null

var _users: Array[Node] = []
var _claimed_at: Dictionary = {}     # instance_id -> float (seconds, station clock)
var _exit_hooks: Dictionary = {}     # instance_id -> Callable
var _queue: Array[Node] = []
var _clock: float = 0.0
var _body: StaticBody2D
var _tex: Texture2D
var _focused: bool = false


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
	if _focused:
		queue_redraw()


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
	if _users.size() >= data.capacity or is_reserved_against(who) or is_locked_for(who):
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


# --- reservation (water cup) -----------------------------------------------

## A water cup next to the machine reserves it: only `who` may claim it, and
## everyone else in line gives up.
func reserve(who: Node) -> void:
	reserved_by = who
	for i: int in range(_queue.size() - 1, -1, -1):
		if _queue[i] != who:
			_queue.remove_at(i)
	queue_redraw()


func unreserve() -> void:
	reserved_by = null
	queue_redraw()


## Unfinished prerequisite tasks block the player (NPCs never use gated stations).
func is_locked_for(_who: Node) -> bool:
	if data == null:
		return false
	if data.once and GameState.sets_done.has(data.id):
		return true
	for req: StringName in data.requires:
		if not GameState.sets_done.has(req):
			return true
	return false


func is_reserved_against(who: Node) -> bool:
	return reserved_by != null and is_instance_valid(reserved_by) and reserved_by != who


## A slot is free and no one else's cup is holding it.
func is_available_for(who: Node) -> bool:
	return is_free() and not is_reserved_against(who)


# --- queue ------------------------------------------------------------------

## Joins the line. False if the line is full or the machine is reserved.
func join_queue(who: Node) -> bool:
	if who == null or _users.has(who) or is_reserved_against(who):
		return false
	if _queue.has(who):
		return true
	_prune_queue()
	if _queue.size() >= max_queue:
		return false
	_queue.append(who)
	return true


func queue_size() -> int:
	_prune_queue()
	return _queue.size()


## Where the i-th person in line stands (0 = next up).
func queue_spot(i: int) -> Vector2:
	return interact_point() + data.queue_dir.normalized() * queue_spacing * float(i + 1)


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


## True if `who` may claim now: a slot is free, it isn't reserved for someone
## else, and nobody is ahead in line. The cup owner skips the line.
func is_turn_of(who: Node) -> bool:
	if not is_free():
		return false
	if is_locked_for(who):
		return false
	if reserved_by != null and is_instance_valid(reserved_by):
		return who == reserved_by
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
	if not data.draw_base:
		pass
	elif tex != null:
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
	if _focused:
		_draw_focus_marker()


# --- focus marker ----------------------------------------------------------

## Shows/hides the bouncing "E" marker (set by the player).
func set_focused(on: bool) -> void:
	if _focused == on:
		return
	_focused = on
	queue_redraw()


## Distance from `p` to this station's solid footprint (0 if inside).
func distance_to_point(p: Vector2) -> float:
	if data == null:
		return INF
	var fp: Vector2 = data.footprint
	var r := Rect2(global_position + Vector2(-fp.x * 0.5, -fp.y), fp)
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q)


func _visual_height() -> float:
	if data.base_region.has_area():
		return data.base_region.size.y
	return data.footprint.y + 16.0


func _draw_focus_marker() -> void:
	var font: Font = ThemeDB.fallback_font
	var bob: float = sin(_clock * 6.0) * 2.0
	var c := Vector2(0, -_visual_height() - 14.0 + bob)
	var key := Rect2(c - Vector2(9, 9), Vector2(18, 18))
	draw_rect(key, Color(0.98, 0.95, 0.8))
	draw_rect(key, Color(0.15, 0.15, 0.2), false, 2.0)
	draw_string(font, c + Vector2(-9, 5), "E", HORIZONTAL_ALIGNMENT_CENTER, 18, 14, Color(0.15, 0.15, 0.2))
	var col := Color(0.3, 1.0, 0.5) if is_free() else Color(1.0, 0.7, 0.3)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 12), c + Vector2(5, 12), c + Vector2(0, 17)]), col)
