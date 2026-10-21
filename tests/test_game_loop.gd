extends TestCase
## Whole-game integration: spotted flow, win flow, restart leaves nothing behind.

const MAIN := preload("res://scenes/main.tscn")


func _main(level_id: StringName = &"gym") -> Node:
	GameState.selected_level = level_id
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
	check(p.global_position.distance_to((m.get(&"level") as Level).player_spawn) < 1.0, "player sent back to spawn")
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
	var lvl: Level = m.get(&"level")
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
		var lvl: Level = m.get(&"level")
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


func test_time_penalty_never_passes_limit() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	GameState.elapsed = GameState.time_limit - 5.0
	var pm: Patroller = m.get_node("Level/World/ProductManager") as Patroller
	pm.spotted_player.emit()
	check(GameState.elapsed <= GameState.time_limit, "elapsed clamped (%.1f)" % GameState.elapsed)


func test_no_instant_remount_after_a_set() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var st: Station = (m.get(&"level") as Level).stations[2]
	check(p.try_use(st), "on the treadmill")
	st.finish_use(p)
	await step_frames(2)
	check(p._find_focus_station() != st, "just-left machine isn't offered again right away")
	for i: int in 60:
		await tree.physics_frame
	p.global_position = st.exit_point()
	check(p._find_focus_station() == st, "offered again after the short delay")


func test_respawn_spot_is_safe_for_a_while() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var pm: Patroller = m.get_node("Level/World/ProductManager") as Patroller
	var p: Player = m.get(&"player")
	var lvl: Level = m.get(&"level")
	pm.spotted_player.emit()
	# PM stands right next to the spawn staring at it
	pm.set_physics_process(false)
	pm.global_position = lvl.player_spawn + Vector2(0, -120)
	pm.cone.rotation = PI * 0.5
	pm.grace = 0.0
	for i: int in 60:
		await tree.physics_frame
		pm.cone.rebuild()
		pm._update_awareness(1.0 / 60.0)
	check(pm.awareness < 0.01, "standing at the respawn spot is safe right after a catch (%.2f)" % pm.awareness)
	check(p.global_position.distance_to(lvl.player_spawn) < 1.0, "player at spawn")


func test_water_cup_reserves_machine() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var lvl: Level = m.get(&"level")
	var bench: Station = lvl.stations[0]
	p.snap_to(bench.exit_point())
	p.facing = Vector2.UP
	check(p.cup_drop_target() == bench, "dropping here would reserve the bench")
	p.toggle_cup()
	check(not p.cup.carried, "cup on the floor")
	check(bench.reserved_by == p, "bench reserved by the player")
	# a regular can't take it
	var g: GymGoer = lvl.world.get_node(^"GymGoer0") as GymGoer
	check(not g.begin_use(bench), "regular can't claim the reserved bench")
	check(p.interact(bench), "player can still use it")
	check(p.station == bench, "player on the bench")
	p.end_use()
	await step_frames(1)
	p.snap_to(p.cup.global_position + Vector2(0, 10))
	check(p.can_pick_up_cup(), "cup in reach")
	p.toggle_cup()
	check(p.cup.carried and bench.reserved_by == null, "picking it up frees the bench")


func test_player_queues_then_gets_turn() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var lvl: Level = m.get(&"level")
	var st: Station = lvl.stations[1]
	var g: GymGoer = lvl.world.get_node(^"GymGoer0") as GymGoer
	check(g.begin_use(st), "regular on the dumbbells")
	p.snap_to(st.exit_point())
	check(p.interact(st), "E on a busy machine joins the line")
	check(p.queued == st and st.queue_position(p) == 0, "player first in line")
	check(p.station == null, "not on it yet")
	st.finish_use(g)
	await step_frames(1)
	check(st.is_turn_of(p), "player's turn once it frees up")
	check(not st.is_turn_of(g), "the regular can't cut in")
	check(p.interact(st), "E takes the turn")
	check(p.station == st and p.queued == null, "player on the machine, out of the line")


func test_shove_knocks_regular_back() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var lvl: Level = m.get(&"level")
	var st: Station = lvl.stations[4]
	var g: GymGoer = lvl.world.get_node(^"GymGoer0") as GymGoer
	g.begin_use(st)
	st.tick(5.0)   # past push protection
	p.snap_to(st.exit_point())
	p.interact(st)
	var shoves: Array[int] = [0]
	var cb: Callable = func(_a: Node, _b: Node, _c: Vector2) -> void: shoves[0] += 1
	Events.shoved.connect(cb)
	check(p.interact(st), "first in line can shove")
	Events.shoved.disconnect(cb)
	check_eq(shoves[0], 1, "shove event fired")
	check(p.station == st, "player took the bag")
	check(g.station == null and g.is_angry(), "regular knocked off and angry")
	check(g.global_position.distance_to(st.exit_point()) > 10.0, "regular knocked back past the exit point")
	await step_frames(30)
	check(is_equal_approx(Engine.time_scale, 1.0), "hit-stop released")


func test_every_standing_spot_is_in_reach() -> void:
	var m: Node = _main()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var lvl: Level = m.get(&"level")
	for st: Station in lvl.stations:
		p.snap_to(st.interact_point())
		check(p._find_focus_station() == st, "E reaches %s from its standing spot" % st.name)
