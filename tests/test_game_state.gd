extends TestCase
## reset() restores a fresh state; run end conditions fire once.


func _snapshot() -> Dictionary:
	return {
		"state": GameState.state, "elapsed": GameState.elapsed, "detections": GameState.detections,
		"points": GameState.training_points, "stats": GameState.stats, "sets": GameState.sets_done,
		"buffs": GameState.active_buffs,
	}


func test_reset_equals_fresh() -> void:
	var fresh: Dictionary = _snapshot()
	GameState.start_run()
	GameState.tick(5.0)
	GameState.detections = 2
	GameState.record_set(&"bench_press", &"strength", 4)
	GameState.apply_buff(&"stealthy", 8.0)
	GameState.reset()
	check_eq(_snapshot(), fresh, "reset matches fresh state")


func test_win_when_goal_reached() -> void:
	GameState.start_run()
	var results: Array[Dictionary] = []
	var cb: Callable = func(r: Dictionary) -> void: results.append(r)
	Events.run_finished.connect(cb)
	GameState.record_set(&"x", &"strength", GameState.training_goal)
	GameState.tick(0.1)
	GameState.tick(0.1)
	Events.run_finished.disconnect(cb)
	check_eq(GameState.state, GameState.State.WON, "won")
	check_eq(results.size(), 1, "run_finished emitted once")


func test_timeout() -> void:
	GameState.start_run()
	GameState.tick(GameState.time_limit + 1.0)
	check_eq(GameState.state, GameState.State.TIMEOUT, "timed out")


func test_buff_expires() -> void:
	GameState.start_run()
	GameState.apply_buff(&"stealthy", 1.0)
	check(GameState.has_buff(&"stealthy"), "buff active")
	GameState.tick(1.5)
	check(not GameState.has_buff(&"stealthy"), "buff expired")
