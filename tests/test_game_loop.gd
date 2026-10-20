extends TestCase
## Whole-game integration: spotted flow, win flow, restart leaves nothing behind.

const MAIN := preload("res://scenes/main.tscn")


func _main() -> Node:
	var m: Node = MAIN.instantiate()
	add(m)
	return m


func test_spotted_sends_player_back() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var pm: Patroller = m.get_node("Level/World/ProductManager") as Patroller
	var p: Player = m.get(&"player")
	# stand right in front of the PM while it looks around at point 0
	p.global_position = pm.global_position + Vector2(0, 60)
	p.speed_kind = ActorBody.Speed.SPRINT
	var detected: Array[int] = [0]
	var cb: Callable = func(_by: Node) -> void: detected[0] += 1
	Events.player_detected.connect(cb)
	for i: int in 60 * 6:
		await tree.physics_frame
		if detected[0] > 0:
			break
		p.global_position = pm.global_position + Vector2.RIGHT.rotated(pm.cone.global_rotation) * 60.0
	Events.player_detected.disconnect(cb)
	check_eq(detected[0], 1, "player detected once")
	check_eq(GameState.detections, 1, "detection counted")
	check(p.global_position.distance_to((m.get(&"level") as GymLevel).player_spawn) < 1.0, "player sent back to spawn")
	check(pm.awareness < 0.01, "awareness reset after detection")
	check(GameState.is_running(), "first detection is not game over")


func test_three_detections_end_run() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var pm: Patroller = m.get_node("Level/World/ProductManager") as Patroller
	for i: int in 3:
		pm.spotted_player.emit()
	check_eq(GameState.state, GameState.State.CAUGHT, "caught after 3 detections")


func test_player_releases_station_when_caught() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var lvl: GymLevel = m.get(&"level")
	var st: Station = lvl.stations[0]
	check(p.try_use(st), "player on station")
	var pm: Patroller = m.get_node("Level/World/ProductManager") as Patroller
	pm.spotted_player.emit()
	await step_frames(1)
	check(not st.is_user(p), "station released on detection")
	check(p.minigame == null, "minigame closed")


func test_hidden_behind_pillar_stays_safe() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var pm: Patroller = m.get_node("Level/World/ProductManager") as Patroller
	var p: Player = m.get(&"player")
	# PM at a fixed spot looking right at the pillar; player right behind it
	pm.set_physics_process(false)
	pm.global_position = Vector2(200, 352)
	pm.cone.rotation = 0.0
	p.global_position = Vector2(370, 356)
	for i: int in 30:
		await tree.physics_frame
		pm.cone.rebuild()
		pm._update_awareness(1.0 / 60.0)
	check(pm.awareness < 0.01, "pillar hides the player (awareness %.2f)" % pm.awareness)
	p.global_position = Vector2(300, 300)
	for i: int in 30:
		await tree.physics_frame
		pm._update_awareness(1.0 / 60.0)
	check(pm.awareness > 0.05, "in the open the player is seen (awareness %.2f)" % pm.awareness)


func test_restart_leaves_no_residue() -> void:
	var baseline: int = -1
	for i: int in 20:
		var m: Node = _main()
		await step_frames(3)
		GameState.start_run()
		var p: Player = m.get(&"player")
		var lvl: GymLevel = m.get(&"level")
		p.try_use(lvl.stations[i % lvl.stations.size()])
		await step_frames(3)
		m.free()
		GameState.reset()
		Station.clear_all_claims()
		await step_frames(2)
		var count: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		if i == 2:
			baseline = count
		elif i > 2:
			check(count <= baseline + 50, "object count stable across restarts (%d vs %d)" % [count, baseline])
	check_eq(GameState.training_points, 0, "no score residue")
