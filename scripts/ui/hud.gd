class_name Hud
extends CanvasLayer
## All on-screen UI, drawn in code: top bar, alert meter, station prompt,
## minigame meter, intro card, pause and results.

const STAT_NAMES: Dictionary = {&"strength": "力量", &"stamina": "耐力", &"power": "爆发"}
const BG := Color(0.08, 0.09, 0.12, 0.85)
const GOOD := Color(0.35, 0.85, 0.45)
const WARN := Color(0.95, 0.75, 0.25)
const BAD := Color(0.95, 0.3, 0.3)

var player: Player
var alert: float = 0.0
var paused: bool = false
var _flash: String = ""
var _flash_t: float = 0.0
var _canvas: Control
var _font: Font


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
	Events.rep_completed.connect(_on_rep)
	Events.station_use_finished.connect(_on_set_done)
	Events.player_detected.connect(func(_by: Node) -> void: flash("被产品经理发现了！"))


func flash(text: String, secs: float = 1.6) -> void:
	_flash = text
	_flash_t = secs


func _on_rep(_st: Node, who: Node, good: bool) -> void:
	if who == player:
		flash("漂亮！" if good else "失误…", 0.6)


func _on_set_done(st: Node, who: Node) -> void:
	if who == player:
		var d: StationData = (st as Station).data
		flash("%s 完成一组！%s +%d，隐身 %d 秒" % [d.display_name, STAT_NAMES.get(d.stat, String(d.stat)), d.stat_gain, int(d.buff_duration)], 2.2)


