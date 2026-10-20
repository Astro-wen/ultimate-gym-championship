class_name DebugShot
extends Node
## Dev-only automation driven by user args after `--`:
##   --autostart            start the run immediately
##   --warp=x,y             teleport the player
##   --use=<station index>  put the player on that station
##   --shot=<path.png>      save a screenshot after --shot-frames (default 30), then quit
##   --run-frames=N         quit after N frames (for soak runs)
##   --autoplay             let AutoplayBot drive the player

var main: Node
var shot_path: String = ""
var shot_frames: int = 30
var run_frames: int = -1
var _frame: int = 0


static func apply_cmdline(m: Node) -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return
	var d := DebugShot.new()
	d.main = m
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	var opts: Dictionary = {}
	for a: String in args:
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	d.shot_path = String(opts.get("shot", ""))
	d.shot_frames = int(opts.get("shot-frames", "30"))
	d.run_frames = int(opts.get("run-frames", "-1"))
	m.add_child(d)
	if opts.has("autostart"):
		GameState.start_run()
	if opts.has("warp"):
		var xy: PackedStringArray = String(opts["warp"]).split(",")
		m.get(&"player").global_position = Vector2(float(xy[0]), float(xy[1]))
	if opts.has("autoplay"):
		var bot := AutoplayBot.new()
		bot.player = m.get(&"player")
		bot.level = m.get(&"level")
		m.add_child(bot)
	if opts.has("use"):
		d._use_station.call_deferred(int(opts["use"]))


func _use_station(idx: int) -> void:
	var lvl: GymLevel = main.get(&"level")
	var p: Player = main.get(&"player")
	if idx >= 0 and idx < lvl.stations.size():
		p.try_use(lvl.stations[idx])


func _process(_delta: float) -> void:
	_frame += 1
	if shot_path != "" and _frame == shot_frames:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(shot_path)
		print("[shot] saved %s" % shot_path)
		get_tree().quit()
	elif run_frames > 0 and _frame >= run_frames:
		print("[soak] %d frames ok" % _frame)
		get_tree().quit()
