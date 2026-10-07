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
	_test_timelines_chart()
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


## The timelines chart: every path uses real cards, every reality has its own name, and runs land
## on exactly the reality they made (not on one that only shares some of its outcomes).
func _test_timelines_chart() -> void:
	var map_script: GDScript = load("res://scripts/timeline_map.gd")
	var map: Dictionary = map_script.call("data")
	var nodes: Dictionary = map.get("nodes", {})
	var keys := {}
	for reality in map.get("realities", []):
		for id in reality.get("path", []):
			_check(nodes.has(id), "timelines chart: unknown card %s" % id)
		var key: String = map_script.call("key_of", reality)
		_check(not keys.has(key), "timelines chart: two realities named %s" % key)
		keys[key] = true
		var found: Dictionary = map_script.call("reality_for", reality["timeline"], reality["needs"])
		_check(found == reality, "timelines chart: %s matches another reality" % key)
	var mixed: Dictionary = map_script.call("reality_for", "main", ["tokhang_peter", "kumpisal_sinamahan", "padala_key"])
	_check(mixed.get("path", []).has("m_sinamahan"), "timelines chart: a saved Kulas shows on the chart")
	var old: Array = map_script.call("realities_with", ["main:tokhang_peter+padala_key"])
	_check(old.size() == 1, "timelines chart: an older save's reality is still found")


func _test_choices_fit_one_line() -> void:
	var font: Font = load("res://assets/fonts/Lora.ttf")
	for path in ["res://story/tokhang.json", "res://story/kumpisal.json", "res://story/padala.json"]:
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
	_check(state.save_to_slot(slot), "save_to_slot returns true")
	state.location = "church_nave"
	state.flags = {}
	state.decisions = []
	_check(state.load_slot(slot), "load_slot returns true")
	_check(state.location == "public_market", "location restored")
	_check(state.flags.get("trusted_gloria") == true, "flags restored")
	_check(state.decisions.size() == 1, "decisions restored")
	_check(state.delete_slot(slot), "delete_slot returns true")
	_check(not state.has_slot(slot), "slot is gone after delete")
	_check(not state.load_slot(99), "invalid slot is rejected")
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
	_check(info["timeline"] == "main" and int(info["chapter"]) == 1, "a version 1 save in the church becomes the main timeline at Kumpisal")
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
	_check(director.current_story() == "kumpisal" and director.variant() == "main/kumpisal", "main timeline chapter 2 is Kumpisal")
	state.start_unsaved_game()
