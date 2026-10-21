class_name Hud
extends CanvasLayer
## All on-screen UI, drawn in code: top bar, alert gauge + vignette, key-cap
## prompts, queue card, minigame card, toasts, intro, pause and results.

const STAT_NAMES: Dictionary = {&"strength": "力量", &"stamina": "耐力", &"power": "爆发", &"task": "进度"}
const STAT_COLORS: Dictionary = {&"strength": Color(0.95, 0.45, 0.35), &"stamina": Color(0.4, 0.85, 0.5), &"power": Color(0.98, 0.75, 0.3)}
const PANEL := Color(0.07, 0.08, 0.11, 0.88)
const PANEL_EDGE := Color(1, 1, 1, 0.10)
const TEXT := Color(0.94, 0.95, 0.97)
const DIM := Color(0.66, 0.69, 0.75)
const GOOD := Color(0.4, 0.88, 0.5)
const WARN := Color(0.98, 0.76, 0.28)
const BAD := Color(0.96, 0.33, 0.3)
const INFO := Color(0.45, 0.75, 0.98)
const TOAST_SECS: float = 2.4

## Emitted by the start menu: &"office" or &"gym".
signal level_chosen(id: StringName)

const MENU_ITEMS: Array[Dictionary] = [
	{"id": &"office", "title": "Demo：办公室", "sub": "干完活、偷偷签退、坐电梯提前下班", "key": "1", "color": Color(0.45, 0.75, 0.98)},
	{"id": &"gym", "title": "健身房", "sub": "午休 3 分钟练完今天的量，抢器械别被抓", "key": "2", "color": Color(0.98, 0.76, 0.28)},
]
const WATCHER_NAMES: Dictionary = {"ProductManager": "产品经理", "Receptionist": "前台"}
const TASK_SHORT: Dictionary = {&"desk_work": "敲代码", &"printer": "打印周报", &"signout": "前台签退", &"elevator": "坐电梯"}

var player: Player
var level: Level
## Start menu: pick a level (no run, no player input).
var menu_mode: bool = false
var alert: float = 0.0
var paused: bool = false
var _menu_sel: int = 0
var _menu_rects: Array[Rect2] = []
var _diff_rects: Array[Rect2] = []
var _canvas: Control
var _font: Font
var _t: float = 0.0
var _toasts: Array[Dictionary] = []   # {text, kind, t}
var _caught_flash: float = 0.0
var _shown_progress: float = 0.0
## Full length of the current stealth buff (for its countdown bar).
var _buff_full: float = 8.0
var _sb_cache: Dictionary = {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_ui)
	add_child(_canvas)
	_font = ThemeDB.fallback_font
	Events.alert_changed.connect(func(v: float) -> void: alert = v)
	Events.station_use_finished.connect(_on_set_done)
	Events.player_detected.connect(_on_detected)
	Events.toast.connect(toast)
	Events.buff_applied.connect(func(_k: StringName, d: float) -> void: _buff_full = d)
	Events.shoved.connect(func(_p: Node, _v: Node, _at: Vector2) -> void: toast("挤上去了！对方很不爽，产品经理也听见了", &"warn"))


## Shows a banner under the top bar (stacks, newest at the bottom).
func toast(text: String, kind: StringName = &"info") -> void:
	_toasts.append({"text": text, "kind": kind, "t": 0.0})
	while _toasts.size() > 3:
		_toasts.pop_front()


## Kept for older callers: a plain info toast.
func flash(text: String, _secs: float = 1.6) -> void:
	toast(text, &"info")


func _on_set_done(st: Node, who: Node) -> void:
	if who != player:
		return
	var d: StationData = (st as Station).data
	if d.stat == &"task":
		toast("✓ %s 完成！" % d.display_name, &"good")
	else:
		toast("%s 完成一组！%s +%d · 隐身 %d 秒" % [d.display_name, STAT_NAMES.get(d.stat, String(d.stat)), d.stat_gain, int(d.buff_duration)], &"good")


func _on_detected(by: Node) -> void:
	_caught_flash = 1.0
	var left: int = GameState.max_strikes - GameState.detections
	var who: String = "同事"
	if by != null:
		who = WATCHER_NAMES.get(String(by.name), "同事")
	toast("被%s发现了！" % who + ("扣 15 秒，还剩 %d 次机会" % left if left > 0 else ""), &"bad")


