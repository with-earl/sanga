extends SceneTree
## Headless smoke test. Run from the project folder:
##   Godot_console.exe --headless --path . --script tests/smoke_test.gd

var _failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	_test_autoloads_loaded()
	_test_scenes_load()
	_test_save_roundtrip()
	_test_art_slot_paths()
	_test_settings()
	_test_save_upgrade()
	_test_story_order()
	_test_choices_fit_one_line()
	_test_one_story()
	_test_run_recap()
	await _test_asset_preloader()
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: ", failure)
		quit(1)


## Every choice must fit on one line, with room for the ✦ of a memory choice, so the options stay
## short and the screen stays balanced.
const CHOICE_ROOM := 560.0
const CHOICE_FONT_SIZE := 26


## One story, three starting points: every order plays each story once, the run always goes on
## around the same circle, and every ending the memories and threads name is a real ending.
func _test_one_story() -> void:
	var director := root.get_node("/root/StoryDirector")
	var circle := ["tokhang", "kumpisal", "padala"]
	for start in director.TIMELINES:
		var order: Array = director.TIMELINES[start]
		_check(order.size() == 3 and circle.all(func(story: String) -> bool: return story in order), "run %s plays each story once" % start)
		for index in order.size():
			_check(order[index] == circle[(circle.find(order[0]) + index) % 3], "run %s goes on around the circle" % start)
	_check(director.is_true_ending(["kumpisal_sinamahan", "padala_pinalaya", "tokhang_safe"]), "nobody dead and Eli confessed is the true ending")
	_check(not director.is_true_ending(["kumpisal_sinamahan", "padala_tanod", "tokhang_safe"]), "Mercy rescued without Eli's confession is not the true ending")
	var endings := {}
	for path in ["res://story/tokhang.json", "res://story/kumpisal.json", "res://story/padala.json"]:
		_collect_ending_ids(JSON.parse_string(FileAccess.get_file_as_string(path)), endings)
	for id in ["kumpisal_kulas", "kumpisal_sinamahan", "padala_tanod"]:
		# Outcomes the scripts give rather than the story files.
		endings[id] = true
	var memories: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://story/alaala.json"))
	for item in memories.get("alaala", []):
		for id in item.get("from", []):
			_check(endings.has(id), "memory %s comes from an ending that exists: %s" % [item.get("id", ""), id])
	var links: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://story/threads.json"))
	for link in links.get("threads", []):
		for end in [link.get("from", {}), link.get("to", {})]:
			for id in end.get("outcome", []):
				_check(endings.has(id), "thread names an ending that exists: %s" % id)


func _collect_ending_ids(data: Variant, found: Dictionary) -> void:
	if data is Dictionary:
		if data.get("id") is String and str(data["id"]).contains("_") and data.has("steps"):
			found[str(data["id"])] = true
		for value in data.values():
			_collect_ending_ids(value, found)
	elif data is Array:
		for value in data:
			_collect_ending_ids(value, found)


## The recap writes only what the run did, and always closes with the same line, so it never
## hints at how many other ways there were.
func _test_run_recap() -> void:
	var recap: GDScript = load("res://scripts/run_recap.gd")
	var run_log := [
		{"story": "Tokhang"},
		{"choice": "Oo."},
		{"ending": "Peter", "line": "Namatay si Peter."},
		{"alaala": "laruang_baril"},
	]
	var lines: Array = recap.call("lines_for", run_log)
	var words: Array = lines.map(func(line: Array) -> String: return str(line[0]))
	_check(words[0] == recap.get("TITLE"), "recap: starts with its title")
	_check(words[-1] == recap.get("CLOSING_LINE"), "recap: ends with the closing line")
	_check(words.has("Tokhang") and words.has("“Oo.”") and words.has("Namatay si Peter."), "recap: writes the story, the choice and the ending")
	_check(lines.size() == 7, "recap: one line per moment, two for a memory")
	# In time order the past comes first, and a choice is joined to its echo and to its ending.
	var played := [
		{"story": "Tokhang"}, {"choice": "Sige. Dadaanan ko na."}, {"ending": "Peter", "line": "Nanlaban daw."}, {"outcome": "tokhang_peter"},
		{"story": "Kumpisal"}, {"choice": "Wala kang dapat ipag-alala, anak.", "flag": "run_echo_mercy_reassured"},
		{"story": "Padala"}, {"echo": "Sabi niya.", "speaker": "Mercy", "flag": "run_echo_mercy_reassured"},
	]
	var threads_script: GDScript = load("res://scripts/time_threads.gd")
	var order: Array = threads_script.call("sections", played).map(func(section: Dictionary) -> String: return section["story"])
	_check(order == ["Kumpisal", "Padala", "Tokhang"], "time order: past, present, future (got %s)" % [order])
	var threads: Array = threads_script.call("threads", played)
	_check([5, 7] in threads, "time order: a choice is joined to its echo")
	_check([1, 2] in threads, "time order: a choice is joined to the ending it caused")
	var empty: Array = recap.call("lines_for", [])
	_check(empty.size() == 2, "recap: an empty run shows only the title and the closing line")


