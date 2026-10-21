extends Node2D
## Root of the demo. Shows the level menu, builds the chosen level, actors and
## HUD; owns start/pause/restart/back-to-menu.

## Placeholder colors (used when the licensed character sheets are absent)
## and walk-sheet skins [set, index] (used when present).
const GOER_LOOKS: Array[Dictionary] = [
	{"body": Color(0.85, 0.25, 0.25), "legs": Color(0.2, 0.2, 0.25), "hair": Color(0.15, 0.1, 0.08), "skin": [0, 0], "pose": &"goer_red"},
	{"body": Color(0.3, 0.7, 0.4), "legs": Color(0.25, 0.25, 0.35), "hair": Color(0.85, 0.65, 0.3), "skin": [0, 2], "pose": &"goer_green"},
	{"body": Color(0.95, 0.6, 0.2), "legs": Color(0.15, 0.15, 0.2), "hair": Color(0.3, 0.2, 0.15), "skin": [3, 0], "pose": &"goer_blue"},
	{"body": Color(0.95, 0.85, 0.5), "legs": Color(0.3, 0.3, 0.4), "hair": Color(0.9, 0.75, 0.35), "skin": [0, 3], "pose": &"goer_blonde"},
	{"body": Color(0.55, 0.75, 0.95), "legs": Color(0.45, 0.4, 0.3), "hair": Color(0.6, 0.45, 0.3), "skin": [0, 7], "pose": &"goer_sky"},
	{"body": Color(0.6, 0.35, 0.25), "legs": Color(0.2, 0.2, 0.25), "hair": Color(0.15, 0.12, 0.1), "skin": [2, 2], "pose": &"goer_brown"},
]
const PLAYER_SKIN: Array[int] = [0, 6]
const PM_SKIN: Array[int] = [1, 0]
## When the results screen appeared (ms); E restarts only after a short delay
## so a key mashed during the last rep doesn't skip the results.
const RESULTS_INPUT_DELAY_MS: int = 1200

var level: Level
var player: Player
var hud: Hud
var director: StealthDirector
var _ended_ms: int = 0


## Level for an id; the menu shows over the office.
static func make_level(id: StringName) -> Level:
	if id == &"gym":
		return GymLevel.new()
	return OfficeLevel.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# close via quit_game() so audio is released first (no leak warnings)
	get_tree().auto_accept_quit = false
	GameState.reset()
	Station.clear_all_claims()
	DebugShot.level_from_cmdline()
	level = make_level(GameState.selected_level)
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	GameState.training_goal = level.goal_points
	GameState.time_limit = level.time_limit
	player = Player.new()
	player.name = "Player"
	player.position = level.player_spawn
	player.facing = Vector2.UP
	level.world.add_child(player)
	LocalArt.apply_skin(player.visual, PLAYER_SKIN[0], PLAYER_SKIN[1])
	player.visual.pose_char = &"player"
	if level.level_id == &"gym":
		var cup := WaterCup.new()
		cup.name = "WaterCup"
		cup.owner_actor = player
		level.world.add_child(cup)
		player.cup = cup
	_spawn_npcs()
	hud = Hud.new()
	hud.player = player
	hud.level = level
	hud.menu_mode = GameState.selected_level == &""
	hud.level_chosen.connect(choose_level)
	add_child(hud)
	Sfx.attach(self)
	Juice.attach(self, level.world)
	var cam := ShakeCamera.new()
	cam.name = "Camera"
	cam.room = Level.ROOM
	cam.target = player
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(cam)
	Events.run_finished.connect(func(_r: Dictionary) -> void: _ended_ms = Time.get_ticks_msec())
	DebugShot.apply_cmdline(self)


