class_name TimingGame
extends Minigame
## Punching bag: the bag swings back and forth; hit when it is in the zone.

var phase: float = 0.0
var _dir: float = 1.0
var _punch: float = 0.0
var _stun: float = 0.0


func handle_input(action: StringName, pressed: bool) -> void:
	if action != &"interact" or not pressed or _stun > 0.0:
		return
	var z: Vector2 = zone()
	var good: bool = phase >= z.x and phase <= z.y
	_count(good)
	_punch = 1.0
	if good:
		# knock the bag back out of the zone so mashing can't chain hits
		_dir = -1.0
		phase = maxf(z.x - p("knockback", 0.08), 0.0)
	else:
		_stun = p("stun", 0.5)


func tick(delta: float) -> void:
	_punch = maxf(_punch - delta * 4.0, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	phase += _dir * delta * p("swing_speed", 0.9)
	if phase >= 1.0:
		phase = 1.0
		_dir = -1.0
	elif phase <= 0.0:
		phase = 0.0
		_dir = 1.0


func meter() -> float:
	return phase


func zone() -> Vector2:
	return Vector2(p("zone_lo", 0.78), p("zone_hi", 0.95))


func hint() -> String:
	return "沙袋荡回来时按 E 出拳"


func pose() -> float:
	return _punch
