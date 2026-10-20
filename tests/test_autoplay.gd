extends TestCase
## Full 3-minute runs played through real input actions.

const MAIN := preload("res://scenes/main.tscn")


func _run(pm_active: bool) -> Dictionary:
	var m: Node = MAIN.instantiate()
	add(m)
	await step_frames(2)
	var pm: Patroller = m.get_node("Level/World/ProductManager") as Patroller
	if not pm_active:
		pm.set_physics_process(false)
		pm.cone.set_physics_process(false)
	var bot := AutoplayBot.new()
	bot.player = m.get(&"player")
	bot.level = m.get(&"level")
	m.add_child(bot)
	GameState.start_run()
	var frames: int = 0
	while GameState.is_running() and frames < 60 * 200:
		await tree.physics_frame
		frames += 1
	var r: Dictionary = GameState.build_result()
	bot.queue_free()
	await step_frames(1)
	return r


func test_game_is_winnable_without_pm() -> void:
	var r: Dictionary = await _run(false)
	print("    autoplay (no PM): state=%s time=%.0fs training=%.0f%% grade=%s" % [GameState.State.keys()[r["state"]], r["time"], r["training"] * 100.0, r["grade"]])
	check_eq(r["state"], GameState.State.WON, "a competent player finishes in time")
	check(float(r["time"]) < GameState.time_limit * 0.85, "with slack to spare (%.0fs)" % r["time"])


func test_full_game_with_pm_ends_cleanly() -> void:
	var r: Dictionary = await _run(true)
	print("    autoplay (with PM): state=%s time=%.0fs training=%.0f%% detections=%d grade=%s" % [GameState.State.keys()[r["state"]], r["time"], r["training"] * 100.0, r["detections"], r["grade"]])
	check(r["state"] != GameState.State.RUNNING, "run reached an ending")
	check(float(r["training"]) > 0.3, "even a careless bot makes progress")
