extends TestCase
## Every data/stations/*.tres must load, build a station and a minigame,
## and be completable — proof that new equipment needs no code.


func _all_data() -> Array[StationData]:
	var out: Array[StationData] = []
	for f: String in DirAccess.get_files_at("res://data/stations"):
		if f.ends_with(".tres"):
			var d: StationData = load("res://data/stations/" + f) as StationData
			check(d != null, "%s loads as StationData" % f)
			if d != null:
				out.append(d)
	return out


func test_all_station_data_valid() -> void:
	var all: Array[StationData] = _all_data()
	check(all.size() >= 4, "at least 4 stations defined")
	var ids: Dictionary = {}
	for d: StationData in all:
		check(d.id != &"", "id set")
		check(not ids.has(d.id), "id unique: %s" % d.id)
		ids[d.id] = true
		check(not d.display_name.is_empty(), "%s display name" % d.id)
		check(d.capacity >= 1, "%s capacity" % d.id)
		check(d.anchor_offsets.size() >= d.capacity, "%s anchors per slot" % d.id)
		check(d.reps_per_set >= 1, "%s reps" % d.id)
		check(d.use_time > 0.0, "%s use_time" % d.id)


func test_each_station_completes_a_set() -> void:
	for d: StationData in _all_data():
		GameState.reset()
		var s := Station.new()
		s.data = d
		add(s)
		var p := Node2D.new()
		p.add_to_group(&"player")
		add(p)
		check(s.try_claim(p), "%s claim" % d.id)
		var g: Minigame = Minigame.create(d)
		check(g != null, "%s minigame" % d.id)
		MinigameBot.play(g, 120.0)
		check(g.is_finished(), "%s minigame completable by a bot (reps %d/%d)" % [d.id, g.reps, g.target_reps])
		check(s.finish_use(p), "%s finish" % d.id)
		check_eq(GameState.training_points, d.stat_gain, "%s scored" % d.id)
		s.free()
		p.free()
