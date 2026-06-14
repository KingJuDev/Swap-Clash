extends Node

## Background music manager (autoload). Plays every track found in a folder, one
## after another in shuffled order, looping forever (re-shuffles each pass).
## Discovery is by directory scan, so dropping a new file in the folder is enough.

const BATTLE_DIR := "res://resources/audio/music/Battle"
const AUDIO_EXTENSIONS := ["mp3", "ogg", "wav"]

var _player: AudioStreamPlayer
var _queue: Array[String] = []
var _current_dir := ""
var _last_played := ""

func _ready() -> void:
	randomize()
	# Keep the music going even while the tree is paused (pause popup).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_on_finished)

## Convenience entry point for in-match music.
func play_battle() -> void:
	play_playlist(BATTLE_DIR)

## Starts (or keeps) the shuffled playlist for the given folder.
func play_playlist(dir: String) -> void:
	if dir == _current_dir and _player.playing:
		return
	_current_dir = dir
	_queue = _build_shuffled_queue(dir, _last_played)
	_play_next()

func stop() -> void:
	_current_dir = ""
	_queue.clear()
	_player.stop()

func _play_next() -> void:
	if _current_dir == "":
		return
	if _queue.is_empty():
		_queue = _build_shuffled_queue(_current_dir, _last_played)
	if _queue.is_empty():
		return
	var path: String = _queue.pop_front()
	_last_played = path
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_player.stream = stream
	_player.play()

func _on_finished() -> void:
	_play_next()

## Lists playable audio files in a folder. Handles exported builds where source
## files are listed with a trailing ".import"/".remap" suffix.
func _list_tracks(dir_path: String) -> Array[String]:
	var tracks: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return tracks
	# Dedup: in the editor a folder holds both "foo.mp3" and "foo.mp3.import",
	# which normalise to the same resource path.
	var seen := {}
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var name := file_name
			if name.ends_with(".import") or name.ends_with(".remap"):
				name = name.get_basename()
			if name.get_extension().to_lower() in AUDIO_EXTENSIONS:
				var path := dir_path.path_join(name)
				if not seen.has(path):
					seen[path] = true
					tracks.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return tracks

## Returns the folder's tracks in shuffled order, avoiding starting with
## `avoid_first` (the last track played) when there is more than one track.
func _build_shuffled_queue(dir_path: String, avoid_first: String) -> Array[String]:
	var tracks := _list_tracks(dir_path)
	tracks.shuffle()
	if tracks.size() > 1 and tracks[0] == avoid_first:
		var first: String = tracks.pop_front()
		tracks.append(first)
	return tracks
