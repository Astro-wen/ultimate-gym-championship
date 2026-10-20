class_name Minigame
extends RefCounted
## Pure-logic exercise minigame. Feed it inputs and time; it counts reps.
## The view (MinigameMeter) only reads meter()/zone()/hint().

signal rep_done(good: bool)

var target_reps: int = 5
var reps: int = 0
var misses: int = 0
var params: Dictionary = {}


static func create(d: StationData) -> Minigame:
	var g: Minigame
	match d.minigame:
		&"hold_release":
			g = HoldReleaseGame.new()
		&"alternate":
			g = AlternateGame.new()
		&"rhythm":
			g = RhythmGame.new()
		&"timing":
			g = TimingGame.new()
		_:
			push_error("Unknown minigame kind: %s" % d.minigame)
			g = HoldReleaseGame.new()
	g.target_reps = maxi(d.reps_per_set, 1)
	g.params = d.minigame_params
	g._setup()
	return g


func p(key: String, default: float) -> float:
	return float(params.get(key, default))


func is_finished() -> bool:
	return reps >= target_reps


func _count(good: bool) -> void:
	if is_finished():
		return
	if good:
		reps += 1
	else:
		misses += 1
	rep_done.emit(good)


# --- overridables --------------------------------------------------------

func _setup() -> void:
	pass


func handle_input(_action: StringName, _pressed: bool) -> void:
	pass


func tick(_delta: float) -> void:
	pass


## 0..1 main meter value.
func meter() -> float:
	return 0.0


## Target window on the meter (x=lo, y=hi).
func zone() -> Vector2:
	return Vector2(0.6, 0.85)


func hint() -> String:
	return ""


## 0..1 position for the pose animation (0 = rest, 1 = full effort).
func pose() -> float:
	return meter()
