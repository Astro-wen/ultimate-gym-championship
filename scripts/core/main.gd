extends Node2D
## Root of the demo. Builds the level, actors and HUD; owns start/pause/restart.

## Placeholder colors (used when the licensed character sheets are absent)
## and walk-sheet skins [set, index] (used when present).
const GOER_LOOKS: Array[Dictionary] = [
	{"body": Color(0.85, 0.25, 0.25), "legs": Color(0.2, 0.2, 0.25), "hair": Color(0.15, 0.1, 0.08), "skin": [0, 0], "pose": &"goer_red"},
	{"body": Color(0.3, 0.7, 0.4), "legs": Color(0.25, 0.25, 0.35), "hair": Color(0.85, 0.65, 0.3), "skin": [0, 2], "pose": &"goer_green"},
	{"body": Color(0.95, 0.6, 0.2), "legs": Color(0.15, 0.15, 0.2), "hair": Color(0.3, 0.2, 0.15), "skin": [3, 0], "pose": &"goer_blue"},
]
const PLAYER_SKIN: Array[int] = [0, 6]
const PM_SKIN: Array[int] = [1, 0]

var level: GymLevel
var player: Player
var hud: Hud
var director: StealthDirector


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	Station.clear_all_claims()
	level = GymLevel.new()
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	player = Player.new()
	player.name = "Player"
	player.position = level.player_spawn
	player.facing = Vector2.UP
	level.world.add_child(player)
	LocalArt.apply_skin(player.visual, PLAYER_SKIN[0], PLAYER_SKIN[1])
	player.visual.pose_char = &"player"
	_spawn_npcs()
	hud = Hud.new()
	hud.player = player
	add_child(hud)
	Sfx.attach(self)
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
	var pm := Patroller.new()
	pm.name = "ProductManager"
	pm.level = level
	pm.points = level.patrol_points
	pm.position = level.patrol_points[0]
	pm.target_player = player
	level.world.add_child(pm)
	LocalArt.apply_skin(pm.visual, PM_SKIN[0], PM_SKIN[1])
	director = StealthDirector.new()
	director.name = "StealthDirector"
	director.player = player
	director.level = level
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		restart()
	elif event.is_action_pressed(&"pause") and GameState.is_running():
		get_tree().paused = not get_tree().paused
		hud.paused = get_tree().paused
	elif event.is_action_pressed(&"interact") and GameState.state == GameState.State.READY:
		GameState.start_run()
		get_viewport().set_input_as_handled()


func restart() -> void:
	get_tree().paused = false
	GameState.reset()
	Station.clear_all_claims()
	get_tree().reload_current_scene()
