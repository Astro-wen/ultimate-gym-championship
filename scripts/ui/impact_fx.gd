class_name ImpactFx
extends Node2D
## One-shot comic impact: radial speed lines, a ring, dust puffs and a word.

var word: String = "砰！"
var t: float = 0.0
var life: float = 0.42
var _seed: int = 0
var _puffs: Array[Vector2] = []


static func spawn(parent: Node, at: Vector2, text: String = "砰！") -> ImpactFx:
	var f := ImpactFx.new()
	f.word = text
	f.position = at
	f.z_index = 30
	f.z_as_relative = false
	parent.add_child(f)
	return f


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_seed = rng.randi()
	for i: int in 6:
		_puffs.append(Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(10.0, 20.0))


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = t / life
	var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
	var a: float = 1.0 - k
	# speed lines
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for i: int in 10:
		var ang: float = TAU * i / 10.0 + rng.randf_range(-0.15, 0.15)
		var dir := Vector2.RIGHT.rotated(ang)
		var r0: float = lerpf(6.0, 20.0, ease_k)
		var r1: float = r0 + lerpf(14.0, 4.0, k) * rng.randf_range(0.7, 1.3)
		draw_line(dir * r0, dir * r1, Color(1.0, 0.95, 0.6, a), 2.0)
	# ring
	draw_arc(Vector2.ZERO, lerpf(4.0, 26.0, ease_k), 0.0, TAU, 24, Color(1, 1, 1, a * 0.9), 2.0)
	# dust
	for p: Vector2 in _puffs:
		draw_circle(p * (0.6 + ease_k), lerpf(4.0, 1.0, k), Color(0.85, 0.82, 0.75, a * 0.8))
	# word: pops big, settles
	var font: Font = ThemeDB.fallback_font
	var size: int = int(lerpf(26.0, 18.0, minf(k * 3.0, 1.0)))
	var pos := Vector2(-40, -26 - 10.0 * ease_k)
	draw_string_outline(font, pos, word, HORIZONTAL_ALIGNMENT_CENTER, 80, size, 5, Color(0.1, 0.05, 0.05, a))
	draw_string(font, pos, word, HORIZONTAL_ALIGNMENT_CENTER, 80, size, Color(1.0, 0.85, 0.25, a))
