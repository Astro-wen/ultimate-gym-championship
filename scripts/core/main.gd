extends Node2D
## Root of the demo. Builds the level, actors and HUD; owns start/pause/restart.

@export var level_script: Script = preload("res://scripts/level/gym_level.gd")

var level: GymLevel
var player: Player
var hud: Hud


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
	_spawn_npcs()
	hud = Hud.new()
	hud.player = player
	add_child(hud)
	DebugShot.apply_cmdline(self)


const GOER_LOOKS: Array[Dictionary] = [
	{"body": Color(0.85, 0.25, 0.25), "legs": Color(0.2, 0.2, 0.25), "hair": Color(0.15, 0.1, 0.08)},
	{"body": Color(0.3, 0.7, 0.4), "legs": Color(0.25, 0.25, 0.35), "hair": Color(0.85, 0.65, 0.3)},
	{"body": Color(0.95, 0.6, 0.2), "legs": Color(0.15, 0.15, 0.2), "hair": Color(0.3, 0.2, 0.15)},
]

var director: StealthDirector


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
	var pm := Patroller.new()
	pm.name = "ProductManager"
	pm.level = level
	pm.points = level.patrol_points
	pm.position = level.patrol_points[0]
	pm.target_player = player
	level.world.add_child(pm)
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
