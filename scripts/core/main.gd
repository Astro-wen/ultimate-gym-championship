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


## Overridden by later milestones (GymGoers, Patroller).
func _spawn_npcs() -> void:
	pass


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
