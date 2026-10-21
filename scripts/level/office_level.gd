class_name OfficeLevel
extends Level
## The office: finish the day's work at your desk, print the weekly report,
## sign out at the front desk unseen, and take the elevator — without the
## PM, your colleagues or the receptionist noticing you sneaking off early.

const DESKS: String = "res://assets/sheets/interiors/int03_office_desks_768.png"
const MISC: String = "res://assets/sheets/interiors/int19_office_misc_768.png"

## Front desk position (the receptionist sits behind it, see `sitters`).
const RECEPTION := Vector2(800, 330)
const ELEVATOR_X: float = 890.0


func _init() -> void:
	level_id = &"office"
	title = "办公室"
	tagline = "干完今天的活，神不知鬼不觉地签退，坐电梯提前下班"
	intro_tips = [
		"按顺序：工位敲完代码 → 打印周报 → 前台签退 → 坐电梯",
		"同事大多盯着屏幕（视野很短），会时不时转头看过道",
		"前台会轮流看电脑、抬头、看电梯口：等她低头再去签字",
		"书架、打印机、饮水机挡视线；会议室是玻璃的，挡路不挡视线",
	]
	goal_points = 4
	time_limit = 120.0
	watch_rise = 0.8
	# in an office, standing in plain view at the front desk is not subtle
	still_factor = 0.7
	station_files = [
		"res://data/stations/desk_work.tres",
		"res://data/stations/printer.tres",
		"res://data/stations/signout.tres",
		"res://data/stations/elevator.tres",
	]
	station_positions = [
		Vector2(100, 300),           # your desk
		Vector2(560, 470),           # printer
		RECEPTION,                   # front desk (sign-out sheet on its left)
		Vector2(ELEVATOR_X, 104),    # elevator doors (painted on the wall)
	]
	blockers = [
		Rect2(150, 214, 192, 44),    # desk row 1 (3 seats)
		Rect2(150, 384, 192, 44),    # desk row 2
		Rect2(400, 296, 96, 40),     # bookshelf (cover)
		Rect2(620, 410, 96, 40),     # bookshelf (cover)
		Rect2(668, 196, 44, 30),     # water cooler
	]
	blocker_art = [
		{"path": DESKS, "region": Rect2(240, 460, 192, 112), "see_through": true},
		{"path": DESKS, "region": Rect2(240, 460, 192, 112), "see_through": true},
		{"path": DESKS, "region": Rect2(144, 304, 96, 104)},
		{"path": DESKS, "region": Rect2(336, 304, 96, 104)},
		{"path": MISC, "region": Rect2(670, 346, 60, 130)},
	]
	blocker_colors = [
		Color(0.72, 0.58, 0.4), Color(0.72, 0.58, 0.4),
		Color(0.55, 0.4, 0.3), Color(0.55, 0.4, 0.3), Color(0.75, 0.82, 0.88),
	]
	glass = [
		Rect2(470, 96, 6, 134),      # meeting room, left wall
		Rect2(510, 224, 140, 6),     # bottom wall (door gap at x 476-510)
		Rect2(644, 96, 6, 134),      # right wall
	]
	covers = [
		Rect2(400, 336, 96, 34),
		Rect2(620, 450, 96, 34),
		Rect2(712, 190, 40, 44),
	]
	player_spawn = Vector2(100, 340)
	# your own cubicle: sitting or standing at your desk is just working
	safe_zones = [Rect2(56, 300, 92, 64)]
	patrol_points = [
		Vector2(560, 160), Vector2(560, 280), Vector2(372, 275),
		Vector2(300, 470), Vector2(700, 380),
	]
	sitters = [
		{"name": "Colleague0", "pos": Vector2(182, 166), "skin": [0, 1], "angle": 60.0,
			"schedule": [Vector3(90, 2.5, 80), Vector3(55, 3.0, 210), Vector3(90, 2.5, 80), Vector3(130, 3.0, 210)]},
		{"name": "Colleague1", "pos": Vector2(310, 166), "skin": [0, 4], "angle": 60.0,
			"schedule": [Vector3(90, 2.0, 80), Vector3(120, 3.0, 210), Vector3(90, 3.0, 80), Vector3(45, 3.0, 210)]},
		{"name": "Colleague2", "pos": Vector2(246, 336), "skin": [1, 1], "angle": 60.0,
			"schedule": [Vector3(90, 2.5, 80), Vector3(150, 3.0, 200), Vector3(90, 2.0, 80), Vector3(40, 3.0, 200)]},
		# a real NPC behind the counter; after a round of watching she goes to the
		# water cooler for a drink (a window to sign out unseen) and comes back
		{"name": "Receptionist", "pos": RECEPTION + Vector2(0, -70), "skin": [1, 5], "angle": 70.0,
			"route": [Vector2(690, 246)], "loops": 2, "range": 160.0, "sweep": 35.0,
			"schedule": [Vector3(45, 3.0, 90), Vector3(105, 3.0, 230), Vector3(-35, 3.0, 180)]},
	]



