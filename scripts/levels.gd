class_name Levels
extends RefCounted

# Loader level. Sumber utama: res://levels.json (dibuat solver BFS, 30 level).
# Kalau file belum ada (pengembangan awal), pakai 3 level placeholder di bawah.

const PLACEHOLDER: Array = [
	{
		"name": "Pasar 1 — Kenalan", "theme": "pasar", "par": 2,
		"vehicles": [
			{"id": "P", "type": "player", "len": 2, "dir": "H", "row": 2, "col": 0, "color": "red"},
			{"id": "B", "type": "car", "len": 2, "dir": "V", "row": 2, "col": 3, "color": "blue"},
			{"id": "A", "type": "car", "len": 2, "dir": "V", "row": 0, "col": 3, "color": "yellow"},
			{"id": "C", "type": "car", "len": 2, "dir": "H", "row": 4, "col": 1, "color": "green"},
		],
		"solution": [["B", "D", 2], ["P", "R", 6]],
	},
	{
		"name": "Pasar 2 — Motor Nyelip", "theme": "pasar", "par": 3,
		"vehicles": [
			{"id": "P", "type": "player", "len": 2, "dir": "H", "row": 2, "col": 0, "color": "red"},
			{"id": "A", "type": "car", "len": 2, "dir": "V", "row": 2, "col": 4, "color": "blue"},
			{"id": "B", "type": "car", "len": 2, "dir": "H", "row": 0, "col": 2, "color": "orange"},
			{"id": "C", "type": "motor", "len": 1, "dir": "V", "row": 4, "col": 4, "color": "pink"},
			{"id": "D", "type": "car", "len": 2, "dir": "H", "row": 5, "col": 0, "color": "green"},
		],
		"solution": [["C", "D", 1], ["A", "D", 1], ["P", "R", 6]],
	},
	{
		"name": "Pasar 3 — Angkot Ngalangin", "theme": "pasar", "par": 3,
		"vehicles": [
			{"id": "P", "type": "player", "len": 2, "dir": "H", "row": 2, "col": 0, "color": "red"},
			{"id": "A", "type": "angkot", "len": 3, "dir": "V", "row": 0, "col": 4, "color": "yellow"},
			{"id": "B", "type": "car", "len": 2, "dir": "H", "row": 3, "col": 1, "color": "blue"},
			{"id": "C", "type": "car", "len": 2, "dir": "V", "row": 4, "col": 0, "color": "green"},
			{"id": "D", "type": "motor", "len": 1, "dir": "H", "row": 1, "col": 2, "color": "cyan"},
			{"id": "E", "type": "car", "len": 2, "dir": "H", "row": 5, "col": 3, "color": "purple"},
		],
		"solution": [["E", "L", 2], ["A", "D", 3], ["P", "R", 6]],
	},
]

const THEMES: Array = ["pasar", "terminal", "mal"]
const THEME_NAMES: Dictionary = {
	"pasar": "PASAR", "terminal": "TERMINAL", "mal": "MAL",
}
const THEME_COLORS: Dictionary = {
	"pasar": Color("#2e7d32"), "terminal": Color("#1565c0"), "mal": Color("#6a1b9a"),
}

static func load_all() -> Array:
	if FileAccess.file_exists("res://levels.json"):
		var f := FileAccess.open("res://levels.json", FileAccess.READ)
		if f != null:
			var data: Variant = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_ARRAY and (data as Array).size() >= 3:
				return data
	return PLACEHOLDER.duplicate(true)

static func theme_of(level_idx: int, levels: Array) -> String:
	if level_idx >= 1 and level_idx <= levels.size():
		return str(levels[level_idx - 1].get("theme", "pasar"))
	return "pasar"

static func daily_level_index(total: int) -> int:
	var d: Dictionary = Time.get_date_dict_from_system()
	var doy: int = int(d.get("day", 1))
	var yday: int = 0
	var mdays: Array = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var y: int = int(d.get("year", 2026))
	if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0:
		mdays[1] = 29
	for i in int(d.get("month", 1)) - 1:
		yday += int(mdays[i])
	yday += doy
	return (yday % total) + 1