func _test_choices_fit_one_line() -> void:
	var font: Font = load("res://assets/fonts/Lora.ttf")
	for path in ["res://story/tokhang.json", "res://story/kumpisal.json", "res://story/padala.json", "res://story/prologue.json"]:
		var texts: Array[String] = []
		_collect_choice_texts(JSON.parse_string(FileAccess.get_file_as_string(path)), texts)
		for text in texts:
			var width := font.get_string_size("✦  " + text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHOICE_FONT_SIZE).x
			_check(width <= CHOICE_ROOM, "choice too long for one line in %s: %s" % [path.get_file(), text])


func _collect_choice_texts(data: Variant, texts: Array[String]) -> void:
	if data is Dictionary:
		for key in ["choices", "choose", "choice"]:
			if data.get(key) is Array:
				for option in data[key]:
					if option is Dictionary and option.has("text"):
						texts.append(str(option["text"]))
		for value in data.values():
			_collect_choice_texts(value, texts)
	elif data is Array:
		for value in data:
			_collect_choice_texts(value, texts)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_scenes_load() -> void:
	var router := root.get_node("/root/SceneRouter")
	for key in router.SCENES:
		var packed := load(router.SCENES[key]) as PackedScene
		_check(packed != null, "scene fails to load: %s" % key)
		if packed == null:
			continue
		var instance := packed.instantiate()
		_check(instance != null, "scene fails to instantiate: %s" % key)
		if instance:
			instance.free()


func _test_save_roundtrip() -> void:
	var state := root.get_node("/root/GameState")
	var slot: int = state.SLOT_COUNT - 1
	state.delete_slot(slot)
	state.location = "public_market"
	state.flags = {"trusted_gloria": true}
	state.decisions = [{"id": "d1", "choice": "yes", "location": "public_market"}]
	state.run_log = [{"story": "Tokhang"}, {"choice": "Oo."}]
	state.seen_lines = {}
	_check(not state.see_line("Gloria", "Aba, meron, anak!"), "a new line is not seen yet")
	_check(state.see_line("Gloria", "Aba, meron, anak!"), "a line shown before is seen")
	_check(state.save_to_slot(slot), "save_to_slot returns true")
	state.run_log = []
	state.location = "church_nave"
	state.flags = {}
	state.decisions = []
	_check(state.load_slot(slot), "load_slot returns true")
	_check(state.location == "public_market", "location restored")
	_check(state.flags.get("trusted_gloria") == true, "flags restored")
	_check(state.decisions.size() == 1, "decisions restored")
	_check(state.run_log.size() == 2, "run log restored")
	_check(state.seen_lines.size() == 1, "seen lines restored")
	_check(state.delete_slot(slot), "delete_slot returns true")
	_check(not state.has_slot(slot), "slot is gone after delete")
	_check(not state.load_slot(99), "invalid slot is rejected")
	# Story Mode and Shift Mode keep separate slots: a save in one is not in the other.
	state.mode = state.MODE_SHIFT
	_check(not state.has_slot(slot), "shift slot starts empty")
	_check(state.save_to_slot(slot), "shift save written")
	state.mode = state.MODE_STORY
	_check(not state.has_slot(slot), "a shift save is not a story save")
	state.mode = state.MODE_SHIFT
	_check(state.has_finished_first_run(), "shift mode counts as past the first run")
	_check(state.delete_slot(slot), "shift slot deleted")
	state.mode = state.MODE_STORY
	state.current_slot = -1


