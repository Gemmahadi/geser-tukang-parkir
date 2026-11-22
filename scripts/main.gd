extends Control

# Geser: Tukang Parkir — GitHub Game Off 2026 (tema SHIFT)
# GEMMA WORKS • Godot 4.3 • portrait 720x1280

const VERSION := "v0.1.0"
const AUTODRIVE_ARG := "--autodrive"

var levels: Array = []
var save: SaveData
var sfx: Sfx

var _current_level: int = 1
var _tab: String = "pasar"
var _screens: Dictionary = {}
var _board: Board
var _moves_label: Label
var _game_title: Label
var _best_stars: StarRow
var _win_stars: StarRow
var _win_info: Label
var _win_mascot: Mascot
var _win_next: Button
var _level_grid: GridContainer
var _tab_buttons: Dictionary = {}
var _sound_label: Button
var _reset_armed: bool = false

func _ready() -> void:
	save = SaveData.new()
	save.load()
	sfx = Sfx.new()
	add_child(sfx)
	sfx.enabled = save.sound_on
	levels = Levels.load_all()
	_build_splash()
	_build_menu()
	_build_level_select()
	_build_game()
	_build_howto()
	_build_settings()
	_build_win_overlay()
	_show("splash")
	print("GAME_READY levels=%d version=%s" % [levels.size(), VERSION])
	if AUTODRIVE_ARG in OS.get_cmdline_user_args():
		_run_autodrive()
	elif "--showlevel" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.3).timeout
		_open_level(1)
		print("SHOWLEVEL_DONE")

# ---------- helpers ----------

func _style_btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	return sb

func _make_button(text: String, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 76)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Color.WHITE)
	if accent:
		b.add_theme_stylebox_override("normal", _style_btn(Color("#ef6c00"), Color("#ff8f00")))
		b.add_theme_stylebox_override("hover", _style_btn(Color("#f57c00"), Color("#ffb74d")))
		b.add_theme_stylebox_override("pressed", _style_btn(Color("#e65100"), Color("#ff8f00")))
	else:
		b.add_theme_stylebox_override("normal", _style_btn(Color("#37474f"), Color("#546e7a")))
		b.add_theme_stylebox_override("hover", _style_btn(Color("#455a64"), Color("#78909c")))
		b.add_theme_stylebox_override("pressed", _style_btn(Color("#263238"), Color("#546e7a")))
	b.add_theme_stylebox_override("disabled", _style_btn(Color("#222a30"), Color("#37474f")))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return b