# --- start menu ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not menu_mode:
		return
	if event.is_action_pressed(&"move_left"):
		_menu_sel = (_menu_sel + MENU_ITEMS.size() - 1) % MENU_ITEMS.size()
	elif event.is_action_pressed(&"move_right"):
		_menu_sel = (_menu_sel + 1) % MENU_ITEMS.size()
	elif event.is_action_pressed(&"move_up"):
		GameState.difficulty = maxi(GameState.difficulty - 1, 0)
	elif event.is_action_pressed(&"move_down"):
		GameState.difficulty = mini(GameState.difficulty + 1, Difficulty.NAMES.size() - 1)
	elif event.is_action_pressed(&"interact"):
		level_chosen.emit(MENU_ITEMS[_menu_sel]["id"])
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).physical_keycode
		if k == KEY_1 or k == KEY_KP_1:
			level_chosen.emit(MENU_ITEMS[0]["id"])
		elif k == KEY_2 or k == KEY_KP_2:
			level_chosen.emit(MENU_ITEMS[1]["id"])
	else:
		return
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not menu_mode or _menu_rects.is_empty():
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mm == null and (mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT):
		return
	# canvas_items stretch: map the window position into the 960x540 canvas
	var p: Vector2 = _canvas.get_global_transform_with_canvas().affine_inverse() * (mm.position if mm != null else mb.position)
	for i: int in _diff_rects.size():
		if mb != null and _diff_rects[i].has_point(p):
			GameState.difficulty = i
			get_viewport().set_input_as_handled()
			return
	for i: int in _menu_rects.size():
		if _menu_rects[i].has_point(p):
			_menu_sel = i
			if mb != null:
				level_chosen.emit(MENU_ITEMS[i]["id"])
				get_viewport().set_input_as_handled()
			return


func _draw_menu(vp: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.06, 0.72))
	_text(Vector2(0, 110), "ULTIMATE GYM CHAMPIONSHIP", 34, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	_text(Vector2(0, 142), "打工人的潜行日常 · Demo", 16, DIM, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	_menu_rects.clear()
	var w: float = 300.0
	var h: float = 190.0
	var gap: float = 40.0
	var x0: float = vp.x * 0.5 - w - gap * 0.5
	for i: int in MENU_ITEMS.size():
		var it: Dictionary = MENU_ITEMS[i]
		var sel: bool = i == _menu_sel
		var lift: float = -6.0 if sel else 0.0
		var r := Rect2(x0 + i * (w + gap), 190 + lift, w, h)
		_menu_rects.append(Rect2(r.position.x, 190 - 6, w, h + 6))
		var col: Color = it["color"]
		_panel(r, Color(0.08, 0.09, 0.13, 0.95), Color(col, 0.95 if sel else 0.35), 16)
		if sel:
			_panel(r.grow(4.0), Color(0, 0, 0, 0), Color(col, 0.35 + 0.25 * absf(sin(_t * 4.0))), 20)
		_draw_menu_icon(it["id"], r.position + Vector2(w * 0.5, 64), col)
		_text(Vector2(r.position.x, r.position.y + 128), it["title"], 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w)
		_text(Vector2(r.position.x, r.position.y + 156), it["sub"], 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, w)
		_keycap(Vector2(r.position.x + 12, r.position.y + 12), it["key"])
	_draw_difficulty_row(vp, 404.0)
	var hint: String = "鼠标点击，或 ← → 选关卡、↑ ↓ 选难度、E 开始（也可以直接按 1 / 2）"
	_text(Vector2(0, 498), hint, 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	_text(Vector2(0, vp.y - 10), "美术素材：LimeZu《Modern Interiors》 · 角色动作由 AI 基于原素材绘制", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, vp.x)


## Simple pictograms: an elevator door for the office, a dumbbell for the gym.
func _draw_menu_icon(id: StringName, c: Vector2, col: Color) -> void:
	if id == &"office":
		_panel(Rect2(c + Vector2(-34, -36), Vector2(68, 72)), Color(0.35, 0.37, 0.42), Color(0, 0, 0, 0.4), 6)
		_canvas.draw_rect(Rect2(c + Vector2(-28, -26), Vector2(27, 62)), Color(0.75, 0.78, 0.83))
		_canvas.draw_rect(Rect2(c + Vector2(1, -26), Vector2(27, 62)), Color(0.7, 0.73, 0.78))
		_canvas.draw_rect(Rect2(c + Vector2(-12, -34), Vector2(24, 7)), Color(0.1, 0.1, 0.12))
		_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -33), c + Vector2(4, -33), c + Vector2(0, -28)]), col)
	else:
		_canvas.draw_rect(Rect2(c + Vector2(-38, -4), Vector2(76, 8)), Color(0.75, 0.75, 0.8))
		for sx: float in [-1.0, 1.0]:
			_panel(Rect2(c + Vector2(sx * 30 - 7, -22), Vector2(14, 44)), Color(0.22, 0.22, 0.28), Color(0, 0, 0, 0.4), 4)
			_panel(Rect2(c + Vector2(sx * 42 - 5, -15), Vector2(10, 30)), Color(0.3, 0.3, 0.36), Color(0, 0, 0, 0.4), 3)
		_canvas.draw_circle(c + Vector2(0, -30), 4.0, col)


