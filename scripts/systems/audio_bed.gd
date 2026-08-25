class_name AudioBed
extends Node
## One looping district bed. Volume is a bed, not a blast. Fail-soft + headless-safe.

const BED_VOLUME_DB: float = -10.0
const BOOT_KEY := "downtown"

const PATHS: Dictionary = {
	"downtown": "res://assets/city/district_downtown/audio/bed/downtown_day_long.ogg",
	"night": "res://assets/city/district_downtown/audio/bed/downtown_night_long.ogg",
	"park": "res://assets/city/district_park/audio/bed/park_day_long.ogg",
	"waterfront": "res://assets/city/district_waterfront/audio/bed/harbor_day_long.ogg",
	"rail": "res://assets/city/district_rail/audio/bed/rail_day_long.ogg",
}

var _streams: Dictionary = {}  # district key -> AudioStream
var _player: AudioStreamPlayer
var current: String = ""
var failed: PackedStringArray = []
var loaded_count: int = 0


func load_all() -> void:
	_ensure_player()
	_streams.clear()
	failed.clear()
	loaded_count = 0
	for key in PATHS.keys():
		var path: String = String(PATHS[key])
		var stream := _load_stream(path)
		if stream == null:
			failed.append(path)
			push_warning("AudioBed missing: %s" % path)
			continue
		_streams[key] = stream
		loaded_count += 1
	print("AudioBed loaded=%d failed=%d keys=%s" % [loaded_count, failed.size(), str(_streams.keys())])


func play_boot() -> void:
	set_district(BOOT_KEY)


func set_district(district: String) -> void:
	## Mesh/Look can call later: downtown / park / waterfront / rail / night.
	var key := district.strip_edges().to_lower()
	var stream: AudioStream = _streams.get(key, null)
	if stream == null:
		push_warning("AudioBed no stream for '%s'" % key)
		return
	current = key
	if _is_headless():
		return
	_ensure_player()
	if _player.playing and _player.stream == stream:
		return
	_player.stop()
	_player.stream = stream
	_player.volume_db = BED_VOLUME_DB
	_player.play()


func _ensure_player() -> void:
	if _player != null:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "BedPlayer"
	_player.volume_db = BED_VOLUME_DB
	_player.bus = "Master"
	if not _player.finished.is_connected(_on_finished):
		_player.finished.connect(_on_finished)
	add_child(_player)


func _on_finished() -> void:
	if _is_headless():
		return
	if _player != null and _player.stream != null:
		_player.play()


func _load_stream(path: String) -> AudioStream:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is AudioStream:
			stream = res as AudioStream
	if stream == null and FileAccess.file_exists(path) and path.get_extension().to_lower() == "ogg":
		## *_long.ogg may not have a .import remap yet (sidecars are gitignored).
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return null
	_enable_loop(stream)
	return stream


func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


func _is_headless() -> bool:
	if OS.has_feature("headless"):
		return true
	if DisplayServer.get_name() == "headless":
		return true
	return false
