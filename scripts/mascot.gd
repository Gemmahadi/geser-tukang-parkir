class_name Mascot
extends Control

# Tukang parkir rompi oranye, digambar dari code. Mengangguk saat celebrate=true.

var celebrate: bool = false
var _t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(170, 190)

func _process(delta: float) -> void:
	if celebrate:
		_t += delta
		queue_redraw()

func _draw() -> void:
	var bob: float = sin(_t * 6.0) * 5.0 if celebrate else 0.0
	var cx: float = 85.0
	# kaki
	draw_rect(Rect2(cx - 26, 158, 18, 26), Color("#263238"), true)
	draw_rect(Rect2(cx + 8, 158, 18, 26), Color("#263238"), true)
	# badan: rompi oranye
	var vest := StyleBoxFlat.new()
	vest.bg_color = Color("#ef6c00")
	vest.corner_radius_top_left = 18
	vest.corner_radius_top_right = 18
	vest.corner_radius_bottom_left = 10
	vest.corner_radius_bottom_right = 10
	draw_style_box(vest, Rect2(cx - 48, 78, 96, 84))
	# strip reflektif kuning
	draw_rect(Rect2(cx - 48, 108, 96, 12), Color("#ffd23f"), true)
	draw_rect(Rect2(cx - 48, 132, 96, 8), Color("#ffd23f"), true)
	# lengan menunjuk ke kanan
	var arm_from := Vector2(cx + 40, 96 + bob * 0.3)
	var arm_to := Vector2(cx + 78, 62 + bob)
	draw_line(arm_from, arm_to, Color("#ef6c00"), 13)
	draw_circle(arm_to, 8, Color("#ffe1b0"))
	# kepala
	var head_y: float = 48.0 + bob
	draw_circle(Vector2(cx, head_y), 27, Color("#ffe1b0"))
	# topi
	draw_arc(Vector2(cx, head_y - 4), 27, PI, TAU, 20, Color("#1b3a5c"), 12)
	draw_rect(Rect2(cx - 6, head_y - 32, 40, 8), Color("#1b3a5c"), true)
	# mata + senyum
	draw_circle(Vector2(cx - 10, head_y - 2), 3.2, Color("#22242a"))
	draw_circle(Vector2(cx + 10, head_y - 2), 3.2, Color("#22242a"))
	draw_arc(Vector2(cx, head_y + 6), 11, 0.15 * PI, 0.85 * PI, 14, Color("#22242a"), 2.5)
	# peluit di leher
	draw_circle(Vector2(cx - 8, 82), 6, Color("#e8e8e8"))
