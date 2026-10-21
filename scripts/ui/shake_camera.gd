class_name ShakeCamera
extends Camera2D
## Fixed camera over the room with a small trauma-based shake for impacts.

@export var max_offset: float = 6.0
@export var decay: float = 2.5

var _trauma: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_detected.connect(func(_by: Node) -> void: add_trauma(0.8))
	Events.station_use_finished.connect(func(_s: Node, who: Node) -> void:
		if who.is_in_group(&"player"):
			add_trauma(0.35))
	Events.rep_completed.connect(func(s: Node, who: Node, good: bool) -> void:
		if good and who.is_in_group(&"player") and (s as Station).data.minigame == &"timing":
			add_trauma(0.3))
	Events.shoved.connect(func(_p: Node, _v: Node, _at: Vector2) -> void: add_trauma(0.75))


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	_trauma = maxf(_trauma - decay * delta, 0.0)
	var s: float = _trauma * _trauma * max_offset
	offset = Vector2(sin(_t * 47.0), cos(_t * 39.0)) * s