func _make_label(text: String, font_size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	return l

func _screen(name: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	add_child(c)
	_screens[name] = c
	var bg := ColorRect.new()
	bg.color = Color("#12151c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	return c

func _awning(parent: Control) -> void:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_TOP_WIDE)
	h.add_theme_constant_override("separation", 0)
	parent.add_child(h)
	for i in 18:
		var r := ColorRect.new()
		r.color = Color("#c62828") if i % 2 == 0 else Color("#fafafa")
		r.custom_minimum_size = Vector2(40, 26)
		h.add_child(r)

func _show(name: String) -> void:
	for k in _screens.keys():
		(_screens[k] as Control).visible = (k == name)
	if name == "select":
		_rebuild_level_grid()

# ---------- splash ----------

func _build_splash() -> void:
	var s: Control = _screen("splash")
	var title := _make_label("GEMMA WORKS", 46, Color("#ffd23f"))
	title.position = Vector2(0, 480)
	title.size = Vector2(720, 60)
	s.add_child(title)
	var sub := _make_label("mempersembahkan", 24, Color("#b0bec5"))
	sub.position = Vector2(0, 545)
	sub.size = Vector2(720, 40)
	s.add_child(sub)
	var game := _make_label("GESER: TUKANG PARKIR", 40, Color.WHITE)
	game.position = Vector2(0, 610)
	game.size = Vector2(720, 60)
	s.add_child(game)
	var tap := _make_label("ketuk untuk lanjut", 20, Color("#78909c"))
	tap.position = Vector2(0, 700)
	tap.size = Vector2(720, 30)
	s.add_child(tap)
	s.gui_input.connect(func(_event: InputEvent) -> void:
		if _screens["splash"].visible:
			_show("menu"))
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		if _screens["splash"].visible:
			_show("menu"))

# ---------- menu ----------

func _build_menu() -> void:
	var s: Control = _screen("menu")
	_awning(s)
	var t1 := _make_label("GESER", 92, Color("#ffd23f"))
	t1.position = Vector2(0, 120)
	t1.size = Vector2(720, 110)
	s.add_child(t1)
	var t2 := _make_label("TUKANG PARKIR", 44, Color.WHITE)
	t2.position = Vector2(0, 235)
	t2.size = Vector2(720, 60)
	s.add_child(t2)
	var t3 := _make_label("Puzzle geser mobil • Tema SHIFT", 22, Color("#b0bec5"))
	t3.position = Vector2(0, 300)
	t3.size = Vector2(720, 34)
	s.add_child(t3)
	var m := Mascot.new()
	m.position = Vector2(275, 360)
	s.add_child(m)
	var vb := VBoxContainer.new()
	vb.position = Vector2(80, 580)
	vb.add_theme_constant_override("separation", 16)
	s.add_child(vb)
	var b_main := _make_button("MAIN", true)
	b_main.pressed.connect(func() -> void:
		sfx.play("select")
		_open_level(mini(save.unlocked, levels.size())))
	vb.add_child(b_main)
	var b_select := _make_button("PILIH LEVEL")
	b_select.pressed.connect(func() -> void:
		sfx.play("select")
		_show("select"))
	vb.add_child(b_select)
	var b_daily := _make_button("TANTANGAN HARIAN")
	b_daily.pressed.connect(func() -> void:
		sfx.play("select")
		_open_level(Levels.daily_level_index(levels.size())))
	vb.add_child(b_daily)
	var b_how := _make_button("CARA MAIN")
	b_how.pressed.connect(func() -> void:
		sfx.play("select")
		_show("howto"))
	vb.add_child(b_how)
	var b_set := _make_button("PENGATURAN")
	b_set.pressed.connect(func() -> void:
		sfx.play("select")
		_show("settings"))
	vb.add_child(b_set)
	var ver := _make_label(VERSION + " • GEMMA WORKS • GitHub Game Off 2026", 20, Color("#78909c"))
	ver.position = Vector2(0, 1215)
	ver.size = Vector2(720, 30)
	s.add_child(ver)

# ---------- level select ----------

func _build_level_select() -> void:
	var s: Control = _screen("select")
	var back := _make_button("< KEMBALI")
	back.custom_minimum_size = Vector2(220, 64)
	back.position = Vector2(16, 48)
	back.pressed.connect(func() -> void:
		sfx.play("select")
		_show("menu"))
	s.add_child(back)
	var title := _make_label("PILIH LEVEL", 40, Color.WHITE)
	title.position = Vector2(0, 130)
	title.size = Vector2(720, 56)
	s.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(60, 210)
	tabs.add_theme_constant_override("separation", 12)
	s.add_child(tabs)
	for theme in Levels.THEMES:
		var tb := Button.new()
		tb.text = str(Levels.THEME_NAMES[theme])
		tb.custom_minimum_size = Vector2(192, 64)
		tb.add_theme_font_size_override("font_size", 26)
		tb.toggle_mode = true
		tb.add_theme_stylebox_override("normal", _style_btn(Color("#37474f"), Color("#546e7a")))
		tb.add_theme_stylebox_override("hover", _style_btn(Color("#455a64"), Color("#78909c")))
		tb.add_theme_stylebox_override("pressed", _style_btn(Color("#263238"), Color("#546e7a")))
		var th: String = theme
		tb.pressed.connect(func() -> void:
			sfx.play("select")
			_tab = th
			_update_tabs()
			_rebuild_level_grid())
		tabs.add_child(tb)
		_tab_buttons[theme] = tb
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 300)
	scroll.size = Vector2(640, 920)
	s.add_child(scroll)
	_level_grid = GridContainer.new()
	_level_grid.columns = 2
	_level_grid.add_theme_constant_override("h_separation", 20)
	_level_grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(_level_grid)
	_update_tabs()

func _update_tabs() -> void:
	for theme in _tab_buttons.keys():
		var tb: Button = _tab_buttons[theme]
		tb.button_pressed = (theme == _tab)
		var col: Color = Levels.THEME_COLORS.get(theme, Color("#2e7d32"))
		tb.add_theme_stylebox_override("normal", _style_btn(col if theme == _tab else Color("#37474f"), Color("#546e7a")))

func _rebuild_level_grid() -> void:
	if _level_grid == null:
		return
	for ch in _level_grid.get_children():
		ch.queue_free()
	var start: int = Levels.THEMES.find(_tab) * 10 + 1
	for i in 10:
		var idx: int = start + i
		if idx > levels.size():
			break
		var lv: Dictionary = levels[idx - 1]
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 118)
		b.add_theme_font_size_override("font_size", 28)
		b.text = "Level %d" % idx
		b.add_theme_stylebox_override("normal", _style_btn(Color("#37474f"), Color("#546e7a")))
		b.add_theme_stylebox_override("hover", _style_btn(Color("#455a64"), Color("#78909c")))
		b.add_theme_stylebox_override("pressed", _style_btn(Color("#263238"), Color("#546e7a")))
		b.add_theme_stylebox_override("disabled", _style_btn(Color("#222a30"), Color("#37474f")))
		if idx > save.unlocked:
			b.disabled = true
			b.text = "Level %d\nTerkunci" % idx
		else:
			var sr := StarRow.new()
			sr.position = Vector2(96, 68)
			sr.set_stars(save.get_stars(idx))
			b.add_child(sr)
			var n: int = idx
			b.pressed.connect(func() -> void:
				sfx.play("select")
				_open_level(n))
		_level_grid.add_child(b)

