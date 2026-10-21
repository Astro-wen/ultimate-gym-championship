extends TestCase
## Office level: task order, reachability, watchers, and a full bot run.

const MAIN := preload("res://scenes/main.tscn")


func _office() -> Node:
	GameState.selected_level = &"office"
	var m: Node = MAIN.instantiate()
	add(m)
	return m


func test_office_builds_and_is_reachable() -> void:
	var m: Node = _office()
	await step_frames(2)
	var lvl: Level = m.get(&"level")
	check(lvl is OfficeLevel, "office level loaded")
	check_eq(lvl.stations.size(), 4, "four tasks")
	check_eq(GameState.training_goal, 4, "goal = four tasks")
	check(lvl.is_walkable(lvl.player_spawn), "spawn walkable")
	for st: Station in lvl.stations:
		check(lvl.is_walkable(st.interact_point()), "%s standing spot walkable" % st.name)
		check(lvl.find_path(lvl.player_spawn, st.interact_point()).size() > 0, "%s reachable" % st.name)
	for p: Vector2 in lvl.patrol_points:
		check(lvl.is_walkable(p), "patrol point %s walkable" % p)
	check(m.get_node_or_null("Level/World/Receptionist") != null, "receptionist watcher exists")
	check(m.get_node_or_null("Level/World/GymGoer0") == null, "no gym regulars in the office")


func test_tasks_unlock_in_order() -> void:
	var m: Node = _office()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var lvl: Level = m.get(&"level")
	var desk: Station = lvl.station_by_id(&"desk_work")
	var printer: Station = lvl.station_by_id(&"printer")
	var sign: Station = lvl.station_by_id(&"signout")
	var lift: Station = lvl.station_by_id(&"elevator")
	check(printer.is_locked_for(p) and sign.is_locked_for(p) and lift.is_locked_for(p), "later tasks locked at start")
	check(not p.try_use(lift), "can't take the elevator first")
	check(p.try_use(desk), "desk work available")
	desk.finish_use(p)
	check(not printer.is_locked_for(p), "printer unlocked by the desk work")
	check(sign.is_locked_for(p), "sign-out still locked")
	await step_frames(2)
	check(p.try_use(printer), "printing")
	printer.finish_use(p)
	await step_frames(2)
	check(p.try_use(sign), "signing")
	sign.finish_use(p)
	await step_frames(2)
	check(p.try_use(lift), "elevator")
	lift.finish_use(p)
	GameState.tick(0.1)
	check_eq(GameState.state, GameState.State.WON, "four tasks = going home early")


func test_receptionist_looks_away_sometimes() -> void:
	var m: Node = _office()
	await step_frames(2)
	GameState.start_run()
	var r: Patroller = m.get_node("Level/World/Receptionist") as Patroller
	var lvl: Level = m.get(&"level")
	var sign_spot: Vector2 = lvl.station_by_id(&"signout").anchor_for(null)
	var seen_frames: int = 0
	var unseen_frames: int = 0
	for i: int in 60 * 10:
		await tree.physics_frame
		if r.cone.can_see_point(sign_spot + Vector2(0, -8)):
			seen_frames += 1
		else:
			unseen_frames += 1
	check(seen_frames > 30, "she does watch the sign-out sheet (%d frames)" % seen_frames)
	check(unseen_frames > 120, "and there are windows to sign unseen (%d frames)" % unseen_frames)


func test_office_winnable_by_bot_without_watchers() -> void:
	var m: Node = _office()
	await step_frames(2)
	for n: Node in tree.get_nodes_in_group(&"patrollers"):
		n.set_physics_process(false)
		(n as Patroller).cone.set_physics_process(false)
	var bot := AutoplayBot.new()
	bot.player = m.get(&"player")
	bot.level = m.get(&"level")
	m.add_child(bot)
	GameState.start_run()
	var frames: int = 0
	while GameState.is_running() and frames < 60 * 200:
		await tree.physics_frame
		frames += 1
	print("    autoplay (office, no watchers): state=%s time=%.0fs tasks=%d/4" % [GameState.State.keys()[GameState.state], GameState.elapsed, GameState.training_points])
	check_eq(GameState.state, GameState.State.WON, "all four tasks doable in time")
	bot.queue_free()


func test_office_full_run_ends_cleanly() -> void:
	var m: Node = _office()
	await step_frames(2)
	var bot := AutoplayBot.new()
	bot.player = m.get(&"player")
	bot.level = m.get(&"level")
	m.add_child(bot)
	GameState.start_run()
	var frames: int = 0
	while GameState.is_running() and frames < 60 * 200:
		await tree.physics_frame
		frames += 1
	print("    autoplay (office, careless): state=%s time=%.0fs tasks=%d/4 detections=%d" % [GameState.State.keys()[GameState.state], GameState.elapsed, GameState.training_points, GameState.detections])
	check(GameState.state != GameState.State.RUNNING, "run reached an ending")
	bot.queue_free()


func test_finished_tasks_cant_be_repeated() -> void:
	var m: Node = _office()
	await step_frames(2)
	GameState.start_run()
	var p: Player = m.get(&"player")
	var desk: Station = (m.get(&"level") as Level).station_by_id(&"desk_work")
	check(p.try_use(desk), "first time at the desk")
	desk.finish_use(p)
	await step_frames(2)
	check(desk.is_locked_for(p), "desk task locked once done")
	check(not p.try_use(desk), "can't farm the same task")
	check_eq(GameState.training_points, 1, "counted once")
