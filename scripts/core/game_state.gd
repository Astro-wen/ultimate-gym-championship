extends Node
## State of the current run. Call reset() before every run; nothing may survive it.

enum State { READY, RUNNING, CAUGHT, WON, TIMEOUT }

@export var time_limit: float = 180.0
## Training points needed to finish the day's workout.
@export var training_goal: int = 36

## Level picked in the menu (&"gym" | &"office"; &"" = show the menu).
## Survives reset() and scene reloads on purpose.
var selected_level: StringName = &""
var state: State = State.READY
var elapsed: float = 0.0
var detections: int = 0
var training_points: int = 0
var stats: Dictionary = {}          # StringName -> int
var sets_done: Dictionary = {}      # StringName (station id) -> int
var active_buffs: Dictionary = {}   # StringName -> float (seconds left)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func reset() -> void:
	state = State.READY
	elapsed = 0.0
	detections = 0
	training_points = 0
	stats = {}
	sets_done = {}
	active_buffs = {}


func start_run() -> void:
	reset()
	state = State.RUNNING
	Events.run_started.emit()


func is_running() -> bool:
	return state == State.RUNNING


func time_left() -> float:
	return maxf(time_limit - elapsed, 0.0)


func training_progress() -> float:
	if training_goal <= 0:
		return 1.0
	return clampf(float(training_points) / float(training_goal), 0.0, 1.0)


func record_set(station_id: StringName, stat: StringName, gain: int) -> void:
	sets_done[station_id] = int(sets_done.get(station_id, 0)) + 1
	stats[stat] = int(stats.get(stat, 0)) + gain
	training_points += gain


func apply_buff(kind: StringName, duration: float) -> void:
	if kind == &"" or duration <= 0.0:
		return
	active_buffs[kind] = maxf(float(active_buffs.get(kind, 0.0)), duration)
	Events.buff_applied.emit(kind, duration)


func has_buff(kind: StringName) -> bool:
	return float(active_buffs.get(kind, 0.0)) > 0.0


func finish(result_state: State) -> void:
	if state != State.RUNNING:
		return
	state = result_state
	Events.run_finished.emit(build_result())


func build_result() -> Dictionary:
	return {
		"state": state,
		"time": elapsed,
		"detections": detections,
		"training": training_progress(),
		"perfect": detections == 0,
		"grade": grade(),
	}


func grade() -> String:
	if state != State.WON:
		return "C" if training_progress() >= 0.5 else "D"
	if detections == 0 and elapsed <= time_limit * 0.6:
		return "S"
	if detections == 0:
		return "A"
	return "B"


func tick(delta: float) -> void:
	if state != State.RUNNING:
		return
	elapsed += delta
	for kind: StringName in active_buffs.keys():
		var left: float = float(active_buffs[kind]) - delta
		if left <= 0.0:
			active_buffs.erase(kind)
		else:
			active_buffs[kind] = left
	if training_progress() >= 1.0:
		finish(State.WON)
	elif elapsed >= time_limit:
		finish(State.TIMEOUT)


func _process(delta: float) -> void:
	tick(delta)