func _process(delta: float) -> void:
	_t += delta
	if not get_tree().paused:
		for tt: Dictionary in _toasts:
			tt["t"] = float(tt["t"]) + delta
		_toasts = _toasts.filter(func(tt: Dictionary) -> bool: return float(tt["t"]) < TOAST_SECS)
		_caught_flash = maxf(_caught_flash - delta * 1.6, 0.0)
	_shown_progress = lerpf(_shown_progress, GameState.training_progress(), minf(delta * 8.0, 1.0))
	_canvas.queue_redraw()


# --- drawing helpers -----------------------------------------------------

func _text(pos: Vector2, s: String, size: int = 16, col: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	_canvas.draw_string_outline(_font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.75 * col.a))
	_canvas.draw_string(_font, pos, s, align, width, size, col)


func _text_w(s: String, size: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _panel(r: Rect2, bg: Color = PANEL, border: Color = PANEL_EDGE, radius: int = 8) -> void:
	var key: String = "%s|%s|%d" % [bg, border, radius]
	var sb: StyleBoxFlat = _sb_cache.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		_sb_cache[key] = sb
	_canvas.draw_style_box(sb, r)


func _bar(r: Rect2, v: float, col: Color, zone: Vector2 = Vector2(-1, -1)) -> void:
	_panel(r, Color(0.16, 0.17, 0.22), Color(1, 1, 1, 0.12), 4)
	if zone.x >= 0.0:
		_canvas.draw_rect(Rect2(r.position.x + r.size.x * zone.x, r.position.y + 1, r.size.x * (zone.y - zone.x), r.size.y - 2), Color(0.25, 0.55, 0.32))
	var w: float = r.size.x * clampf(v, 0.0, 1.0)
	if w > 1.0:
		_panel(Rect2(r.position, Vector2(w, r.size.y)), col, Color(1, 1, 1, 0.18), 4)
		_canvas.draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(maxf(w - 6.0, 0.0), 2)), Color(1, 1, 1, 0.25))
	if zone.x >= 0.0:
		_canvas.draw_rect(Rect2(r.position.x + r.size.x * zone.x, r.position.y, r.size.x * (zone.y - zone.x), r.size.y), Color(0.45, 1.0, 0.55), false, 1.5)


## A keyboard key-cap with a label; returns its width.
func _keycap(pos: Vector2, key: String, size: int = 13) -> float:
	var w: float = maxf(_text_w(key, size) + 12.0, 22.0)
	var r := Rect2(pos, Vector2(w, 22))
	_panel(Rect2(r.position + Vector2(0, 2), r.size), Color(0.45, 0.42, 0.35), Color(0, 0, 0, 0), 5)
	_panel(r, Color(0.98, 0.95, 0.86), Color(0.2, 0.2, 0.25, 0.6), 5)
	_canvas.draw_string(_font, pos + Vector2(0, 16), key, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(0.14, 0.14, 0.2))
	return w


## [key] label pairs laid out as one centered strip at height `y`.
func _prompt_row(y: float, items: Array, vp: Vector2) -> void:
	if items.is_empty():
		return
	var gap: float = 22.0
	var total: float = 0.0
	for it: Array in items:
		total += maxf(_text_w(it[0], 13) + 12.0, 22.0) + 6.0 + _text_w(it[1], 15)
	total += gap * (items.size() - 1)
	var r := Rect2(vp.x * 0.5 - total * 0.5 - 14.0, y - 6.0, total + 28.0, 34.0)
	_panel(r)
	var x: float = r.position.x + 14.0
	for it: Array in items:
		x += _keycap(Vector2(x, y), it[0]) + 6.0
		var col: Color = it[2] if it.size() > 2 else TEXT
		_text(Vector2(x, y + 16), it[1], 15, col)
		x += _text_w(it[1], 15) + gap


