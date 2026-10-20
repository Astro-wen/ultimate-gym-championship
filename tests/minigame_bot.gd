class_name MinigameBot
extends RefCounted
## Plays a minigame with perfect-ish inputs, for tests and NPC-free checks.

const DT: float = 1.0 / 60.0


static func play(g: Minigame, max_seconds: float) -> void:
	var t: float = 0.0
	var tap_cd: float = 0.0
	while t < max_seconds and not g.is_finished():
		if g is HoldReleaseGame:
			var h: HoldReleaseGame = g
			if not h.holding:
				h.handle_input(&"interact", true)
			elif h.charge >= (h.zone().x + h.zone().y) * 0.5:
				h.handle_input(&"interact", false)
		elif g is AlternateGame:
			var a: AlternateGame = g
			tap_cd -= DT
			if tap_cd <= 0.0:
				a.handle_input(a.expected, true)
				a.handle_input(a.expected, false)
				tap_cd = 0.3
		elif g is RhythmGame:
			var r: RhythmGame = g
			tap_cd -= DT
			if tap_cd <= 0.0 and r.speed < (r.zone().x + r.zone().y) * 0.5:
				r.handle_input(&"interact", true)
				tap_cd = 0.12
		elif g is TimingGame:
			var tg: TimingGame = g
			var z: Vector2 = tg.zone()
			if tg.phase >= z.x + 0.02 and tg.phase <= z.y - 0.02:
				tg.handle_input(&"interact", true)
		g.tick(DT)
		t += DT
