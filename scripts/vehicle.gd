class_name Vehicle
extends Control

const COLORS: Dictionary = {
	"red": Color("#e63946"), "blue": Color("#4361ee"), "yellow": Color("#ffb703"),
	"green": Color("#43aa8b"), "orange": Color("#fb8500"), "purple": Color("#7b2cbf"),
	"white": Color("#e9ecef"), "pink": Color("#ff70a6"), "cyan": Color("#48cae4"),
	"brown": Color("#8b5e3c"),
}
const WHEEL := Color("#22242a")
const GLASS := Color("#cfe8ff")

var data: Dictionary = {}
var cell: int = 100
var board: Board = null
var head: int = 0
var row: int = 0
var col: int = 0
var is_player: bool = false
var is_fixed: bool = false

var _grabbed: bool = false
var _grab_point: Vector2 = Vector2.ZERO
var _start_head: int = 0
var _min_head: int = 0
var _max_head: int = 0
var _tween: Tween = null

func axis() -> String:
	return str(data.get("dir", "H"))

func len_cells() -> int:
	return int(data.get("len", 2))

func type_name() -> String:
	return str(data.get("type", "car"))

func setup(d: Dictionary) -> void:
	data = d
	row = int(d.get("row", 0))
	col = int(d.get("col", 0))
	head = col if axis() == "H" else row
	is_player = type_name() == "player"
	is_fixed = type_name() == "mogok"
	var ln: int = len_cells()
	if axis() == "H":
		size = Vector2(ln * cell, cell)
	else:
		size = Vector2(cell, ln * cell)
	_apply_head_pos()
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _apply_head_pos() -> void:
	if axis() == "H":
		position = Vector2(head * cell, row * cell)
	else:
		position = Vector2(col * cell, head * cell)

func _head_px() -> float:
	return position.x if axis() == "H" else position.y

func _gui_input(event: InputEvent) -> void:
	if board == null or board.input_locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if is_fixed:
				_shake()
				return
			_grabbed = true
			_start_head = head
			_grab_point = mb.position
			var lim: Vector2i = board.slide_limits(self)
			_min_head = lim.x
			_max_head = lim.y
			if _tween != null and _tween.is_valid():
				_tween.kill()
			accept_event()
		elif _grabbed:
			_grabbed = false
			_snap()
			accept_event()

func _input(event: InputEvent) -> void:
	if not _grabbed or board == null:
		return
	if event is InputEventMouseMotion:
		var bp: Vector2 = board.get_local_mouse_position()
		var target: float
		if axis() == "H":
			target = clampf(bp.x - _grab_point.x, _min_head * cell, _max_head * cell)
			position.x = target
		else:
			target = clampf(bp.y - _grab_point.y, _min_head * cell, _max_head * cell)
			position.y = target
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_grabbed = false
			_snap()

func _snap() -> void:
	var target: int = clampi(int(round(_head_px() / cell)), _min_head, _max_head)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var dest: Vector2 = position
	if axis() == "H":
		dest.x = target * cell
	else:
		dest.y = target * cell
	_tween.tween_property(self, "position", dest, 0.12)
	if target != _start_head:
		head = target
		board.vehicle_moved(self, target)

func _shake() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var base: Vector2 = position
	_tween = create_tween()
	_tween.tween_property(self, "position", base + Vector2(5, 0), 0.05)
	_tween.tween_property(self, "position", base - Vector2(5, 0), 0.05)
	_tween.tween_property(self, "position", base, 0.05)
	if board != null:
		board.sfx_click()