# --- frame ---------------------------------------------------------------

func _draw_ui() -> void:
	var vp: Vector2 = _canvas.size
	if menu_mode:
		_draw_menu(vp)
		return
	_draw_vignette(vp)
	_draw_top_bar(vp)
	match GameState.state:
		GameState.State.READY:
			_draw_intro(vp)
		GameState.State.RUNNING:
			_draw_play(vp)
		_:
			_draw_results(vp)
	_draw_toasts(vp)
	if paused:
		_draw_pause(vp)


func _draw_vignette(vp: Vector2) -> void:
	var a: float = 0.0
	if GameState.is_running() and alert > 0.45:
		a = (alert - 0.45) / 0.55 * (0.35 + 0.15 * sin(_t * (6.0 + alert * 8.0)))
	a = maxf(a, _caught_flash * 0.6)
	if a <= 0.01:
		return
	var steps: int = 10
	for i: int in steps:
		var k: float = float(i) / steps
		var inset: float = k * 70.0
		var c := Color(0.9, 0.08, 0.06, a * (1.0 - k) * 0.35)
		_canvas.draw_rect(Rect2(Vector2(inset, inset), vp - Vector2(inset, inset) * 2.0), c, false, 8.0)


func _draw_top_bar(vp: Vector2) -> void:
	_panel(Rect2(6, 6, vp.x - 12, 36), PANEL, PANEL_EDGE, 10)
	# timer chip
	var t: float = GameState.time_left()
	var low: bool = t < 30.0 and GameState.is_running()
	var tc: Color = BAD if low else TEXT
	var pulse: float = 1.0 + (0.12 * absf(sin(_t * 6.0)) if low else 0.0)
	_panel(Rect2(12, 11, 74, 26), Color(0.6, 0.12, 0.1, 0.6) if low else Color(1, 1, 1, 0.06), PANEL_EDGE, 7)
	_text(Vector2(12, 31), "%d:%02d" % [int(t) / 60, int(t) % 60], int(18 * pulse), tc, HORIZONTAL_ALIGNMENT_CENTER, 74)
	if level != null and level.level_id == &"office":
		_draw_task_chips()
	else:
		_draw_training(vp)
	_draw_top_bar_right(vp)


func _draw_task_chips() -> void:
	var x: float = 98.0
	_text(Vector2(x, 30), "任务", 14, DIM)
	x += 36.0
	var next_found: bool = false
	for st: Station in level.stations:
		var id: StringName = st.data.id
		var done: bool = GameState.sets_done.has(id)
		var is_next: bool = not done and not next_found and not st.is_locked_for(player)
		if is_next:
			next_found = true
		var s: String = TASK_SHORT.get(id, st.data.display_name)
		var w: float = _text_w(s, 14) + 30.0
		var bg: Color = Color(GOOD, 0.22) if done else (Color(INFO, 0.18 + 0.1 * absf(sin(_t * 3.0))) if is_next else Color(1, 1, 1, 0.04))
		_panel(Rect2(x, 13, w, 22), bg, Color(GOOD, 0.6) if done else (Color(INFO, 0.7) if is_next else PANEL_EDGE), 11)
		var c := Vector2(x + 11, 24)
		if done:
			_canvas.draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3), c + Vector2(4, -3)]), GOOD, 2.0)
		elif is_next:
			_canvas.draw_circle(c, 4.0, INFO)
		else:
			_canvas.draw_rect(Rect2(c + Vector2(-3, -1), Vector2(6, 5)), DIM)
			_canvas.draw_arc(c + Vector2(0, -1), 2.5, PI, TAU, 6, DIM, 1.2)
		_text(Vector2(x + 19, 30), s, 14, TEXT if (done or is_next) else DIM)
		x += w + 6.0


