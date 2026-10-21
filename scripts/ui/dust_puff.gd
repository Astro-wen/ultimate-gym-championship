class_name DustPuff
extends Node2D
## A small kicked-up dust cloud at the feet (running, landings).

var life: float = 0.4
var t: float = 0.0
var drift: Vector2 = Vector2.ZERO
var size: float = 4.0


static func spawn(parent: Node, at: Vector2, push: Vector2 = Vector2.ZERO, puff_size: float = 4.0) -> void:
	var d := DustPuff.new()
	d.position = at
	d.drift = push
	d.size = puff_size
	parent.add_child(d)


func _process(delta: float) -> void:
	t += delta
	position += drift * delta
	drift *= 0.9
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = t / life
	var a: float = (1.0 - k) * 0.55
	var r: float = size * (0.6 + k)
	var c := Color(0.88, 0.85, 0.78, a)
	draw_circle(Vector2(-r * 0.6, -1.0 - k * 3.0), r * 0.8, c)
	draw_circle(Vector2(r * 0.5, -2.0 - k * 4.0), r * 0.65, c)
	draw_circle(Vector2(0, -k * 2.0), r, c)
