extends SceneTree

# Verifies the battle music playlist: folder discovery, shuffle covering all
# tracks, anti back-to-back-repeat, and play/stop bookkeeping.

func _process(_delta: float) -> bool:
	var music: Variant = get_root().get_node("MusicPlayer")
	var dir: String = music.BATTLE_DIR

	# Discovery: both .mp3 tracks found, with clean paths (no .import suffix).
	var tracks: Array = music._list_tracks(dir)
	assert(tracks.size() == 2)
	for path in tracks:
		assert(path.get_extension().to_lower() == "mp3")
		assert(path.begins_with(dir))

	# A shuffled queue contains exactly the same set of tracks.
	var queue: Array = music._build_shuffled_queue(dir, "")
	assert(queue.size() == tracks.size())
	for path in tracks:
		assert(path in queue)

	# Anti-repeat: when avoiding a given track, the queue does not start with it.
	var avoided: String = tracks[0]
	for i in range(20):
		var q: Array = music._build_shuffled_queue(dir, avoided)
		assert(q[0] != avoided)

	# play_battle loads a stream and records the current folder; stop resets.
	music.play_battle()
	assert(music._current_dir == dir)
	assert(music._player.stream != null)
	music.stop()
	assert(music._current_dir == "")
	assert(music._queue.is_empty())

	print("ALL TESTS PASSED")
	quit()
	return true