func _draw_training(_vp: Vector2) -> void:
	# training progress
	_text(Vector2(98, 30), "训练量", 14, DIM)
	_bar(Rect2(150, 16, 190, 16), _shown_progress, GOOD)
	for i: int in range(1, 4):
		_canvas.draw_rect(Rect2(150 + 190 * i / 4.0, 18, 1, 12), Color(0, 0, 0, 0.35))
	_text(Vector2(346, 30), "%d%%" % int(GameState.training_progress() * 100.0), 14, TEXT)
	# stat chips
	var x: float = 398.0
	for k: StringName in [&"strength", &"stamina", &"power"]:
		var s: String = "%s %d" % [STAT_NAMES[k], int(GameState.stats.get(k, 0))]
		var w: float = _text_w(s, 14) + 22.0
		_panel(Rect2(x, 13, w, 22), Color(1, 1, 1, 0.05), PANEL_EDGE, 11)
		_canvas.draw_circle(Vector2(x + 10, 24), 4.0, STAT_COLORS[k])
		_text(Vector2(x + 17, 30), s, 14, TEXT)
		x += w + 6.0


func _draw_top_bar_right(vp: Vector2) -> void:
	# strikes (times caught)
	var x: float = vp.x - 250.0
	_text(Vector2(x, 30), "被抓", 14, DIM)
	for i: int in GameState.max_strikes:
		var c := Vector2(x + 44 + i * 18, 24)
		var used: bool = i < GameState.detections
		_canvas.draw_circle(c, 7.0, BAD if used else Color(1, 1, 1, 0.08))
		_canvas.draw_arc(c, 7.0, 0.0, TAU, 16, BAD if used else Color(1, 1, 1, 0.3), 1.5)
		if used:
			_canvas.draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), Color.WHITE, 2.0)
			_canvas.draw_line(c + Vector2(3, -3), c + Vector2(-3, 3), Color.WHITE, 2.0)
	# stealth buff / cup status
	x = vp.x - 140.0
	if GameState.has_buff(&"stealthy"):
		var left: float = float(GameState.active_buffs[&"stealthy"])
		_text(Vector2(x, 24), "隐身", 12, INFO)
		_bar(Rect2(x + 28, 16, 96, 8), left / maxf(_buff_full, 0.01), INFO)
	if player != null and player.cup != null:
		var cs: String = "水杯在手上"
		var cc: Color = DIM
		if not player.cup.carried:
			cs = "水杯占着%s" % player.cup.reserved.data.display_name if player.cup.reserved != null else "水杯在地上"
			cc = INFO if player.cup.reserved != null else DIM
		_text(Vector2(x, 36 if GameState.has_buff(&"stealthy") else 30), cs, 11 if GameState.has_buff(&"stealthy") else 13, cc)


func _draw_alert_gauge(vp: Vector2) -> void:
	if alert <= 0.01:
		return
	var col: Color = WARN.lerp(BAD, clampf((alert - 0.5) * 2.0, 0.0, 1.0))
	var w: float = 200.0
	var r := Rect2(vp.x * 0.5 - w * 0.5 - 30, 48, w + 60, 24)
	_panel(r, PANEL, Color(col, 0.5), 12)
	# eye icon
	var c := Vector2(r.position.x + 18, r.position.y + 12)
	var open: float = 3.0 + alert * 3.0
	_canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(0, -open), c + Vector2(9, 0), c + Vector2(0, open)]), Color(1, 1, 1, 0.9))
	_canvas.draw_circle(c, 2.6, col.darkened(0.4))
	_bar(Rect2(r.position.x + 34, r.position.y + 7, w, 10), alert, col)


func _draw_play(vp: Vector2) -> void:
	_draw_alert_gauge(vp)
	if player == null:
		return
	var g: Minigame = player.minigame
	if g != null and player.station != null:
		_draw_minigame_card(vp, g, player.station.data)
		return
	if player.queued != null and is_instance_valid(player.queued):
		_draw_queue_card(vp, player.queued)
	var items: Array = []
	var st: Station = player.focus_station
	if st != null:
		var label: String = player.interact_label(st)
		if label != "":
			var col: Color = GOOD if st.is_turn_of(player) else (WARN if label.begins_with("挤") else TEXT)
			items.append(["E", label, col])
		elif st.is_locked_for(player):
			items.append(["E", player.locked_reason(st), DIM])
		elif st.is_reserved_against(player):
			items.append(["E", "%s被别人占了" % st.data.display_name, DIM])
		elif player.queued != st and st.queue_size() >= st.max_queue:
			items.append(["E", "%s排满了，换一台吧" % st.data.display_name, DIM])
	if player.cup != null:
		if player.cup.carried:
			var tgt: Station = player.cup_drop_target()
			items.append(["F", "放水杯占住%s" % tgt.data.display_name if tgt != null else "放下水杯", INFO if tgt != null else DIM])
		elif player.can_pick_up_cup():
			items.append(["F", "拿起水杯", TEXT])
	_prompt_row(vp.y - 46, items, vp)