func _test_art_slot_paths() -> void:
	var slot := ArtSlot.new()
	slot.category = "characters"
	slot.asset_id = "gloria"
	_check(slot.expected_path() == "res://assets/characters/gloria.png", "expected path format")
	slot.free()


func _test_asset_preloader() -> void:
	var preloader := root.get_node("/root/AssetPreloader")
	preloader.start()
	var frames := 0
	while not preloader.poll(0.1) and frames < 900:
		await process_frame
		frames += 1
	_check(frames < 900, "asset preloader finishes")
	_check(preloader.failed.is_empty(), "no asset fails to load: %s" % str(preloader.failed))
	_check(preloader.loaded_count() >= 7, "preloader loads at least every scene")


func _test_settings() -> void:
	var settings := root.get_node("/root/Settings")
	var kept_sound: float = settings.sound_volume
	var kept_music: float = settings.music_volume
	settings.set_sound_volume(0.25)
	settings.set_music_volume(0.5)
	settings.save()
	settings.set_sound_volume(1.0)
	settings.set_music_volume(1.0)
	settings.load_settings()
	_check(is_equal_approx(settings.sound_volume, 0.25), "sound volume survives save and load")
	_check(is_equal_approx(settings.music_volume, 0.5), "music volume survives save and load")
	settings.set_music_volume(0.6)
	_check(is_equal_approx(settings.music_volume, 0.5), "volume snaps to the nearest quarter step")
	_check(AudioServer.get_bus_index("Sound") != -1 and AudioServer.get_bus_index("Music") != -1, "sound and music buses exist")
	settings.set_sound_volume(5.0)
	_check(settings.sound_volume == 1.0, "volume is clamped to 1")
	settings.set_sound_volume(kept_sound)
	settings.set_music_volume(kept_music)
	settings.save()


func _test_autoloads_loaded() -> void:
	for setting in ProjectSettings.get_property_list():
		var name_: String = setting["name"]
		if name_.begins_with("autoload/"):
			var autoload_name := name_.trim_prefix("autoload/")
			_check(root.has_node("/root/" + autoload_name), "autoload loads: %s" % autoload_name)


func _test_save_upgrade() -> void:
	var state := root.get_node("/root/GameState")
	var slot: int = state.SLOT_COUNT - 1
	DirAccess.make_dir_recursive_absolute(state.SAVE_DIR)
	var old := FileAccess.open(state.slot_path(slot), FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 1, "saved_at": "2026-10-04T10:00:00", "location": "church_nave", "flags": {}, "decisions": []}))
	old.close()
	var info: Dictionary = state.slot_summary(slot)
	_check(info["exists"], "a version 1 save still loads")
	_check(info["timeline"] == "main" and int(info["chapter"]) == 1, "a version 1 save in the church becomes a market run at Kumpisal")
	state.delete_slot(slot)
	state.current_slot = -1


func _test_story_order() -> void:
	var director := root.get_node("/root/StoryDirector")
	var state := root.get_node("/root/GameState")
	for timeline in director.TIMELINES:
		for story in director.TIMELINES[timeline]:
			_check(director.STORIES.has(story), "story %s of timeline %s exists" % [story, timeline])
			_check(root.get_node("/root/SceneRouter").SCENES.has(director.STORIES[story]["scene"]), "scene of story %s exists" % story)
	state.start_unsaved_game()
	state.timeline = "main"
	state.chapter = 1
	_check(director.current_story() == "kumpisal", "a run begun at the market plays Kumpisal second")
	_check(director.played_before("tokhang") and not director.played_before("padala"), "a run knows which stories came before")
	state.start_unsaved_game()
