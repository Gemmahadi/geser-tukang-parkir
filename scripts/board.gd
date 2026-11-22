class_name Board
extends Control

signal moves_changed(moves: int)
signal level_won(moves: int)

const GRID := 6
const CELL := 100
const SIZE := 600

var level: Dictionary = {}
var vehicles: Array = []
var moves: int = 0
var input_locked: bool = false
var sfx: Sfx = null

var _won: bool = false
var _exit_label: Label = null

func setup(level_data: Dictionary) -> void:
	level = level_data
	moves = 0
	_won = false
	input_locked = false
	for v in vehicles:
		v.queue_free()
	vehicles.clear()
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	if _exit_label == null:
		_exit_label = Label.new()
		_exit_label.text = "KELUAR"
		_exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_exit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_exit_label.add_theme_font_size_override("font_size", 15)
		_exit_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		add_child(_exit_label)
	_exit_label.position = Vector2(SIZE - CELL, 2 * CELL + 2)
	_exit_label.size = Vector2(CELL, 34)
	for vd in level.get("vehicles", []):
		var v := Vehicle.new()
		v.board = self
		v.cell = CELL
		add_child(v)
		v.setup(vd)
		vehicles.append(v)
	queue_redraw()

func sfx_click() -> void:
	if sfx != null:
		sfx.play("click")

func vehicle_by_id(vid: String) -> Vehicle:
	for v in vehicles:
		if str(v.data.get("id", "")) == vid:
			return v
	return null

func slide_limits(v: Vehicle) -> Vector2i:
	var occ: Array = []
	for r in GRID:
		occ.append([false, false, false, false, false, false])
	for o in vehicles:
		if o == v:
			continue
		for k in o.len_cells():
			if o.axis() == "H":
				occ[o.row][o.head + k] = true
			else:
				occ[o.head + k][o.col] = true
	if v.axis() == "H":
		var r: int = v.row
		var lo: int = v.head
		while lo > 0 and not occ[r][lo - 1]:
			lo -= 1
		var hi: int = v.head
		var max_hi: int = GRID if v.is_player else GRID - v.len_cells()
		while hi < max_hi:
			var nxt: int = hi + v.len_cells()
			if nxt < GRID and occ[r][nxt]:
				break
			hi += 1
		return Vector2i(lo, hi)
	else:
		var c: int = v.col
		var lo: int = v.head
		while lo > 0 and not occ[lo - 1][c]:
			lo -= 1
		var hi: int = v.head
		var max_hi: int = GRID - v.len_cells()
		while hi < max_hi:
			var nxt: int = hi + v.len_cells()
			if nxt < GRID and occ[nxt][c]:
				break
			hi += 1
		return Vector2i(lo, hi)

func vehicle_moved(v: Vehicle, new_head: int) -> void:
	if _won:
		return
	moves += 1
	moves_changed.emit(moves)
	if sfx != null:
		sfx.play("slide")
	if v.is_player and new_head >= GRID:
		_do_win(v)

func _do_win(player: Vehicle) -> void:
	_won = true
	input_locked = true
	if sfx != null:
		sfx.play("win")
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(player, "position:x", SIZE + 40, 0.45)
	await tw.finished
	level_won.emit(moves)

func is_won() -> bool:
	return _won

func restart() -> void:
	setup(level)

func play_solution(solution: Array) -> void:
	input_locked = true
	for step in solution:
		if step.size() < 3:
			continue
		var v: Vehicle = vehicle_by_id(str(step[0]))
		if v == null or v.is_fixed:
			continue
		var d: int = int(step[2])
		var dir_sign: int = 1 if str(step[1]) in ["R", "D"] else -1
		var target: int = v.head + dir_sign * d
		var lim: Vector2i = slide_limits(v)
		target = clampi(target, lim.x, lim.y)
		if target == v.head:
			continue
		var dest: Vector2 = v.position
		if v.axis() == "H":
			dest.x = target * CELL
		else:
			dest.y = target * CELL
		v.head = target
		var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(v, "position", dest, 0.28)
		await tw.finished
		moves += 1
		moves_changed.emit(moves)
		if v.is_player and target >= GRID:
			_do_win(v)
			return
	input_locked = false

func _draw() -> void:
	var theme_col: Color = Levels.THEME_COLORS.get(str(level.get("theme", "pasar")), Color("#2e7d32"))
	# latar aspal
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#2f3542")
	bg.corner_radius_top_left = 18
	bg.corner_radius_top_right = 18
	bg.corner_radius_bottom_left = 18
	bg.corner_radius_bottom_right = 18
	bg.border_color = theme_col
	bg.set_border_width_all(4)
	draw_style_box(bg, Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)))
	# garis parkir kuning putus-putus
	var line_col := Color(1.0, 0.82, 0.25, 0.75)
	for i in range(1, GRID):
		_dashed_line(Vector2(i * CELL, 8), Vector2(i * CELL, SIZE - 8), line_col)
		_dashed_line(Vector2(8, i * CELL), Vector2(SIZE - 8, i * CELL), line_col)
	# zona keluar (baris 2, kolom kanan)
	draw_rect(Rect2(Vector2(SIZE - CELL, 2 * CELL), Vector2(CELL, CELL)), Color(0.2, 0.7, 0.3, 0.35), true)
	var ax: float = SIZE - CELL + 18
	var ay: float = 2 * CELL + CELL * 0.68
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax, ay - 14), Vector2(ax + 26, ay), Vector2(ax, ay + 14)]),
		Color(1, 1, 1, 0.85))
	draw_rect(Rect2(Vector2(ax - 14, ay - 5), Vector2(16, 10)), Color(1, 1, 1, 0.85), true)

func _dashed_line(a: Vector2, b: Vector2, col: Color) -> void:
	var total: float = a.distance_to(b)
	var dir: Vector2 = (b - a).normalized()
	var d: float = 0.0
	while d < total:
		var seg: float = minf(14.0, total - d)
		draw_line(a + dir * d, a + dir * (d + seg), col, 3.0)
		d += 24.0