func _spawn_npcs() -> void:
	for i: int in level.npc_spawns.size():
		var g := GymGoer.new()
		g.name = "GymGoer%d" % i
		g.level = level
		g.rng.seed = 1000 + i
		g.position = level.npc_spawns[i]
		var look: Dictionary = GOER_LOOKS[i % GOER_LOOKS.size()]
		g.body_color = look["body"]
		g.legs_color = look["legs"]
		g.hair_color = look["hair"]
		level.world.add_child(g)
		LocalArt.apply_skin(g.visual, look["skin"][0], look["skin"][1])
		g.visual.pose_char = look["pose"]
	if not level.patrol_points.is_empty():
		var pm := Patroller.new()
		pm.name = "ProductManager"
		pm.level = level
		pm.points = level.patrol_points
		pm.position = level.patrol_points[0]
		pm.target_player = player
		pm.base_rise = level.watch_rise
		pm.speed_factor_still = level.still_factor
		level.world.add_child(pm)
		LocalArt.apply_skin(pm.visual, PM_SKIN[0], PM_SKIN[1])
	for s: Dictionary in level.sitters:
		var w := Patroller.new()
		w.name = String(s.get("name", "Sitter"))
		w.level = level
		var route: Array[Vector2] = [s["pos"]]
		for p: Vector2 in s.get("route", []):
			route.append(p)
		w.points = route
		w.schedule_loops = int(s.get("loops", 1))
		w.view_range = float(s.get("range", 200.0))
		w.sweep_deg = float(s.get("sweep", 40.0))
		w.position = s["pos"]
		w.target_player = player
		w.view_angle = float(s.get("angle", 60.0))
		w.hide_body = bool(s.get("hide_body", false))
		w.base_rise = level.watch_rise
		w.speed_factor_still = level.still_factor
		w.body_color = Color(0.55, 0.6, 0.7)
		var sched: Array[Vector3] = []
		for v: Vector3 in s.get("schedule", []):
			sched.append(v)
		w.look_schedule = sched
		level.world.add_child(w)
		var skin: Array = s.get("skin", [])
		if skin.size() == 2:
			LocalArt.apply_skin(w.visual, int(skin[0]), int(skin[1]))
	_apply_difficulty()
	director = StealthDirector.new()
	director.name = "StealthDirector"
	director.player = player
	director.level = level
	director.max_detections = int(Difficulty.params(GameState.difficulty)["strikes"])
	GameState.max_strikes = director.max_detections
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)


func _unhandled_input(event: InputEvent) -> void:
	if hud.menu_mode:
		return   # the HUD menu handles its own input
	if event.is_action_pressed(&"restart"):
		restart()
	elif event.is_action_pressed(&"menu") and (get_tree().paused or not GameState.is_running()):
		choose_level(&"")
	elif event.is_action_pressed(&"pause") and GameState.is_running():
		get_tree().paused = not get_tree().paused
		hud.paused = get_tree().paused
	elif event.is_action_pressed(&"interact") and _results_ready():
		restart()
	elif event.is_action_pressed(&"interact") and GameState.state == GameState.State.READY:
		GameState.start_run()
		get_viewport().set_input_as_handled()


## Switch level (&"" = back to the menu) and rebuild the scene.
func choose_level(id: StringName) -> void:
	GameState.selected_level = id
	restart()


func restart() -> void:
	get_tree().paused = false
	GameState.reset()
	Station.clear_all_claims()
	get_tree().reload_current_scene()


func _results_ready() -> bool:
	var ended: bool = GameState.state != GameState.State.READY and not GameState.is_running()
	return ended and Time.get_ticks_msec() - _ended_ms >= RESULTS_INPUT_DELAY_MS


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Stop audio, let the server drop its playbacks, then quit.
func quit_game() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"sfx"):
		(n as Sfx).stop_all()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


## Tune every watcher for the chosen difficulty; the PM can also follow.
func _apply_difficulty() -> void:
	var dp: Dictionary = Difficulty.params(GameState.difficulty)
	for n: Node in get_tree().get_nodes_in_group(&"patrollers"):
		var w: Patroller = n as Patroller
		w.base_rise *= float(dp["rise"])
		w.range_mult = float(dp["view"])
		if w.look_schedule.is_empty():
			# the walking PM
			w.walk_speed *= float(dp["pm_speed"])
			w.can_chase = true
			w.chase_speed = float(dp["chase_speed"])
			w.chase_give_up = float(dp["chase_time"])
			w.follow_threshold = float(dp["follow_at"])
			w.route_randomness = float(dp["randomness"])