func _draw() -> void:
	var ln: int = len_cells()
	var body := Rect2(Vector2(5, 5), size - Vector2(10, 10))
	var base_col: Color = COLORS.get(str(data.get("color", "blue")), Color("#4361ee"))
	if is_fixed:
		base_col = base_col.darkened(0.45)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base_col
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.set_border_width_all(2)
	draw_style_box(sb, body)
	if type_name() == "motor":
		_draw_motor(body)
		return
	# kaca depan / jendela
	var win := Rect2()
	if axis() == "H":
		win = Rect2(Vector2(18, 16), Vector2(size.x - 36, 26))
	else:
		win = Rect2(Vector2(16, 18), Vector2(26, size.y - 36))
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = GLASS
	wsb.corner_radius_top_left = 8
	wsb.corner_radius_top_right = 8
	wsb.corner_radius_bottom_left = 8
	wsb.corner_radius_bottom_right = 8
	draw_style_box(wsb, win)
	# garis tengah / strip angkot
	if type_name() == "angkot":
		var stripe := Rect2(Vector2(8, size.y * 0.55), Vector2(size.x - 16, 10)) if axis() == "H" else Rect2(Vector2(size.x * 0.55, 8), Vector2(10, size.y - 16))
		draw_rect(stripe, Color("#ffffff"), true)
	if is_player:
		# papan tanda kuning di atap (taksi tukang parkir)
		var sign := Rect2(Vector2(size.x * 0.5 - 16, 2), Vector2(32, 12)) if axis() == "H" else Rect2(Vector2(2, size.y * 0.5 - 16), Vector2(12, 32))
		draw_rect(sign, Color("#ffd23f"), true)
		draw_rect(sign, Color(0, 0, 0, 0.4), false, 1.5)
	if is_fixed:
		# asap mogok
		draw_circle(Vector2(size.x * 0.3, 14), 7, Color(0.75, 0.75, 0.75, 0.8))
		draw_circle(Vector2(size.x * 0.5, 8), 9, Color(0.8, 0.8, 0.8, 0.7))
		draw_circle(Vector2(size.x * 0.7, 14), 6, Color(0.75, 0.75, 0.75, 0.8))
		# segitiga peringatan
		var cx: float = size.x * 0.5
		var cy: float = size.y * 0.62
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, cy - 12), Vector2(cx + 12, cy + 9), Vector2(cx - 12, cy + 9)]),
			Color("#ffd23f"))
		draw_circle(Vector2(cx, cy + 2), 2.0, Color("#22242a"))
	# roda
	var wpos: Array = []
	if axis() == "H":
		var y1: float = size.y - 8
		var y2: float = 8
		wpos = [Vector2(22, y1), Vector2(size.x - 22, y1), Vector2(22, y2), Vector2(size.x - 22, y2)]
	else:
		var x1: float = 8
		var x2: float = size.x - 8
		wpos = [Vector2(x1, 22), Vector2(x2, 22), Vector2(x1, size.y - 22), Vector2(x2, size.y - 22)]
	for p in wpos:
		draw_circle(p, 9, WHEEL)
		draw_circle(p, 4, Color("#555a66"))
	# lampu depan
	var front: Vector2 = Vector2(size.x - 6, size.y * 0.5) if axis() == "H" else Vector2(size.x * 0.5, size.y - 6)
	draw_circle(front, 5, Color("#fff3b0"))

func _draw_motor(_body: Rect2) -> void:
	# motor 1 sel: dua roda + badan + setang
	var c: Vector2 = size * 0.5
	draw_circle(Vector2(20, size.y - 22), 13, WHEEL)
	draw_circle(Vector2(size.x - 20, size.y - 22), 13, WHEEL)
	draw_circle(Vector2(20, size.y - 22), 5, Color("#888d99"))
	draw_circle(Vector2(size.x - 20, size.y - 22), 5, Color("#888d99"))
	var base_col: Color = COLORS.get(str(data.get("color", "pink")), Color("#ff70a6"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = base_col
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	draw_style_box(sb, Rect2(Vector2(14, size.y * 0.32), Vector2(size.x - 28, 26)))
	draw_line(Vector2(size.x - 22, size.y * 0.34), Vector2(size.x - 8, size.y * 0.2), Color("#22242a"), 4)
	draw_circle(Vector2(size.x * 0.5, size.y * 0.28), 7, Color("#ffe1b0"))