# ---------- game ----------

func _build_game() -> void:
	var s: Control = _screen("game")
	_awning(s)
	var back := _make_button("<")
	back.custom_minimum_size = Vector2(72, 64)
	back.position = Vector2(16, 48)
	back.pressed.connect(func() -> void:
		sfx.play("select")
		_show("select"))
	s.add_child(back)
	_game_title = _make_label("Level 1", 30, Color.WHITE)
	_game_title.position = Vector2(100, 56)
	_game_title.size = Vector2(520, 44)
	s.add_child(_game_title)
	var restart := _make_button("ULANG")
	restart.custom_minimum_size = Vector2(120, 64)
	restart.position = Vector2(584, 48)
	restart.add_theme_font_size_override("font_size", 24)
	restart.pressed.connect(func() -> void:
		sfx.play("click")
		_board.restart()
		_update_moves_label())
	s.add_child(restart)
	_moves_label = _make_label("Langkah: 0 • Par: 0", 28, Color("#ffd23f"))
	_moves_label.position = Vector2(0, 140)
	_moves_label.size = Vector2(720, 40)
	s.add_child(_moves_label)
	_board = Board.new()
	_board.sfx = sfx
	_board.position = Vector2(60, 300)
	_board.moves_changed.connect(func(_m: int) -> void: _update_moves_label())
	_board.level_won.connect(_on_level_won)
	s.add_child(_board)
	var tip := _make_label("Geser mobil MERAH sampai keluar kanan!", 22, Color("#b0bec5"))
	tip.position = Vector2(0, 940)
	tip.size = Vector2(720, 34)
	s.add_child(tip)
	var best_l := _make_label("Terbaik:", 24, Color.WHITE)
	best_l.position = Vector2(180, 1000)
	best_l.size = Vector2(120, 36)
	s.add_child(best_l)
	_best_stars = StarRow.new()
	_best_stars.position = Vector2(310, 1000)
	s.add_child(_best_stars)
	var hint2 := _make_label("Mobil mogok tidak bisa digeser. Motor 1 petak, angkot 3 petak.", 20, Color("#78909c"))
	hint2.position = Vector2(0, 1060)
	hint2.size = Vector2(720, 30)
	s.add_child(hint2)

func _open_level(idx: int) -> void:
	_current_level = clampi(idx, 1, levels.size())
	var lv: Dictionary = levels[_current_level - 1]
	_board.setup(lv)
	var theme_name: String = str(Levels.THEME_NAMES.get(str(lv.get("theme", "pasar")), "PASAR"))
	_game_title.text = "Level %d — %s" % [_current_level, theme_name]
	_best_stars.set_stars(save.get_stars(_current_level))
	_update_moves_label()
	_show("game")

func _update_moves_label() -> void:
	if _board == null or _moves_label == null:
		return
	var par: int = int(_board.level.get("par", 0))
	_moves_label.text = "Langkah: %d • Par: %d" % [_board.moves, par]

func _on_level_won(moves: int) -> void:
	var par: int = int(_board.level.get("par", 0))
	var stars: int = 3 if moves <= par else (2 if moves <= par + 4 else 1)
	save.set_stars(_current_level, stars)
	save.unlock_next(_current_level)
	_best_stars.set_stars(stars)
	_win_stars.set_stars(stars)
	_win_info.text = "Langkah: %d • Par: %d" % [moves, par]
	_win_mascot.celebrate = true
	_win_next.visible = _current_level < levels.size()
	(_screens["win"] as Control).visible = true
	print("LEVEL_WON level=%d moves=%d par=%d stars=%d" % [_current_level, moves, par, stars])

# ---------- win overlay ----------

