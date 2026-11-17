extends Node
## Tiny synthesized sound effects (no audio assets needed).

const RATE := 22050
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams.flip = _make(0.12, func(t): return _noise() * exp(-t * 40.0) * 0.5 + sin(t * 900.0) * exp(-t * 30.0) * 0.2)
	_streams.place = _make(0.1, func(t): return _noise() * exp(-t * 60.0) * 0.6)
	_streams.whoosh = _make(0.4, func(t): return _noise() * sin(PI * t / 0.4) * 0.35)
	_streams.burn = _make(0.35, func(t): return _noise() * exp(-t * 8.0) * 0.5)
	_streams.bell = _make(1.6, func(t): return (sin(TAU * 523.0 * t) + 0.5 * sin(TAU * 1046.0 * t) + 0.3 * sin(TAU * 1567.0 * t)) * exp(-t * 2.5) * 0.3)
	_streams.coin = _make(0.25, func(t): return sin(TAU * (988.0 if t < 0.08 else 1318.0) * t) * exp(-t * 10.0) * 0.35)
	_streams.win = _make(1.0, func(t): return sin(TAU * [523.0, 659.0, 784.0, 1046.0][mini(int(t / 0.18), 3)] * t) * exp(-fmod(t, 0.18) * 6.0) * 0.3)
	_streams.lose = _make(0.9, func(t): return sin(TAU * [392.0, 330.0, 262.0][mini(int(t / 0.3), 2)] * t) * exp(-fmod(t, 0.3) * 5.0) * 0.3)
	_streams.click = _make(0.05, func(t): return sin(TAU * 1500.0 * t) * exp(-t * 80.0) * 0.3)


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _make(length: float, f: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := clampf(float(f.call(float(i) / RATE)), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = bytes
	return s


func play(name: String) -> void:
	if not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = linear_to_db(float(Profile.data.get("settings", {}).get("volume", 0.8)))
			p.play()
			return
