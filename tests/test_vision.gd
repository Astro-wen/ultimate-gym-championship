extends TestCase
## View cone geometry and occlusion, awareness rules.


func _wall(rect: Rect2, layer: int) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = layer
	b.position = rect.get_center()
	var s := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	s.shape = r
	b.add_child(s)
	add(b)
	return b


func _cone() -> VisionCone:
	var c := VisionCone.new()
	c.angle_deg = 70.0
	c.range_px = 300.0
	c.position = Vector2(1000, 1000)
	add(c)
	return c


func test_wall_blocks_sight() -> void:
	var c: VisionCone = _cone()
	_wall(Rect2(1100, 980, 20, 40), Layers.WORLD | Layers.VISION_BLOCKER)
	await step_frames(2)
	check(not c.can_see_point(Vector2(1200, 1000)), "point behind wall hidden")
	check(c.can_see_point(Vector2(1050, 1000)), "point before wall visible")


func test_non_blocker_does_not_block() -> void:
	var c: VisionCone = _cone()
	_wall(Rect2(1100, 980, 20, 40), Layers.WORLD)   # e.g. low equipment / glass
	await step_frames(2)
	check(c.can_see_point(Vector2(1200, 1000)), "world-only body doesn't block sight")


func test_cone_edges_and_range() -> void:
	var c: VisionCone = _cone()
	await step_frames(1)
	var inside: Vector2 = c.global_position + Vector2.RIGHT.rotated(deg_to_rad(34.0)) * 200.0
	var outside: Vector2 = c.global_position + Vector2.RIGHT.rotated(deg_to_rad(36.0)) * 200.0
	check(c.can_see_point(inside), "just inside half-angle visible")
	check(not c.can_see_point(outside), "just outside half-angle hidden")
	check(not c.can_see_point(c.global_position + Vector2(301, 0)), "beyond range hidden")
	c.rotation = PI
	check(c.can_see_point(c.global_position + Vector2(-200, 0)), "rotation turns the cone")


func test_sample_points_partial_visibility() -> void:
	var c: VisionCone = _cone()
	# wall hides the far half of a body standing at x=1200
	_wall(Rect2(1100, 940, 20, 60), Layers.VISION_BLOCKER)
	await step_frames(2)
	var body := Node2D.new()
	body.position = Vector2(1200, 1008)
	add(body)
	var pts: PackedVector2Array = Patroller.sample_points(body)
	var f: float = c.visible_fraction(pts)
	check(f > 0.0 and f < 1.0, "half-hidden body is partially visible (%.2f)" % f)


func test_awareness_rates() -> void:
	var level := GymLevel.new()
	add(level)
	var pm := Patroller.new()
	pm.level = level
	pm.points = level.patrol_points
	level.world.add_child(pm)
	var walk: float = pm.rise_rate(100.0, ActorBody.Speed.WALK, 1.0, false, false)
	var sprint: float = pm.rise_rate(100.0, ActorBody.Speed.SPRINT, 1.0, false, false)
	var still: float = pm.rise_rate(100.0, ActorBody.Speed.STILL, 1.0, false, false)
	check(is_equal_approx(sprint / walk, 2.5), "sprint is 2.5x walk")
	check(still < walk, "standing still is safest")
	check(is_equal_approx(pm.rise_rate(100.0, ActorBody.Speed.WALK, 1.0, true, false), walk * 0.5), "cover halves the rise")
	check(pm.rise_rate(250.0, ActorBody.Speed.WALK, 1.0, false, false) < walk, "far is slower than near")
	check(pm.rise_rate(100.0, ActorBody.Speed.WALK, 1.0, false, true) < walk, "stealth buff slows the rise")


func test_global_alert_is_max() -> void:
	var a := Patroller.new()
	var b := Patroller.new()
	add(a)
	add(b)
	a.awareness = 0.3
	b.awareness = 0.6
	var d := StealthDirector.new()
	add(d)
	check(is_equal_approx(d.global_alert(), 0.6), "global alert is the max, not the sum")
