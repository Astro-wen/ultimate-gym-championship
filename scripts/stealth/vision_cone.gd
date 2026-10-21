class_name VisionCone
extends Node2D
## Flashlight-style view cone. Raycasts against the vision_blocker layer to
## build an occluded polygon, used both for drawing and for detection.
## Rotation of this node is the look direction.

@export var angle_deg: float = 70.0
@export var range_px: float = 288.0
@export var ray_count: int = 32
@export var fill_color: Color = Color(1.0, 0.95, 0.55, 0.18)
@export var alert_color: Color = Color(1.0, 0.3, 0.25, 0.30)
## 0..1, tints the cone as awareness grows.
var heat: float = 0.0
## Collision objects that never block (e.g. the owner).
var exclude: Array[RID] = []
var polygon: PackedVector2Array = PackedVector2Array()


func _physics_process(_delta: float) -> void:
	rebuild()
	queue_redraw()


func rebuild() -> void:
	polygon = PackedVector2Array([Vector2.ZERO])
	var half: float = deg_to_rad(angle_deg) * 0.5
	for i: int in ray_count + 1:
		var a: float = -half + (2.0 * half) * float(i) / float(ray_count)
		var local_end: Vector2 = Vector2.RIGHT.rotated(a) * range_px
		var hit: Variant = _cast(global_position, to_global(local_end))
		polygon.append(to_local(hit) if hit != null else local_end)


func _cast(from: Vector2, to: Vector2) -> Variant:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, Layers.VISION_BLOCKER, exclude)
	var r: Dictionary = space.intersect_ray(q)
	return r.get("position") if not r.is_empty() else null


## True if world point `p` is inside the cone and not occluded.
func can_see_point(p: Vector2) -> bool:
	var rel: Vector2 = p - global_position
	var dist: float = rel.length()
	if dist > range_px:
		return false
	if dist > 0.001:
		var look: Vector2 = Vector2.RIGHT.rotated(global_rotation)
		if absf(look.angle_to(rel)) > deg_to_rad(angle_deg) * 0.5:
			return false
	return _cast(global_position, p) == null


## Fraction of `points` visible (0..1).
func visible_fraction(points: PackedVector2Array) -> float:
	if points.is_empty():
		return 0.0
	var n: int = 0
	for p: Vector2 in points:
		if can_see_point(p):
			n += 1
	return float(n) / float(points.size())


func _draw() -> void:
	if polygon.size() < 3:
		return
	# rays all blocked right at the eye (pressed against a wall): nothing to fill
	if Geometry2D.triangulate_polygon(polygon).is_empty():
		return
	var col: Color = fill_color.lerp(alert_color, clampf(heat, 0.0, 1.0))
	draw_colored_polygon(polygon, col)
	draw_polyline(polygon + PackedVector2Array([Vector2.ZERO]), Color(col, col.a * 2.0), 1.0)