func _draw_room() -> void:
	# warm wood floor with a carpet under the desks
	_draw_floor(Color(0.62, 0.5, 0.38), Color(0.58, 0.46, 0.35))
	draw_rect(Rect2(40, 130, 410, 300), Color(0.36, 0.42, 0.5))
	draw_rect(Rect2(40, 130, 410, 300), Color(0.28, 0.33, 0.4), false, 3.0)
	# meeting room floor
	draw_rect(Rect2(476, 96, 168, 128), Color(0.5, 0.52, 0.56))
	_draw_walls(Color(0.88, 0.88, 0.84), Color(0.6, 0.58, 0.55))
	# windows on the back wall
	for x: int in [60, 200, 330]:
		draw_rect(Rect2(x, 20, 100, 52), Color(0.66, 0.82, 0.92))
		draw_rect(Rect2(x, 20, 100, 52), Color(0.4, 0.45, 0.55), false, 2.0)
		draw_line(Vector2(x + 50, 20), Vector2(x + 50, 72), Color(0.4, 0.45, 0.55), 2.0)
	# meeting room sign and whiteboard
	draw_rect(Rect2(500, 26, 120, 50), Color(0.97, 0.97, 0.97))
	draw_rect(Rect2(500, 26, 120, 50), Color(0.5, 0.5, 0.55), false, 2.0)
	for i: int in 3:
		draw_line(Vector2(510, 38 + i * 12), Vector2(560 + i * 15, 38 + i * 12), Color(0.3, 0.45, 0.8), 2.0)
	# company logo behind the front desk
	draw_rect(Rect2(735, 30, 130, 44), Color(0.2, 0.35, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(735, 60), "需求科技", HORIZONTAL_ALIGNMENT_CENTER, 130, 20, Color.WHITE)
	_draw_elevator()
	# glass walls of the meeting room
	for r: Rect2 in glass:
		draw_rect(Rect2(r.position - Vector2(0, 30), r.size + Vector2(0, 30)), Color(0.7, 0.88, 0.96, 0.35))
		draw_rect(Rect2(r.position - Vector2(0, 30), r.size + Vector2(0, 30)), Color(0.55, 0.7, 0.8, 0.8), false, 1.0)


# --- elevator ------------------------------------------------------------------

## 0 = closed, 1 = fully open.
var door_open: float = 0.0:
	set(v):
		door_open = v
		queue_redraw()
## Floor shown above the doors (counts down while you call it).
var floor_num: int = 5:
	set(v):
		if v != floor_num:
			floor_num = v
			queue_redraw()
var _riding: bool = false


func _ready() -> void:
	super._ready()
	Events.station_use_finished.connect(_on_task_done)


func _process(_delta: float) -> void:
	if _riding:
		return
	# the car comes down while you hold the call button
	var p: Player = get_tree().get_first_node_in_group(&"player") as Player
	if p != null and p.station != null and p.station.data.id == &"elevator" and p.minigame is HoldReleaseGame:
		floor_num = clampi(5 - int((p.minigame as HoldReleaseGame).charge * 5.0), 1, 5)
	elif not GameState.sets_done.has(&"elevator"):
		floor_num = 5


func _on_task_done(st: Node, who: Node) -> void:
	if (st as Station).data.id == &"elevator" and who is Player and not _riding:
		ride_elevator(who as Player)


## Ding, doors open, the player walks in, doors close, then the run ends.
func ride_elevator(p: Player) -> void:
	_riding = true
	GameState.hold_win = true
	p.input_enabled = false
	var inside := Vector2(ELEVATOR_X, WALL_TOP - 2.0)
	var tw: Tween = create_tween()
	tw.tween_method(func(f: float) -> void: floor_num = int(round(f)), float(floor_num), 1.0, 0.4)
	tw.tween_callback(Events.elevator_ding.emit)
	tw.tween_property(self, ^"door_open", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		p.facing = Vector2.UP
		p.speed_kind = ActorBody.Speed.WALK
		p.glide_to(inside, 0.55))
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		p.speed_kind = ActorBody.Speed.STILL
		p.visible = false)
	tw.tween_property(self, ^"door_open", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void: GameState.hold_win = false)


func _draw_elevator() -> void:
	var ex: float = ELEVATOR_X
	var frame := Rect2(ex - 40, 18, 80, 78)
	draw_rect(frame, Color(0.35, 0.37, 0.42))
	# the car interior shows as the doors part
	draw_rect(Rect2(ex - 34, 30, 68, 66), Color(0.22, 0.2, 0.18))
	draw_rect(Rect2(ex - 30, 34, 60, 6), Color(1.0, 0.92, 0.7, 0.8))
	draw_rect(Rect2(ex - 34, 86, 68, 10), Color(0.4, 0.36, 0.3))
	# two leaves sliding into the frame
	var leaf: float = 34.0 * (1.0 - door_open)
	if leaf > 0.5:
		draw_rect(Rect2(ex - leaf, 30, leaf, 66), Color(0.72, 0.75, 0.8))
		draw_rect(Rect2(ex, 30, leaf, 66), Color(0.68, 0.71, 0.76))
		draw_line(Vector2(ex - leaf, 30), Vector2(ex - leaf, 96), Color(0.55, 0.58, 0.62), 1.0)
		draw_line(Vector2(ex + leaf, 30), Vector2(ex + leaf, 96), Color(0.55, 0.58, 0.62), 1.0)
		draw_line(Vector2(ex, 30), Vector2(ex, 96), Color(0.3, 0.32, 0.36), 2.0)
	# floor display + direction arrow
	draw_rect(Rect2(ex - 16, 20, 32, 9), Color(0.1, 0.1, 0.12))
	var arrow: String = "" if floor_num <= 1 else " ▼"
	draw_string(ThemeDB.fallback_font, Vector2(ex - 16, 28), "%dF%s" % [floor_num, arrow], HORIZONTAL_ALIGNMENT_CENTER, 32, 8, Color(1.0, 0.55, 0.2))
	# call button: lit while the car is coming / riding
	var lit: bool = _riding or floor_num < 5
	draw_circle(Vector2(ex + 46, 64), 4.0, Color(0.9, 0.9, 0.92))
	draw_circle(Vector2(ex + 46, 64), 2.0, Color(1.0, 0.6, 0.2) if lit else Color(0.55, 0.55, 0.6))
