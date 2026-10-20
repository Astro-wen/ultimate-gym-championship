class_name StealthDirector
extends Node
## Combines every Patroller's awareness into the global alert (max, not sum)
## and applies the consequences of being spotted.

@export var max_detections: int = 3
@export var time_penalty: float = 15.0
@export var difficulty_step: float = 0.05
@export var difficulty_cap: float = 1.3
@export var respawn_grace: float = 2.5

var player: Player
var level: GymLevel
var _last_alert: float = -1.0


func _ready() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"patrollers"):
		var pt: Patroller = n as Patroller
		pt.spotted_player.connect(_on_spotted.bind(pt))


func global_alert() -> float:
	var a: float = 0.0
	for n: Node in get_tree().get_nodes_in_group(&"patrollers"):
		a = maxf(a, (n as Patroller).awareness)
	return a


func _physics_process(_delta: float) -> void:
	var a: float = global_alert()
	if not is_equal_approx(a, _last_alert):
		_last_alert = a
		Events.alert_changed.emit(a)


func _on_spotted(by: Patroller) -> void:
	if not GameState.is_running():
		return
	GameState.detections += 1
	Events.player_detected.emit(by)
	player.end_use(&"caught")
	player.snap_to(level.player_spawn)
	player.facing = Vector2.UP
	for n: Node in get_tree().get_nodes_in_group(&"patrollers"):
		var pt: Patroller = n as Patroller
		pt.awareness = 0.0
		pt.grace = respawn_grace
	by.difficulty = minf(by.difficulty + difficulty_step, difficulty_cap)
	if GameState.detections >= max_detections:
		GameState.finish(GameState.State.CAUGHT)
	else:
		GameState.elapsed += time_penalty
