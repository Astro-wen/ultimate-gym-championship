class_name GymLevel
extends Level
## The gym: train on four machines while regulars compete for them and the
## PM patrols.


func _init() -> void:
	level_id = &"gym"
	title = "健身房"
	tagline = "午休 3 分钟，偷偷练完今天的量，别被产品经理抓去开会"
	intro_tips = [
		"四个动作：卧推 · 哑铃弯举 · 跑步机 · 沙袋",
		"器械被占就排队（混在队伍里不显眼）；常客多，用水杯先占好下一台",
		"黄色视野照到会涨警戒；柜子、柱子后面的浅绿区更安全",
		"被抓扣 15 秒，3 次出局；练完一组获得短暂隐身",
	]
	goal_points = 36
	station_files = [
		"res://data/stations/bench_press.tres",
		"res://data/stations/dumbbell_curl.tres",
		"res://data/stations/treadmill.tres",
		"res://data/stations/treadmill.tres",
		"res://data/stations/punching_bag.tres",
	]
	station_positions = [
		Vector2(170, 215),
		Vector2(380, 185),
		Vector2(650, 215),
		Vector2(740, 215),
		Vector2(870, 360),
	]
	blockers = [
		Rect2(24, 250, 44, 150),    # lockers
		Rect2(300, 330, 40, 40),    # pillar
		Rect2(560, 330, 40, 40),    # pillar
		Rect2(880, 120, 56, 40),    # water cooler + shelf
	]
	blocker_colors = [Color(0.45, 0.55, 0.65), Color(0.7, 0.7, 0.72), Color(0.7, 0.7, 0.72), Color(0.7, 0.7, 0.72)]
	covers = [
		Rect2(68, 250, 40, 150),
		Rect2(290, 370, 60, 40),
		Rect2(550, 370, 60, 40),
	]
	player_spawn = Vector2(120, 480)
	npc_spawns = [
		Vector2(300, 480), Vector2(420, 470), Vector2(540, 480),
		Vector2(660, 470), Vector2(780, 480), Vector2(880, 470),
	]
	patrol_points = [
		Vector2(480, 120), Vector2(200, 300), Vector2(480, 450), Vector2(800, 300),
	]


func _draw_room() -> void:
	# rubber gym tiles
	_draw_floor(Color(0.32, 0.33, 0.38), Color(0.29, 0.30, 0.35))
	# training mat
	draw_rect(Rect2(760, 300, 160, 120), Color(0.55, 0.22, 0.24))
	_draw_walls(Color(0.82, 0.80, 0.74), Color(0.55, 0.52, 0.48))
	# mirror strip and glass door on the back wall
	draw_rect(Rect2(140, 22, 300, 52), Color(0.70, 0.85, 0.92))
	draw_rect(Rect2(140, 22, 300, 52), Color(0.4, 0.5, 0.6), false, 2.0)
	draw_rect(Rect2(450, 30, 60, 66), Color(0.55, 0.75, 0.85, 0.8))
	draw_rect(Rect2(450, 30, 60, 66), Color(0.3, 0.35, 0.45), false, 2.0)
	# entrance door (bottom-left)
	draw_rect(Rect2(84, ROOM.y - WALL, 72, WALL), Color(0.6, 0.45, 0.3))
