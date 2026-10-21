extends TestCase
## Minigame rules: good inputs count, bad inputs miss, no reps after finish.


func _d(kind: StringName, reps: int = 3) -> StationData:
	var d := StationData.new()
	d.minigame = kind
	d.reps_per_set = reps
	return d


func test_hold_release_zone() -> void:
	var g: HoldReleaseGame = Minigame.create(_d(&"hold_release")) as HoldReleaseGame
	g.handle_input(&"interact", true)
	g.tick(0.1)
	g.handle_input(&"interact", false)
	check_eq(g.reps, 0, "early release is not a rep")
	check_eq(g.misses, 1, "early release is a miss")
	g.tick(1.0)
	g.handle_input(&"interact", true)
	for i: int in 45:
		g.tick(1.0 / 60.0)
	g.handle_input(&"interact", false)
	check_eq(g.reps, 1, "release in zone (charge %.2f) counts" % g.charge)


func test_hold_overcharge_misses() -> void:
	var g: HoldReleaseGame = Minigame.create(_d(&"hold_release")) as HoldReleaseGame
	g.handle_input(&"interact", true)
	for i: int in 120:
		g.tick(1.0 / 60.0)
	check_eq(g.misses, 1, "holding too long misses")
	check(not g.holding, "auto-dropped")


func test_alternate_requires_alternation() -> void:
	var g: AlternateGame = Minigame.create(_d(&"alternate")) as AlternateGame
	g.handle_input(&"move_left", true)
	g.handle_input(&"move_left", true)
	check_eq(g.reps, 0, "same side twice is not a rep")
	g.handle_input(&"move_left", true)
	g.tick(0.15)   # a human gap between hands (simultaneous presses are a miss)
	g.handle_input(&"move_right", true)
	check_eq(g.reps, 1, "left then right is a rep")
	g.handle_input(&"move_up", true)
	check_eq(g.misses, 1, "other keys are ignored (only earlier mistake counted)")


func test_rhythm_needs_taps() -> void:
	var g: RhythmGame = Minigame.create(_d(&"rhythm")) as RhythmGame
	for i: int in 600:
		g.tick(1.0 / 60.0)
	check_eq(g.reps, 0, "standing still earns nothing")
	MinigameBot.play(g, 60.0)
	check(g.is_finished(), "steady tapping finishes")


func test_timing_hit_and_miss() -> void:
	var g: TimingGame = Minigame.create(_d(&"timing")) as TimingGame
	g.phase = 0.1
	g.handle_input(&"interact", true)
	check_eq(g.misses, 1, "early punch misses")
	g.tick(1.0)
	g.phase = 0.85
	g.handle_input(&"interact", true)
	check_eq(g.reps, 1, "punch in zone hits")


func test_no_reps_after_finish() -> void:
	var g: Minigame = Minigame.create(_d(&"timing", 1))
	MinigameBot.play(g, 30.0)
	check(g.is_finished(), "finished")
	(g as TimingGame).phase = 0.85
	g.handle_input(&"interact", true)
	check_eq(g.reps, 1, "reps capped at target")


func test_timing_mash_cannot_chain_hits() -> void:
	var g: TimingGame = Minigame.create(_d(&"timing", 5)) as TimingGame
	g.phase = 0.85
	g.handle_input(&"interact", true)
	check_eq(g.reps, 1, "first hit counts")
	for i: int in 12:
		g.tick(1.0 / 60.0)
		if i % 3 == 0:
			g.handle_input(&"interact", true)
	check_eq(g.reps, 1, "mashing right after a hit doesn't chain more reps")


func test_alternate_both_keys_at_once_is_a_miss() -> void:
	var g: AlternateGame = Minigame.create(_d(&"alternate", 6)) as AlternateGame
	for i: int in 6:
		g.handle_input(&"move_left", true)
		g.handle_input(&"move_right", true)
		g.tick(0.2)
	check_eq(g.reps, 0, "pressing both sides together never scores")
	g.handle_input(&"move_left", true)
	g.tick(0.15)
	g.handle_input(&"move_right", true)
	check_eq(g.reps, 1, "a real alternation still scores")


func test_hold_press_during_lockout_is_kept() -> void:
	var g: HoldReleaseGame = Minigame.create(_d(&"hold_release")) as HoldReleaseGame
	g.handle_input(&"interact", true)
	for i: int in 45:
		g.tick(1.0 / 60.0)
	g.handle_input(&"interact", false)
	check_eq(g.reps, 1, "first rep")
	g.handle_input(&"interact", true)   # pressed again during the lockout, and held
	for i: int in 30:
		g.tick(1.0 / 60.0)
	check(g.holding, "the held press starts charging once the lockout ends")
