class_name SaveData
extends RefCounted

const PATH := "user://save.cfg"

var stars: Dictionary = {}
var unlocked: int = 1
var sound_on: bool = true

func load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	unlocked = int(cfg.get_value("progress", "unlocked", 1))
	sound_on = bool(cfg.get_value("settings", "sound_on", true))
	var raw: String = str(cfg.get_value("progress", "stars", ""))
	if raw != "":
		for part in raw.split(","):
			var kv: PackedStringArray = part.split(":")
			if kv.size() == 2:
				stars[int(kv[0])] = int(kv[1])

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("settings", "sound_on", sound_on)
	var parts: PackedStringArray = []
	for k in stars.keys():
		parts.append(str(k) + ":" + str(stars[k]))
	cfg.set_value("progress", "stars", ",".join(parts))
	cfg.save(PATH)

func get_stars(level_idx: int) -> int:
	return int(stars.get(level_idx, 0))

func set_stars(level_idx: int, value: int) -> void:
	var old: int = get_stars(level_idx)
	if value > old:
		stars[level_idx] = value
		save()

func unlock_next(level_idx: int) -> void:
	if level_idx + 1 > unlocked:
		unlocked = level_idx + 1
		save()

func reset_all() -> void:
	stars.clear()
	unlocked = 1
	save()
