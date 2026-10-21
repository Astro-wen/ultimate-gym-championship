extends TestCase
## Occupancy rules: atomic claim, one station per actor, release on every
## exit path, push protection, single reward per set.


func _data(cap: int = 1) -> StationData:
	var d := StationData.new()
	d.id = &"test"
	d.capacity = cap
	d.stat = &"strength"
	d.stat_gain = 2
	d.anchor_offsets = [Vector2.ZERO, Vector2(10, 0)]
	return d


func _station(cap: int = 1) -> Station:
	var s := Station.new()
	s.data = _data(cap)
	add(s)
	return s


func _actor(is_player: bool = false) -> Node2D:
	var n := Node2D.new()
	if is_player:
		n.add_to_group(&"player")
	add(n)
	return n


func test_claim_is_exclusive() -> void:
	var s: Station = _station()
	var a: Node2D = _actor()
	var b: Node2D = _actor()
	check(s.try_claim(a), "first claim succeeds")
	check(not s.try_claim(b), "second claim on full station fails")
	check(not s.try_claim(a), "re-claim by same actor fails")
	check_eq(s.users().size(), 1, "one user")


func test_one_station_per_actor() -> void:
	var s1: Station = _station()
	var s2: Station = _station()
	var a: Node2D = _actor()
	check(s1.try_claim(a), "claim s1")
	check(not s2.try_claim(a), "cannot also claim s2")
	s1.release(a)
	check(s2.try_claim(a), "can claim s2 after releasing s1")


func test_actor_freed_releases() -> void:
	var s: Station = _station()
	var a: Node2D = _actor()
	s.try_claim(a)
	a.free()
	check(s.is_free(), "station free after its user is freed")
	check(s.users().is_empty(), "no dangling users")


func test_station_freed_releases_claims() -> void:
	var s: Station = _station()
	var a: Node2D = _actor()
	s.try_claim(a)
	s.free()
	check(Station.station_of(a) == null, "actor holds nothing after station freed")
	var s2: Station = _station()
	check(s2.try_claim(a), "actor can claim another station")


func test_push_protection() -> void:
	var s: Station = _station()
	s.push_protect = 2.0
	var a: Node2D = _actor()
	var b: Node2D = _actor()
	s.try_claim(a)
	check(not s.push(b, a), "cannot push during protection window")
	s.tick(2.5)
	check(s.push(b, a), "push allowed after protection window")
	check(s.is_user(b) and not s.is_user(a), "slot swapped")
	check(not s.push(a, b), "new user is protected again")


func test_reward_once_per_set() -> void:
	var s: Station = _station()
	var p: Node2D = _actor(true)
	s.try_claim(p)
	check(s.finish_use(p), "finish succeeds")
	check(not s.finish_use(p), "second finish without claim fails")
	check_eq(GameState.training_points, 2, "reward applied exactly once")
	check(s.is_free(), "finish releases")


func test_npc_gets_no_reward() -> void:
	var s: Station = _station()
	var n: Node2D = _actor(false)
	s.try_claim(n)
	s.finish_use(n)
	check_eq(GameState.training_points, 0, "NPC sets don't score")


func test_queue_order() -> void:
	var s: Station = _station()
	var a: Node2D = _actor()
	var b: Node2D = _actor()
	var c: Node2D = _actor()
	s.try_claim(a)
	s.join_queue(b)
	s.join_queue(c)
	check(not s.is_turn_of(b), "not b's turn while occupied")
	s.release(a)
	check(s.is_turn_of(b), "b is first in line")
	check(not s.is_turn_of(c), "c waits behind b")
	b.free()
	check(s.is_turn_of(c), "freed actor drops out of the queue")


func test_random_ops_invariants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var stations: Array[Station] = []
	for i: int in 4:
		var st: Station = _station(1 + i % 2)
		st.push_protect = 0.5
		stations.append(st)
	var actors: Array[Node2D] = []
	for i: int in 6:
		actors.append(_actor(i == 0))
	var expected_points: int = 0
	for step: int in 1000:
		var st: Station = stations[rng.randi() % stations.size()]
		var a: Node2D = actors[rng.randi() % actors.size()]
		match rng.randi() % 6:
			0, 1:
				st.try_claim(a)
			2:
				st.release(a)
			3:
				var users: Array[Node] = st.users()
				if not users.is_empty():
					st.push(a, users[0])
			4:
				if a.is_in_group(&"player") and st.is_user(a):
					expected_points += 2
				st.finish_use(a)
			5:
				if rng.randf() < 0.15 and not a.is_in_group(&"player"):
					var idx: int = actors.find(a)
					a.free()
					actors[idx] = _actor(false)
		for s2: Station in stations:
			s2.tick(0.1)
		if not _invariants(stations, actors, step):
			return
	check_eq(GameState.training_points, expected_points, "player rewards counted exactly once per finished set")
	for a: Node2D in actors:
		var held: Station = Station.station_of(a)
		if held != null:
			held.release(a)
	for s2: Station in stations:
		check(s2.users().is_empty(), "everything free after releasing all")


func _invariants(stations: Array[Station], actors: Array[Node2D], step: int) -> bool:
	var seen: Dictionary = {}
	for s: Station in stations:
		var users: Array[Node] = s.users()
		if not check(users.size() <= s.capacity(), "step %d: over capacity" % step):
			return false
		for u: Node in users:
			if not check(is_instance_valid(u), "step %d: freed node still a user" % step):
				return false
			if not check(not seen.has(u), "step %d: actor on two stations" % step):
				return false
			seen[u] = true
			if not check(Station.station_of(u) == s, "step %d: claim map out of sync" % step):
				return false
	for a: Node2D in actors:
		var held: Station = Station.station_of(a)
		if held != null and not check(held.is_user(a), "step %d: claim map points to wrong station" % step):
			return false
	return true


func test_reservation_blocks_others() -> void:
	var s: Station = _station()
	var owner_a: Node2D = _actor(true)
	var other: Node2D = _actor()
	s.join_queue(other)
	s.reserve(owner_a)
	check(s.queue_position(other) == -1, "others are dropped from the line when reserved")
	check(not s.try_claim(other), "others can't claim a reserved machine")
	check(not s.join_queue(other), "others can't queue for a reserved machine")
	check(s.is_turn_of(owner_a), "owner skips the line")
	check(s.try_claim(owner_a), "owner claims it")
	s.release(owner_a)
	s.unreserve()
	check(s.try_claim(other), "free for everyone after unreserve")


func test_queue_limit_and_spots() -> void:
	var s: Station = _station()
	var a: Node2D = _actor()
	s.try_claim(a)
	var line: Array[Node2D] = []
	for i: int in s.max_queue:
		var n: Node2D = _actor()
		check(s.join_queue(n), "join %d" % i)
		line.append(n)
	check(not s.join_queue(_actor()), "line is capped at max_queue")
	check(s.queue_spot(0) != s.queue_spot(1), "each place in line has its own spot")
	check(s.queue_spot(1).distance_to(s.interact_point()) > s.queue_spot(0).distance_to(s.interact_point()), "later places stand further back")
