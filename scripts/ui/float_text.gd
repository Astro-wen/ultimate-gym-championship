class_name FloatText
extends Node2D
## Short text that pops up in the world, drifts up and fades ("+4 力量", "漂亮").

var text: String = ""
var color: Color = Color.WHITE
var size: int = 12


static func spawn(parent: Node, at: Vector2, msg: String, col: Color, font_size: int = 12, rise: float = 22.0, secs: float = 0.9) -> FloatText:
	var f := FloatText.new()
	f.text = msg
	f.color = col
	f.size = font_size
	f.position = at
	f.z_index = 20
	f.z_as_relative = false
	parent.add_child(f)
	var tw: Tween = f.create_tween().set_parallel(true)
	tw.tween_property(f, ^"position:y", at.y - rise, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, ^"modulate:a", 0.0, secs * 0.4).set_delay(secs * 0.6)
	tw.chain().tween_callback(f.queue_free)
	return f


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, 3, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size, color)
