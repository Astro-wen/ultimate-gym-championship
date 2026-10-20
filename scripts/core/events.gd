extends Node
## Global event bus. Signals only, no logic.

@warning_ignore_start("unused_signal")
signal player_detected(by: Node)
signal alert_changed(value: float)
signal station_claimed(station: Node, who: Node)
signal station_released(station: Node, who: Node)
signal station_use_finished(station: Node, who: Node)
signal noise_made(at: Vector2, loudness: float)
signal rep_completed(station: Node, who: Node, good: bool)
signal reached_goal()
signal run_started()
signal run_finished(result: Dictionary)
signal buff_applied(kind: StringName, duration: float)
@warning_ignore_restore("unused_signal")
