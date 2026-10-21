class_name AlternateGame
extends Minigame
## Dumbbell curl: alternate left / right. Each correct pair is one rep.
## Mashing the same side twice breaks the rhythm.

var expected: StringName = &"move_left"
var half_done: bool = false
var _arm: float = 0.0
var _window: float = 0.0
## Seconds since the first half of the pair; pressing both sides at once is a miss.
var _since_half: float = 0.0


func handle_input(action: StringName, pressed: bool) -> void:
	if not pressed or (action != &"move_left" and action != &"move_right"):
		return
	if action != expected:
		half_done = false
		expected = &"move_left"
		_count(false)
		return
	if half_done and _since_half < p("min_gap", 0.06):
		half_done = false
		expected = &"move_left"
		_count(false)
		return
	_arm = 1.0
	_window = p("window", 1.2)
	if not half_done:
		half_done = true
		_since_half = 0.0
		expected = &"move_right"
	else:
		half_done = false
		expected = &"move_left"
		_count(true)


func tick(delta: float) -> void:
	_arm = maxf(_arm - delta * 2.5, 0.0)
	if half_done:
		_since_half += delta
		_window -= delta
		if _window <= 0.0:
			half_done = false
			expected = &"move_left"


func meter() -> float:
	return 0.5 if half_done else 0.0


func zone() -> Vector2:
	return Vector2(-1.0, -1.0)


func hint() -> String:
	return "← → 交替弯举" if expected == &"move_left" else "→ 另一只手！"


func pose() -> float:
	return _arm
