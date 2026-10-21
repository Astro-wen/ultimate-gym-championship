class_name HoldReleaseGame
extends Minigame
## Bench press: hold interact to charge, release inside the green zone.

var charge: float = 0.0
var holding: bool = false
var _lockout: float = 0.0
## Key state seen during the lockout; a press held through it starts charging.
var _pending_down: bool = false


func handle_input(action: StringName, pressed: bool) -> void:
	if action != &"interact":
		return
	if _lockout > 0.0:
		_pending_down = pressed
		return
	if pressed:
		holding = true
		charge = 0.0
	elif holding:
		holding = false
		var z: Vector2 = zone()
		var good: bool = charge >= z.x and charge <= z.y
		_count(good)
		charge = 0.0
		_lockout = p("lockout", 0.25)


func tick(delta: float) -> void:
	if _lockout > 0.0:
		_lockout = maxf(_lockout - delta, 0.0)
		if _lockout == 0.0 and _pending_down:
			_pending_down = false
			holding = true
			charge = 0.0
	if holding:
		charge += delta * p("charge_rate", 0.9)
		if charge > 1.0:
			holding = false
			charge = 0.0
			_count(false)
			_lockout = p("lockout", 0.25)


func meter() -> float:
	return clampf(charge, 0.0, 1.0)


func zone() -> Vector2:
	return Vector2(p("zone_lo", 0.62), p("zone_hi", 0.86))


func hint() -> String:
	return "按住 E 蓄力，绿区松开"


func pose() -> float:
	# 0 = bar locked out (frame 0), 1 = bar on the chest while charging
	return clampf(charge, 0.0, 1.0) if holding else 0.0
