class_name RhythmGame
extends Minigame
## Treadmill: tap interact to keep speed inside the zone. Every N seconds
## in the zone counts as one rep; drifting out too long counts a miss.

var speed: float = 0.0
var _in_zone: float = 0.0
var _out_zone: float = 0.0
var _phase: float = 0.0


func handle_input(action: StringName, pressed: bool) -> void:
	if action == &"interact" and pressed:
		speed = minf(speed + p("tap_boost", 0.12), 1.0)


func tick(delta: float) -> void:
	speed = maxf(speed - delta * p("decay", 0.35), 0.0)
	_phase = fmod(_phase + delta * (2.0 + speed * 8.0), 1.0)
	var z: Vector2 = zone()
	if speed >= z.x and speed <= z.y:
		_in_zone += delta
		_out_zone = 0.0
		if _in_zone >= p("seconds_per_rep", 1.5):
			_in_zone = 0.0
			_count(true)
	elif speed > 0.05:
		_out_zone += delta
		if _out_zone >= p("miss_after", 2.5):
			_out_zone = 0.0
			_count(false)


func meter() -> float:
	return speed


func zone() -> Vector2:
	return Vector2(p("zone_lo", 0.45), p("zone_hi", 0.75))


func hint() -> String:
	return "连按 E 保持在绿区"


func pose() -> float:
	return _phase