func _draw_queue_card(vp: Vector2, st: Station) -> void:
	var pos: int = st.queue_position(player)
	if pos < 0:
		return
	var turn: bool = st.is_turn_of(player)
	var r := Rect2(vp.x * 0.5 - 130, vp.y - 98, 260, 40)
	var col: Color = GOOD if turn else INFO
	_panel(r, PANEL, Color(col, 0.6), 10)
	if turn:
		var a: float = 0.6 + 0.4 * absf(sin(_t * 5.0))
		_text(r.position + Vector2(0, 26), "轮到你了！快按 E 上%s" % st.data.display_name, 16, Color(GOOD, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return
	_text(r.position + Vector2(14, 25), "排队：%s" % st.data.display_name, 15, TEXT)
	# little people icons: users, then line, you highlighted
	var x: float = r.position.x + 140
	var people: int = st.users().size() + st.queue_size()
	for i: int in mini(people, 5):
		var me: bool = i == st.users().size() + pos
		var c := Vector2(x + i * 20, r.position.y + 20)
		var pc: Color = WARN if me else (BAD.darkened(0.2) if i < st.users().size() else DIM)
		_canvas.draw_circle(c + Vector2(0, -6), 4.0, pc)
		_canvas.draw_rect(Rect2(c + Vector2(-4, -1), Vector2(8, 8)), pc)
	_text(Vector2(r.end.x - 52, r.end.y + 14), "走开即离队", 11, DIM)


func _draw_minigame_card(vp: Vector2, g: Minigame, d: StationData) -> void:
	var r := Rect2(vp.x * 0.5 - 180, vp.y - 92, 360, 82)
	_panel(r, PANEL, PANEL_EDGE, 12)
	_text(r.position + Vector2(14, 26), d.display_name, 18, TEXT)
	# rep pips, squeezed to fit between the title and the Q key
	var pip_gap: float = minf(16.0, (r.size.x - 110.0 - 90.0) / float(maxi(g.target_reps, 1)))
	for i: int in g.target_reps:
		var c := Vector2(r.position.x + 110 + i * pip_gap, r.position.y + 19)
		var pr: float = minf(6.0, pip_gap * 0.45)
		_canvas.draw_circle(c, pr, Color(0, 0, 0, 0.4))
		_canvas.draw_circle(c, pr - 1.0, GOOD if i < g.reps else Color(1, 1, 1, 0.12))
	var qx: float = r.end.x - 70
	_keycap(Vector2(qx, r.position.y + 9), "Q")
	_text(Vector2(qx + 28, r.position.y + 25), "离开", 13, DIM)
	if d.minigame == &"alternate":
		var a: AlternateGame = g as AlternateGame
		var lx: float = r.position.x + 120
		var left_on: bool = a.expected == &"move_left"
		_panel(Rect2(lx, r.position.y + 36, 50, 24), GOOD if left_on else Color(1, 1, 1, 0.08), PANEL_EDGE, 6)
		_text(Vector2(lx, r.position.y + 54), "← A", 14, Color(0.1, 0.1, 0.15) if left_on else DIM, HORIZONTAL_ALIGNMENT_CENTER, 50)
		_panel(Rect2(lx + 70, r.position.y + 36, 50, 24), GOOD if not left_on else Color(1, 1, 1, 0.08), PANEL_EDGE, 6)
		_text(Vector2(lx + 70, r.position.y + 54), "D →", 14, Color(0.1, 0.1, 0.15) if not left_on else DIM, HORIZONTAL_ALIGNMENT_CENTER, 50)
	else:
		_bar(Rect2(r.position + Vector2(14, 38), Vector2(r.size.x - 28, 18)), g.meter(), WARN, g.zone())
	_text(r.position + Vector2(14, 76), g.hint_line(), 14, Color(0.8, 0.88, 1.0))


func _draw_toasts(vp: Vector2) -> void:
	var y: float = 80.0
	for tt: Dictionary in _toasts:
		var t: float = float(tt["t"])
		var a: float = clampf(minf(t / 0.15, (TOAST_SECS - t) / 0.35), 0.0, 1.0)
		var slide: float = (1.0 - clampf(t / 0.15, 0.0, 1.0)) * -14.0
		var kind: StringName = tt["kind"]
		var col: Color = {&"good": GOOD, &"warn": WARN, &"bad": BAD}.get(kind, INFO)
		var s: String = tt["text"]
		var w: float = _text_w(s, 16) + 40.0
		var r := Rect2(vp.x * 0.5 - w * 0.5, y + slide, w, 30)
		_panel(r, Color(PANEL, PANEL.a * a), Color(col, 0.7 * a), 15)
		_canvas.draw_circle(r.position + Vector2(16, 15), 4.0, Color(col, a))
		_text(r.position + Vector2(26, 21), s, 16, Color(TEXT, a))
		y += 36.0


func _draw_pause(vp: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
	var r := Rect2(vp.x * 0.5 - 180, vp.y * 0.5 - 70, 360, 140)
	_panel(r, PANEL, PANEL_EDGE, 14)
	_text(r.position + Vector2(0, 44), "暂停", 28, TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var x: float = r.position.x + 40
	x += _keycap(Vector2(x, r.position.y + 76), "Esc") + 6
	_text(Vector2(x, r.position.y + 92), "继续", 15, TEXT)
	x += 60
	x += _keycap(Vector2(x, r.position.y + 76), "R") + 6
	_text(Vector2(x, r.position.y + 92), "重开", 15, TEXT)
	x += 60
	x += _keycap(Vector2(x, r.position.y + 76), "M") + 6
	_text(Vector2(x, r.position.y + 92), "回菜单", 15, TEXT)


func _draw_intro(vp: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
	var r := Rect2(vp.x * 0.5 - 330, 62, 660, 418)
	_panel(r, PANEL, Color(1.0, 0.85, 0.35, 0.6), 16)
	var x: float = r.position.x
	var office: bool = level != null and level.level_id == &"office"
	_text(Vector2(x, 108), (level.title if level != null else "") + "  ·  ULTIMATE GYM CHAMPIONSHIP", 26, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(x, 138), level.tagline if level != null else "", 16, TEXT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var dc: Color = Difficulty.COLORS[GameState.difficulty]
	_panel(Rect2(r.end.x - 96, r.position.y + 12, 84, 24), Color(dc, 0.2), Color(dc, 0.8), 12)
	_text(Vector2(r.end.x - 96, r.position.y + 30), "难度：" + Difficulty.name_of(GameState.difficulty), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 84)
	var controls: Array = [
		["WASD", "移动（默认慢走，比较安静）"],
		["Shift", "跑（快，但更容易被发现）"],
		["E", "做任务（敲代码 / 打印 / 签字 / 按电梯）" if office else "上器械 / 排队 / 排第一时挤开别人"],
		["F", "放下 / 拿起水杯：放在器械旁就占住它"],
		["Q", "离开（中途停下）" if office else "离开器械"],
		["Esc", "暂停　　R 重开　　M 回菜单"],
	]
	if office:
		controls.remove_at(3)
	var y: float = 162.0
	for c: Array in controls:
		var kw: float = _keycap(Vector2(x + 44, y), c[0])
		_text(Vector2(x + 44 + maxf(kw, 50.0) + 10, y + 16), c[1], 15, TEXT)
		y += 30.0
	var tips: Array[String] = []
	if level != null:
		tips = level.intro_tips
	y += 8.0
	for tip: String in tips:
		_canvas.draw_circle(Vector2(x + 50, y - 5), 3.0, WARN)
		_text(Vector2(x + 60, y), tip, 14, DIM)
		y += 24.0
	var blink: float = 0.55 + 0.45 * absf(sin(_t * 3.0))
	var bx: float = vp.x * 0.5 - 60
	_keycap(Vector2(bx, r.end.y - 44), "E")
	_text(Vector2(bx + 30, r.end.y - 28), "开始行动" if office else "开始午休", 18, Color(GOOD, blink))
	_text(Vector2(0, vp.y - 10), "美术素材：LimeZu《Modern Interiors》 · 角色动作由 AI 基于原素材绘制", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, vp.x)


func _draw_results(vp: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	var r := Rect2(vp.x * 0.5 - 240, 90, 480, 360)
	var title: String
	var col: Color
	var office: bool = level != null and level.level_id == &"office"
	match GameState.state:
		GameState.State.WON:
			title = "电梯门关上了：提前下班成功！" if office else "训练完成！准时回工位"
			col = GOOD
		GameState.State.CAUGHT:
			title = "被拉进会议室对需求了…" if office else "被抓去开需求会了…"
			col = BAD
		_:
			title = "到点了，还是没溜成…" if office else "午休结束，没练完"
			col = WARN
	_panel(r, PANEL, Color(col, 0.7), 16)
	var x: float = r.position.x
	_text(Vector2(x, 134), title, 24, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(r.end.x - 110, r.position.y + 28), "难度：" + Difficulty.name_of(GameState.difficulty), 12, Difficulty.COLORS[GameState.difficulty], HORIZONTAL_ALIGNMENT_CENTER, 100)
	var grade: String = GameState.grade()
	var gc: Color = {"S": Color(1, 0.85, 0.3), "A": GOOD, "B": INFO}.get(grade, DIM)
	_canvas.draw_circle(Vector2(vp.x * 0.5, 196), 40.0, Color(gc, 0.15))
	_canvas.draw_arc(Vector2(vp.x * 0.5, 196), 40.0, 0.0, TAU, 40, gc, 3.0)
	_text(Vector2(x, 216), grade, 56, gc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# stat tiles
	var tiles: Array = [
		["用时", "%d:%02d" % [int(GameState.elapsed) / 60, int(GameState.elapsed) % 60]],
		["任务" if office else "训练量", ("%d / %d" % [GameState.training_points, GameState.training_goal]) if office else ("%d%%" % int(GameState.training_progress() * 100.0))],
		["被抓", "%d 次" % GameState.detections],
	]
	var tw: float = 130.0
	var tx: float = vp.x * 0.5 - (tw * 3 + 20) * 0.5
	for tile: Array in tiles:
		_panel(Rect2(tx, 256, tw, 58), Color(1, 1, 1, 0.05), PANEL_EDGE, 10)
		_text(Vector2(tx, 278), tile[0], 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, tw)
		_text(Vector2(tx, 304), tile[1], 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER, tw)
		tx += tw + 10.0
	# sets per machine
	var parts: PackedStringArray = []
	for id: StringName in GameState.sets_done.keys():
		var nm: String = {&"bench_press": "卧推", &"dumbbell_curl": "哑铃", &"treadmill": "跑步机", &"punching_bag": "沙袋"}.get(id, TASK_SHORT.get(id, String(id)))
		parts.append(("✓ %s" % nm) if office else ("%s ×%d" % [nm, int(GameState.sets_done[id])]))
	_text(Vector2(x, 342), ("完成：" if office else "完成组数：") + (" · ".join(parts) if not parts.is_empty() else "无"), 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var bx: float = vp.x * 0.5 - 70
	bx -= 50
	bx += _keycap(Vector2(bx, r.end.y - 50), "E") + 8
	_text(Vector2(bx, r.end.y - 34), "再来一局", 17, TEXT)
	bx += 90
	bx += _keycap(Vector2(bx, r.end.y - 50), "M") + 8
	_text(Vector2(bx, r.end.y - 34), "回菜单", 17, DIM)


func _draw_difficulty_row(vp: Vector2, y: float) -> void:
	_diff_rects.clear()
	_panel(Rect2(vp.x * 0.5 - 230, y - 10, 460, 82), PANEL, PANEL_EDGE, 14)
	var w: float = 96.0
	var gap: float = 10.0
	var n: int = Difficulty.NAMES.size()
	var x: float = vp.x * 0.5 - (w * n + gap * (n - 1)) * 0.5 + 40.0
	_text(Vector2(x - 80, y + 20), "难度", 15, DIM)
	for i: int in n:
		var sel: bool = i == GameState.difficulty
		var col: Color = Difficulty.COLORS[i]
		var r := Rect2(x + i * (w + gap), y, w, 28)
		_diff_rects.append(r)
		_panel(r, Color(col, 0.25) if sel else Color(1, 1, 1, 0.05), Color(col, 0.9) if sel else PANEL_EDGE, 14)
		_text(Vector2(r.position.x, y + 20), Difficulty.name_of(i), 15, TEXT if sel else DIM, HORIZONTAL_ALIGNMENT_CENTER, w)
	_text(Vector2(0, y + 58), Difficulty.BLURBS[GameState.difficulty], 13, Difficulty.COLORS[GameState.difficulty], HORIZONTAL_ALIGNMENT_CENTER, vp.x)