func _process(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	_canvas.queue_redraw()


# --- drawing helpers -----------------------------------------------------

func _text(pos: Vector2, s: String, size: int = 16, col: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	_canvas.draw_string_outline(_font, pos, s, align, width, size, 4, Color(0, 0, 0, 0.8))
	_canvas.draw_string(_font, pos, s, align, width, size, col)


func _bar(r: Rect2, v: float, col: Color, zone: Vector2 = Vector2(-1, -1)) -> void:
	_canvas.draw_rect(r, Color(0.15, 0.15, 0.2))
	if zone.x >= 0.0:
		_canvas.draw_rect(Rect2(r.position.x + r.size.x * zone.x, r.position.y, r.size.x * (zone.y - zone.x), r.size.y), Color(0.25, 0.6, 0.3))
	_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col)
	_canvas.draw_rect(r, Color(0.9, 0.9, 0.95), false, 1.0)


func _draw_ui() -> void:
	var vp: Vector2 = _canvas.size
	_draw_top_bar(vp)
	match GameState.state:
		GameState.State.READY:
			_draw_intro(vp)
		GameState.State.RUNNING:
			_draw_play(vp)
		_:
			_draw_results(vp)
	if paused:
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
		_text(Vector2(0, vp.y * 0.5), "暂停中  Esc 继续  R 重开", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x)


func _draw_top_bar(vp: Vector2) -> void:
	_canvas.draw_rect(Rect2(0, 0, vp.x, 34), BG)
	var t: float = GameState.time_left()
	var col: Color = BAD if t < 30.0 else Color.WHITE
	_text(Vector2(12, 24), "⏱ %d:%02d" % [int(t) / 60, int(t) % 60], 18, col)
	_text(Vector2(110, 24), "训练量", 16)
	_bar(Rect2(170, 10, 200, 16), GameState.training_progress(), GOOD)
	_text(Vector2(378, 24), "%d%%" % int(GameState.training_progress() * 100.0), 16)
	var x: float = 440.0
	for k: StringName in [&"strength", &"stamina", &"power"]:
		_text(Vector2(x, 24), "%s %d" % [STAT_NAMES[k], int(GameState.stats.get(k, 0))], 16)
		x += 78.0
	_text(Vector2(680, 24), "被发现 %d" % GameState.detections, 16, BAD if GameState.detections > 0 else Color.WHITE)
	if GameState.has_buff(&"stealthy"):
		_text(Vector2(790, 24), "隐身 %.0fs" % float(GameState.active_buffs[&"stealthy"]), 16, Color(0.6, 0.85, 1.0))


func _draw_play(vp: Vector2) -> void:
	# alert meter (top-center under the bar)
	if alert > 0.01:
		var col: Color = WARN if alert < 0.7 else BAD
		_text(Vector2(vp.x * 0.5 - 150, 58), "警戒", 16, col)
		_bar(Rect2(vp.x * 0.5 - 110, 45, 220, 14), alert, col)
	if player == null:
		return
	var g: Minigame = player.minigame
	if g != null and player.station != null:
		var d: StationData = player.station.data
		var panel := Rect2(vp.x * 0.5 - 170, vp.y - 98, 340, 88)
		_canvas.draw_rect(panel, BG)
		_text(panel.position + Vector2(12, 24), "%s  %d / %d" % [d.display_name, g.reps, g.target_reps], 18, Color.WHITE)
		_text(panel.position + Vector2(200, 24), "Q 离开", 14, Color(0.7, 0.7, 0.75))
		if d.minigame == &"alternate":
			var left_col: Color = GOOD if (g as AlternateGame).expected == &"move_left" else Color(0.4, 0.4, 0.45)
			var right_col: Color = GOOD if (g as AlternateGame).expected == &"move_right" else Color(0.4, 0.4, 0.45)
			_text(panel.position + Vector2(110, 58), "◀", 28, left_col)
			_text(panel.position + Vector2(200, 58), "▶", 28, right_col)
		else:
			_bar(Rect2(panel.position + Vector2(12, 36), Vector2(316, 18)), g.meter(), WARN, g.zone())
		_text(panel.position + Vector2(12, 78), g.hint(), 15, Color(0.85, 0.9, 1.0))
	elif player.focus_station != null:
		var st: Station = player.focus_station
		var msg: String
		if st.is_free():
			msg = "E  开始 %s" % st.data.display_name
		else:
			var u: Node = st.users()[0] if not st.users().is_empty() else null
			msg = ("E  挤开对方抢%s（会很吵）" if u != null and st.can_push(player, u) else "%s 有人在用…") % st.data.display_name
		var w: float = 300.0
		_canvas.draw_rect(Rect2(vp.x * 0.5 - w * 0.5, vp.y - 50, w, 32), BG)
		_text(Vector2(vp.x * 0.5 - w * 0.5, vp.y - 28), msg, 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)
	if _flash_t > 0.0:
		_text(Vector2(0, vp.y * 0.30), _flash, 22, Color(1, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER, vp.x)


func _draw_intro(vp: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	var r := Rect2(vp.x * 0.5 - 300, 80, 600, 380)
	_canvas.draw_rect(r, BG)
	_canvas.draw_rect(r, Color(0.9, 0.8, 0.4), false, 2.0)
	var x: float = r.position.x
	_text(Vector2(x, 130), "ULTIMATE GYM CHAMPIONSHIP", 30, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(x, 165), "午休 3 分钟，偷偷练完今天的量", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var lines: Array[String] = [
		"WASD / 方向键  移动（默认慢走，比较安静）",
		"Shift  跑步（快，但更容易被发现）",
		"E / 空格  使用器械（卧推 · 哑铃 · 跑步机 · 沙袋）",
		"Q  离开器械        Esc 暂停        R 重开",
		"小心产品经理的视野：警戒满了被抓回门口、扣 15 秒，3 次出局",
		"躲在柜子、柱子后面更安全；练完一组获得短暂隐身",
	]
	for i: int in lines.size():
		_text(Vector2(x + 40, 215 + i * 30), lines[i], 16, Color(0.85, 0.9, 1.0))
	var blink: bool = int(Time.get_ticks_msec() / 500) % 2 == 0
	_text(Vector2(x, 435), "按 E 开始" if blink else "", 22, GOOD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_results(vp: Vector2) -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	var r := Rect2(vp.x * 0.5 - 230, 110, 460, 320)
	_canvas.draw_rect(r, BG)
	var title: String
	var col: Color
	match GameState.state:
		GameState.State.WON:
			title = "训练完成！准时回工位"
			col = GOOD
		GameState.State.CAUGHT:
			title = "被抓去开需求会了…"
			col = BAD
		_:
			title = "午休结束，没练完"
			col = WARN
	_canvas.draw_rect(r, col, false, 2.0)
	var x: float = r.position.x
	_text(Vector2(x, 160), title, 26, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(x, 230), GameState.grade(), 64, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(Vector2(x + 60, 290), "用时  %d:%02d" % [int(GameState.elapsed) / 60, int(GameState.elapsed) % 60], 18)
	_text(Vector2(x + 60, 320), "训练量  %d%%" % int(GameState.training_progress() * 100.0), 18)
	_text(Vector2(x + 60, 350), "被发现  %d 次" % GameState.detections, 18)
	_text(Vector2(x, 405), "按 R 再来一局", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
