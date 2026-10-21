extends TestCase
## 3 GymGoers in the real gym for 5 simulated minutes (run with --fixed-fps 60):
## no deadlock, nobody waits forever, sets keep getting done, stations end free.


func test_gym_goers_soak_5_minutes() -> void:
	# goers only act during a run; make this one long enough for the soak
	var saved_limit: float = GameState.time_limit
	GameState.time_limit = 100000.0
	GameState.start_run()
	var level := GymLevel.new()
	add(level)
	var goers: Array[GymGoer] = []
	for i: int in 3:
		var g := GymGoer.new()
		g.level = level
		g.rng.seed = 77 + i
		g.position = level.npc_spawns[i]
		level.world.add_child(g)
		goers.append(g)
	var sets: Array[int] = [0]
	var cb: Callable = func(_st: Node, _who: Node) -> void: sets[0] += 1
	Events.station_use_finished.connect(cb)
	var same_mode_t: Array[float] = [0.0, 0.0, 0.0]
	var last_mode: Array[int] = [-1, -1, -1]
	var worst: float = 0.0
	var dt: float = 1.0 / 60.0
	for frame: int in 60 * 300:
		await tree.physics_frame
		for i: int in goers.size():
			var g: GymGoer = goers[i]
			if g.mode != last_mode[i]:
				last_mode[i] = g.mode
				same_mode_t[i] = 0.0
			else:
				same_mode_t[i] += dt
				worst = maxf(worst, same_mode_t[i])
			if not check(g.station == null or g.station.is_user(g), "frame %d: goer %d thinks it holds a station it doesn't" % [frame, i]):
				break
			if not check(level.is_walkable(g.global_position) or g.station != null, "frame %d: goer %d inside a wall at %s" % [frame, i, g.global_position]):
				break
		if not failures.is_empty():
			break
		# nobody shares a stationary spot
		for a: int in goers.size():
			for b: int in range(a + 1, goers.size()):
				var ga: GymGoer = goers[a]
				var gb: GymGoer = goers[b]
				if ga.mode == GymGoer.Mode.USE and gb.mode == GymGoer.Mode.USE:
					check(ga.station != gb.station or ga.station.capacity() > 1, "two goers on one single-slot station")
	Events.station_use_finished.disconnect(cb)
	GameState.time_limit = saved_limit
	check(worst < 25.0, "no goer stuck in one mode for 25s (worst %.1fs)" % worst)
	check(sets[0] >= 15, "goers keep training (%d sets in 5 min)" % sets[0])
	for g: GymGoer in goers:
		g.free()
	for st: Station in level.stations:
		check(st.users().is_empty(), "%s free after goers removed" % st.name)


func test_every_station_reachable() -> void:
	var level := GymLevel.new()
	add(level)
	for st: Station in level.stations:
		var path: PackedVector2Array = level.find_path(level.player_spawn, st.interact_point())
		check(path.size() > 0, "%s reachable from spawn" % st.name)
		check(level.is_walkable(st.interact_point()), "%s interact point walkable" % st.name)
	for p: Vector2 in level.patrol_points:
		check(level.is_walkable(p), "patrol point %s walkable" % p)
	for p: Vector2 in level.npc_spawns:
		check(level.is_walkable(p), "npc spawn %s walkable" % p)
	check(level.is_walkable(level.player_spawn), "player spawn walkable")


func test_goers_idle_outside_a_run() -> void:
	var level := GymLevel.new()
	add(level)
	var g := GymGoer.new()
	g.level = level
	g.position = level.npc_spawns[0]
	level.world.add_child(g)
	for i: int in 120:
		await tree.physics_frame
	check(g.global_position.distance_to(level.npc_spawns[0]) < 0.5, "goer doesn't wander before the run starts")
	for st: Station in level.stations:
		check(st.is_free(), "no machine claimed before the run starts")
