class_name Juice
extends Node
## Game-feel reactions to events: impact effects and hit-stop.

## Real seconds the world freezes on a shove.
@export var shove_hitstop: float = 0.08
@export var hitstop_scale: float = 0.05

var world: Node2D
var _stopping: bool = false


static func attach(parent: Node, world_node: Node2D) -> Juice:
	var j := Juice.new()
	j.name = "Juice"
	j.world = world_node
	j.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(j)
	return j


func _ready() -> void:
	Events.shoved.connect(_on_shoved)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_shoved(_pusher: Node, _victim: Node, at: Vector2) -> void:
	ImpactFx.spawn(world, at + Vector2(0, -30), "砰！")
	hit_stop(shove_hitstop)


## Freeze the world for `secs` real seconds (time-scale based, pause-safe).
func hit_stop(secs: float) -> void:
	if _stopping or get_tree().paused:
		return
	_stopping = true
	Engine.time_scale = hitstop_scale
	# a connection (not await) so a restart mid-freeze can't resume on a freed node
	get_tree().create_timer(secs, true, false, true).timeout.connect(_end_stop)


func _end_stop() -> void:
	Engine.time_scale = 1.0
	_stopping = false
