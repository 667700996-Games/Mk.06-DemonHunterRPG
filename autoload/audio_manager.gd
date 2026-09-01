extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 20

var sfx_players: Array[AudioStreamPlayer] = []
var pool_cursor := 0
var music_player: AudioStreamPlayer
var cached_sfx: Dictionary = {}
var music_mood := ""
var disabled := false

func _ready() -> void:
	if "--stress-test" in OS.get_cmdline_user_args() or "--loot-stress-test" in OS.get_cmdline_user_args():
		disabled = true
		return
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		sfx_players.append(player)
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)
	_build_sfx()
	Game.settings_changed.connect(apply_volumes)
	apply_volumes()

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	if disabled: return
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null
	for player in sfx_players:
		player.stop()
		player.stream = null
	cached_sfx.clear()

func apply_volumes() -> void:
	if disabled: return
	_set_bus("Master", Game.settings.master_volume)
	_set_bus("Music", Game.settings.music_volume)
	_set_bus("SFX", Game.settings.sfx_volume)
	_set_bus("UI", Game.settings.ui_volume)

func _set_bus(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0: AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))

func play_sfx(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if disabled: return
	var stream: AudioStreamWAV = cached_sfx.get(name, cached_sfx.get("hit"))
	if stream == null: return
	var player := sfx_players[pool_cursor]
	pool_cursor = (pool_cursor + 1) % sfx_players.size()
	player.stop()
	player.stream = stream
	player.bus = &"UI" if name == "ui" else &"SFX"
	player.pitch_scale = pitch * randf_range(0.96, 1.04)
	player.volume_db = volume_db
	player.play()

func play_music(mood: String) -> void:
	if disabled: return
	if music_mood == mood and music_player.playing: return
	music_mood = mood
	var roots := {"menu": 42, "combat": 38, "combat_graveyard": 38, "combat_ruins": 34,
		"combat_abyss": 43, "intense": 34, "boss": 30, "victory": 50}
	music_player.stream = _make_music(int(roots.get(mood, 38)), mood)
	music_player.volume_db = -8.0
	music_player.play()

func _build_sfx() -> void:
	cached_sfx.hit = _make_tone(115.0, 0.055, 0.55, 0.15)
	cached_sfx.critical = _make_tone(460.0, 0.11, 0.7, -0.55)
	cached_sfx.shoot = _make_tone(310.0, 0.045, 0.35, -0.32)
	cached_sfx.dash = _make_tone(180.0, 0.14, 0.55, 0.9)
	cached_sfx.death = _make_tone(88.0, 0.28, 0.65, -0.7)
	cached_sfx.level = _make_tone(520.0, 0.34, 0.48, 0.65)
	cached_sfx.loot = _make_tone(720.0, 0.12, 0.4, 0.38)
	cached_sfx.legendary = _make_tone(880.0, 0.5, 0.55, -0.18)
	cached_sfx.boss = _make_tone(62.0, 0.75, 0.75, -0.2)
	cached_sfx.ui = _make_tone(600.0, 0.045, 0.25, 0.2)
	cached_sfx.hurt = _make_tone(95.0, 0.12, 0.65, -0.1)
	cached_sfx.explode = _make_tone(74.0, 0.22, 0.8, -0.4)

func _make_tone(frequency: float, seconds: float, amplitude: float, sweep: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * seconds)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var envelope := pow(1.0 - float(i) / frames, 1.8)
		var phase := TAU * frequency * t * (1.0 + sweep * t / maxf(seconds, 0.01))
		var wave := sin(phase) * 0.72 + signf(sin(phase * 0.5)) * 0.18
		var sample := int(clampf(wave * envelope * amplitude, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

func _make_music(root_midi: int, mood: String) -> AudioStreamWAV:
	var seconds := 8.0
	var frames := int(SAMPLE_RATE * seconds)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var notes := [0, 3, 7, 10, 7, 3, 12, 10]
	var intensity := 1.4 if mood in ["intense", "boss"] else 1.0
	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var step := int(t * intensity * 2.0) % notes.size()
		var hz := 440.0 * pow(2.0, (root_midi + notes[step] - 69.0) / 12.0)
		var pulse := signf(sin(TAU * hz * t)) * 0.09
		var bass := sin(TAU * (hz * 0.25) * t) * 0.13
		var kick_phase := fmod(t * intensity * 2.0, 1.0)
		var kick := sin(TAU * (52.0 - kick_phase * 22.0) * t) * exp(-kick_phase * 12.0) * 0.17
		var sample := int(clampf(pulse + bass + kick, -0.75, 0.75) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	stream.data = bytes
	return stream
