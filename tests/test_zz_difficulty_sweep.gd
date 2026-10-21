extends TestCase
## Info only: how a careless bot fares on each difficulty (both levels).

const MAIN := preload("res://scenes/main.tscn")


func _run(level_id: StringName, diff: int) -> Dictionary:
	GameState.selected_level = level_id
	GameState.difficulty = diff
	var m: Node = MAIN.instantiate()
	add(m)
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
	var r: Dictionary = GameState.build_result()
	m.free()
	Station.clear_all_claims()
	GameState.reset()
	return r


func test_sweep() -> void:
	for lv: StringName in [&"gym", &"office"]:
		for d: int in 3:
			var r: Dictionary = await _run(lv, d)
			print("    autoplay sweep %s %s: state=%s time=%.0fs progress=%.0f%% detections=%d" % [lv, Difficulty.name_of(d), GameState.State.keys()[r["state"]], r["time"], float(r["training"]) * 100.0, r["detections"]])
