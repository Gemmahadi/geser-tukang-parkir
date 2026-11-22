class_name StarRow
extends Control

var stars: int = 0
var total: int = 3

func _ready() -> void:
	custom_minimum_size = Vector2(total * 36, 36)

func set_stars(value: int) -> void:
	stars = clampi(value, 0, total)
	queue_redraw()

func _draw() -> void:
	for i in total:
		var c := Vector2(18 + i * 36, 18)
		var col: Color = Color("#ffd23f") if i < stars else Color("#4a5160")
		draw_colored_polygon(_star_points(c, 15.0, 6.5), col)
		draw_arc(c, 15.0, 0, TAU, 24, Color(0, 0, 0, 0.3), 1.5)

func _star_points(center: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var ang: float = -PI / 2.0 + float(i) * PI / 5.0
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	return pts
