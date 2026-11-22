class_name Sfx
extends Node

const SAMPLE_RATE := 22050

var enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}

func _ready() -> void:
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["click"] = _tone([880.0], 0.06, 0.5)
	_streams["slide"] = _tone([240.0], 0.09, 0.4)
	_streams["select"] = _tone([660.0, 990.0], 0.05, 0.45)
	_streams["win"] = _tone([523.25, 659.25, 783.99, 1046.5], 0.13, 0.5)
	_streams["locked"] = _tone([180.0], 0.12, 0.5)

func play(name: String) -> void:
	if not enabled:
		return
	var stream: AudioStreamWAV = _streams.get(name, null)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()

func _tone(freqs: Array, note_dur: float, volume: float) -> AudioStreamWAV:
	var total: int = int(SAMPLE_RATE * note_dur * freqs.size())
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var note: int = mini(i / int(SAMPLE_RATE * note_dur), freqs.size() - 1)
		var t: float = float(i) / SAMPLE_RATE
		var local: float = fmod(t, note_dur) / note_dur
		var env: float = 1.0 - local
		var s: float = sin(TAU * float(freqs[note]) * t) * env * volume
		var v: int = int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
