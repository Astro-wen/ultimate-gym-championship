extends TestCase
## The PM: unpredictable route, following when suspicious (never too
## closely), giving up, and difficulty presets.

const MAIN := preload("res://scenes/main.tscn")


func _gym(diff: int = Difficulty.Level.NORMAL) -> Node:
	GameState.selected_level = &"gym"
	GameState.difficulty = diff
	var m: Node = MAIN.instantiate()
	add(m)
	return m


func _pm(m: Node) -> Patroller:
	return m.get_node("Level/World/ProductManager") as Patroller


func test_chase_is_always_slower_than_walking() -> void:
	for d: int in Difficulty.PARAMS.size():
		check(float(Difficulty.params(d)["chase_speed"]) < 70.0, "%s: chase slower than the player's walk" % Difficulty.name_of(d))


func test_difficulty_is_applied() -> void:
	var easy: Node = _gym(Difficulty.Level.EASY)
	await step_frames(2)
	var pm_e: Patroller = _pm(easy)
	var e_rise: float = pm_e.base_rise
	var e_speed: float = pm_e.chase_speed
	check_eq(GameState.max_strikes, 4, "easy allows 4 catches")
	easy.free()
	Station.clear_all_claims()
	var hard: Node = _gym(Difficulty.Level.HARD)
	await step_frames(2)
	var pm_h: Patroller = _pm(hard)
	check(pm_h.base_rise > e_rise, "hard notices faster")
	check(pm_h.chase_speed > e_speed, "hard follows faster")
	check(pm_h.can_chase, "the PM can follow")
	check_eq(GameState.max_strikes, 2, "hard allows 2 catches")
	var sitter_count: int = 0
	for n: Node in tree.get_nodes_in_group(&"patrollers"):
		if not (n as Patroller).can_chase:
			sitter_count += 1
	check_eq(sitter_count, 0, "gym has only the PM")


func test_pm_follows_but_keeps_distance() -> void:
	var m: Node = _gym()
	await step_frames(2)
	GameState.start_run()
	var pm: Patroller = _pm(m)
	var p: Player = m.get(&"player")
	# open floor: PM looking right at the player 150px away, already suspicious
	pm.global_position = Vector2(480, 300)
	pm.mode = Patroller.Mode.LOOK
	pm._look_angle = 0.0
	pm._base_angle = 0.0
	pm._timer = 99.0
	pm._wait_now = 99.0   # sweep phase 0: look straight along _base_angle
	p.snap_to(Vector2(630, 300))
	pm.awareness = 0.5
	pm.base_rise = 0.0   # isolate movement from detection
	var closest: float = INF
	var top_speed: float = 0.0
	for i: int in 60 * 4:
		await tree.physics_frame
		closest = minf(closest, pm.global_position.distance_to(p.global_position))
		top_speed = maxf(top_speed, pm.velocity.length())
	check(pm.mode == Patroller.Mode.FOLLOW, "PM follows a suspicious player (mode %d)" % pm.mode)
	check(pm.global_position.x > 500.0, "she walked toward the player (%.0f)" % pm.global_position.x)
	check(closest >= pm.keep_distance - 12.0, "but not too close (%.0f px)" % closest)
	check(top_speed <= pm.chase_speed * pm.difficulty + 1.0, "at chase speed, not faster (%.0f)" % top_speed)


func test_pm_gives_up_when_she_loses_you() -> void:
	var m: Node = _gym()
	await step_frames(2)
	GameState.start_run()
	var pm: Patroller = _pm(m)
	var p: Player = m.get(&"player")
	pm.global_position = Vector2(480, 300)
	pm._look_angle = 0.0
	pm.mode = Patroller.Mode.LOOK
	pm._base_angle = 0.0
	pm._timer = 99.0
	pm._wait_now = 99.0   # sweep phase 0: look straight along _base_angle
	p.snap_to(Vector2(620, 300))
	pm.awareness = 0.5
	pm.base_rise = 0.0
	await step_frames(10)
	check(pm.mode == Patroller.Mode.FOLLOW, "following")
	# vanish: she can no longer see the player at all
	p.snap_to(Vector2(90, 470))
	pm.grace = 999.0
	var gave_up: bool = false
	for i: int in 60 * 12:
		await tree.physics_frame
		if pm.mode == Patroller.Mode.RETURN or pm.mode == Patroller.Mode.WALK or pm.mode == Patroller.Mode.LOOK:
			gave_up = true
			break
	check(gave_up, "she searched, gave up and went back to her route (mode %d)" % pm.mode)


func test_route_is_not_a_fixed_loop() -> void:
	var m: Node = _gym(Difficulty.Level.HARD)
	await step_frames(2)
	GameState.start_run()
	var pm: Patroller = _pm(m)
	pm.set_physics_process(false)
	var seq: Array[int] = []
	for i: int in 40:
		pm._next_point()
		seq.append(pm._point_i)
	var non_sequential: int = 0
	var bounce: int = 0
	for i: int in range(1, seq.size()):
		if seq[i] != (seq[i - 1] + 1) % pm.points.size():
			non_sequential += 1
		if i >= 2 and seq[i] == seq[i - 2]:
			bounce += 1
	check(non_sequential > 5, "route varies (%d random hops in 40)" % non_sequential)
	check_eq(bounce, 0, "never straight back to where she just came from")
