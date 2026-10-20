class_name PropBox
extends Node2D
## Placeholder furniture drawn from its bottom edge, so it Y-sorts with actors.

var size: Vector2 = Vector2(48, 48)
var color: Color = Color(0.7, 0.7, 0.72)
## Extra visual height above the collision box (3/4 view).
var height: float = 24.0
var texture: Texture2D
var region: Rect2 = Rect2()


func _draw() -> void:
	if texture != null:
		var s: Vector2 = region.size if region.has_area() else texture.get_size()
		var dst := Rect2(Vector2(-s.x * 0.5, -s.y), s)
		if region.has_area():
			draw_texture_rect_region(texture, dst, region)
		else:
			draw_texture_rect(texture, dst, false)
		return
	var r := Rect2(Vector2(-size.x * 0.5, -size.y - height), Vector2(size.x, size.y + height))
	draw_rect(r, color)
	draw_rect(Rect2(r.position, Vector2(r.size.x, height)), color.lightened(0.15))
	draw_rect(r, Color(0.15, 0.15, 0.2), false, 2.0)