func _build_win_overlay() -> void:
	var w := Control.new()
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.visible = false
	add_child(w)
	_screens["win"] = w
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(80, 300)
	panel.size = Vector2(560, 660)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("#1c212b")
	psb.border_color = Color("#ffd23f")
	psb.set_border_width_all(3)
	psb.corner_radius_top_left = 20
	psb.corner_radius_top_right = 20
	psb.corner_radius_bottom_left = 20
	psb.corner_radius_bottom_right = 20
	panel.add_theme_stylebox_override("panel", psb)
	w.add_child(panel)
	var title := _make_label("LEVEL SELESAI!", 40, Color("#ffd23f"))
	title.position = Vector2(80, 330)
	title.size = Vector2(560, 56)
	w.add_child(title)
	_win_mascot = Mascot.new()
	_win_mascot.position = Vector2(275, 400)
	w.add_child(_win_mascot)
	_win_stars = StarRow.new()
	_win_stars.position = Vector2(306, 600)
	w.add_child(_win_stars)
	_win_info = _make_label("", 28, Color.WHITE)
	_win_info.position = Vector2(80, 660)
	_win_info.size = Vector2(560, 40)
	w.add_child(_win_info)
	_win_next = _make_button("BERIKUTNYA", true)
	_win_next.position = Vector2(80, 730)
	_win_next.pressed.connect(func() -> void:
		sfx.play("select")
		_win_mascot.celebrate = false
		(_screens["win"] as Control).visible = false
		_open_level(_current_level + 1))
	w.add_child(_win_next)
	var b_retry := _make_button("ULANGI")
	b_retry.position = Vector2(80, 822)
	b_retry.pressed.connect(func() -> void:
		sfx.play("select")
		_win_mascot.celebrate = false
		(_screens["win"] as Control).visible = false
		_board.restart()
		_update_moves_label())
	w.add_child(b_retry)
	var b_menu := _make_button("MENU")
	b_menu.position = Vector2(80, 914)
	b_menu.pressed.connect(func() -> void:
		sfx.play("select")
		_win_mascot.celebrate = false
		(_screens["win"] as Control).visible = false
		_show("menu"))
	w.add_child(b_menu)

# ---------- how to ----------

func _build_howto() -> void:
	var s: Control = _screen("howto")
	var title := _make_label("CARA MAIN", 40, Color.WHITE)
	title.position = Vector2(0, 120)
	title.size = Vector2(720, 56)
	s.add_child(title)
	var lines: Array = [
		"1. Seret mobil, motor, atau angkot",
		"    dengan jari / mouse.",
		"2. Kendaraan hanya bisa geser",
		"    searah jalurnya.",
		"3. Keluarkan mobil MERAH lewat",
		"    jalur KELUAR di kanan.",
		"4. Makin sedikit langkah, makin",
		"    banyak bintang. Par = langkah ideal.",
		"5. Mobil MOGOK tidak bisa digeser.",
		"6. Motor 1 petak, angkot 3 petak.",
		"7. Ada 30 level: Pasar, Terminal, Mal.",
	]
	var body := _make_label("\n".join(lines), 26, Color("#e0e0e0"), HORIZONTAL_ALIGNMENT_LEFT)
	body.position = Vector2(90, 220)
	body.size = Vector2(560, 600)
	s.add_child(body)
	var back := _make_button("KEMBALI")
	back.position = Vector2(80, 980)
	back.pressed.connect(func() -> void:
		sfx.play("select")
		_show("menu"))
	s.add_child(back)

# ---------- settings ----------

func _build_settings() -> void:
	var s: Control = _screen("settings")
	var title := _make_label("PENGATURAN", 40, Color.WHITE)
	title.position = Vector2(0, 120)
	title.size = Vector2(720, 56)
	s.add_child(title)
	_sound_label = _make_button("Suara: ON" if save.sound_on else "Suara: OFF")
	_sound_label.position = Vector2(80, 260)
	_sound_label.pressed.connect(func() -> void:
		save.sound_on = not save.sound_on
		sfx.enabled = save.sound_on
		save.save()
		_sound_label.text = "Suara: ON" if save.sound_on else "Suara: OFF"
		sfx.play("select"))
	s.add_child(_sound_label)
	var reset := _make_button("Hapus Progress")
	reset.position = Vector2(80, 356)
	reset.pressed.connect(func() -> void:
		if not _reset_armed:
			_reset_armed = true
			reset.text = "Yakin? Ketuk lagi untuk hapus"
			return
		save.reset_all()
		_reset_armed = false
		reset.text = "Hapus Progress"
		sfx.play("click"))
	s.add_child(reset)
	var ver := _make_label(VERSION + " • GEMMA WORKS • Game Off 2026", 20, Color("#78909c"))
	ver.position = Vector2(0, 520)
	ver.size = Vector2(720, 30)
	s.add_child(ver)
	var back := _make_button("KEMBALI")
	back.position = Vector2(80, 980)
	back.pressed.connect(func() -> void:
		sfx.play("select")
		_reset_armed = false
		_show("menu"))
	s.add_child(back)

# ---------- autodrive (test) ----------

func _run_autodrive() -> void:
	await get_tree().create_timer(0.3).timeout
	_open_level(1)
	await get_tree().create_timer(0.6).timeout
	var sol: Array = levels[0].get("solution", [])
	await _board.play_solution(sol)
	print("AUTODRIVE_DONE moves=%d won=%s" % [_board.moves, str(_board.is_won())])
