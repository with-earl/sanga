extends SceneTree
## The full playthrough: plays the real game from a fresh save, the way a player would, through
## every ending the timelines chart knows. It taps through dialogue, cutscenes, cards, the recap
## and the chart, taps whatever the idle hint would point at, and picks choices by a plan for each
## run. Each run must finish (nothing gets stuck), and must make exactly the reality the plan
## expects, in order, with the memories the plan expects.
##
## The second run is the true ending, reached the way the story bible says a careful player can:
## right after a first run that ends at the police poster.
##
## Run: godot --headless --path . -s res://tests/playthrough.gd
## It prints PLAYTHROUGH PASSED, or what went wrong and where. It uses the last save slot and
## deletes it afterwards. To read the whole script as it played, set PLAYTHROUGH_TRANSCRIPT to a
## file path: every line, choice and run is written there.

## Faster than real time, so the whole save plays in a minute or two.
const SPEED := 12.0
## A run that takes more frames than this is stuck somewhere.
const MAX_FRAMES_PER_RUN := 20000
## Lines that must never show in a finished story: a conversation not written yet, and the "talk
## to someone first" line, which means the route sent the player to the wrong place.
const PLACEHOLDER_LINES := ["No dialogue yet.", "I must talk to"]
## The mark before a choice that needs a memory (Alaala.MARK; this script cannot name the class
## before the game has loaded).
const MARK := "✦"
## Frames between taps, so each tap lands after the last one has done its work.
const TAP_EVERY := 3

## Each run: which story it begins with, what to prefer at each choice and each thing to tap (the
## first preference found in an option's text or a thing's name wins), things to look at that the
## hint does not point to (tapped once at each step of a place's objectives, the way a curious
## player would), whether to take every ✦ choice, the outcomes the run must make, and the memories
## it must give.
const RUNS := [
	{"name": "first run, police poster", "begin": "tokhang", "prefer": ["Sige, ako", "Police"],
		"expect": ["tokhang_peter", "kumpisal_main", "padala_police_card"], "echoes": 3,
		"gain": ["laruang_baril", "pagtakbo_ni_kulas", "father_eli"]},
	{"name": "true ending", "begin": "tokhang", "prefer": ["Sige, ako"], "look": ["Water Gun"], "alaala": true,
		"expect": ["tokhang_safe", "kumpisal_sinamahan", "padala_walang_namatay"], "gain": []},
	{"name": "Gwen buys, key", "begin": "tokhang", "prefer": ["Ikaw na lang", "Keys", "Dumiretso"],
		"expect": ["tokhang_gwen", "kumpisal_main", "padala_key"], "gain": []},
	{"name": "later, Eli confesses", "begin": "tokhang", "prefer": ["Mamaya", "Ama, aaminin"],
		"expect": ["tokhang_kulas", "kumpisal_main", "padala_pinalaya"], "gain": []},
	{"name": "Kumpisal timeline, run", "begin": "kumpisal", "prefer": ["Keys", "Tumakbo", "Alam ng Diyos"],
		"expect": ["kumpisal_kumpisal", "padala_run"], "gain": ["baril_ni_batista"], "echoes": 3},
	{"name": "Kumpisal timeline, jeep", "begin": "kumpisal", "prefer": ["Keys", "Sumakay", "Dumiretso"],
		"expect": ["kumpisal_kumpisal", "padala_ride_jeep"], "gain": []},
	{"name": "Kumpisal timeline, hide", "begin": "kumpisal", "prefer": ["Keys", "Magtago", "Ano'ng maitutulong", "Ang Diyos lang", "Igalang"],
		"expect": ["kumpisal_kumpisal", "padala_nagtago"], "gain": []},
	{"name": "Kumpisal timeline, Eli confesses", "begin": "kumpisal", "prefer": ["Ama, aaminin", "Keys"],
		"expect": ["kumpisal_kumpisal", "padala_pinalaya"], "gain": []},
	{"name": "Padala timeline, police", "begin": "padala", "prefer": ["Police"],
		"expect": ["padala_police", "kumpisal_padala_police", "tokhang_trade"], "gain": [], "echoes": 1},
	{"name": "Padala timeline, food", "begin": "padala", "prefer": ["Food", "'Yun lang"],
		"expect": ["padala_food", "kumpisal_sacrifice"], "gain": ["rider"]},
	{"name": "Padala timeline, tanod", "begin": "padala", "prefer": ["Food", "Isama po"],
		"expect": ["padala_tanod"], "gain": []},
	{"name": "Padala timeline, Kulas walked out", "begin": "padala", "prefer": ["Food", "'Yun lang", "Sasamahan"],
		"expect": ["padala_food", "kumpisal_sinamahan"], "gain": []},
]

var _failures: Array[String] = []
var _run: Dictionary = {}
var _frame := 0
## What the bot did last, to tell where a stuck run stopped.
var _last_action := ""
var _saw_recap := false
## The things already looked at, as "place:step:name", so each is looked at once per step.
var _looked := {}
## Every line and choice as it played, for PLAYTHROUGH_TRANSCRIPT.
var _transcript := PackedStringArray()
var _last_line := ""


func _initialize() -> void:
	await process_frame
	Engine.time_scale = SPEED
	var state := root.get_node("/root/GameState")
	var director := root.get_node("/root/StoryDirector")
	var slot: int = state.SLOT_COUNT - 1
	state.delete_slot(slot)
	root.get_node("/root/SceneRouter").go_to("main_menu")
	await process_frame
	state.new_game(slot)
	for run in RUNS:
		_run = run
		_saw_recap = false
		_looked = {}
		var memories_before: Array = state.alaala.duplicate()
		var finished_before: int = state.runs_finished
		_transcript.append("\n=== %s ===" % run["name"])
		director.begin_with(str(run["begin"]))
		var frames := 0
		while frames < MAX_FRAMES_PER_RUN and not _back_at_menu(state, finished_before):
			await process_frame
			frames += 1
			_frame += 1
			if _frame % TAP_EVERY == 0:
				_act()
		if frames >= MAX_FRAMES_PER_RUN:
			_fail("stuck after %s (scene %s)" % [_last_action, current_scene.name if current_scene else "none"])
			break
		var outcomes: Array = director.last_reality.get("needs", [])
		var expected: Array = run["expect"]
		if outcomes != expected:
			_fail("made %s, expected %s" % [outcomes, expected])
		var gained: Array = state.alaala.filter(func(id: String) -> bool: return id not in memories_before)
		if gained != run["gain"]:
			_fail("gained memories %s, expected %s" % [gained, run["gain"]])
		if not _saw_recap:
			_fail("the recap did not show")
		var echoes: int = director.last_run_log.filter(func(moment: Dictionary) -> bool: return moment.has("echo")).size()
		if echoes < int(run.get("echoes", 0)):
			_fail("%d echoes came back, expected at least %d" % [echoes, run["echoes"]])
		print("run %-36s %s" % [run["name"], ", ".join(outcomes)])
	var held: int = state.alaala.size()
	if held != 5:
		_failures.append("the save holds %d memories, expected all 5" % held)
	if state.realities.size() != RUNS.size():
		_failures.append("the save holds %d realities, expected %d" % [state.realities.size(), RUNS.size()])
	state.delete_slot(slot)
	Engine.time_scale = 1.0
	var transcript_path := OS.get_environment("PLAYTHROUGH_TRANSCRIPT")
	if transcript_path != "":
		var file := FileAccess.open(transcript_path, FileAccess.WRITE)
		file.store_string("\n".join(_transcript) + "\n")
		file.close()
	if _failures.is_empty():
		print("PLAYTHROUGH PASSED")
	else:
		for failure in _failures:
			printerr("FAILED: " + failure)
		print("PLAYTHROUGH FAILED")
	quit(0 if _failures.is_empty() else 1)


func _fail(message: String) -> void:
	_failures.append("%s: %s" % [_run.get("name", "?"), message])


## The run is over once it has been counted and the player is back on the main screen.
func _back_at_menu(state: Node, finished_before: int) -> bool:
	var card: Node = root.get_node("/root/StoryCard")
	return state.runs_finished > finished_before and current_scene != null \
		and current_scene.scene_file_path.ends_with("main_menu.tscn") and not card.visible


## One tap, wherever the game is waiting for one.
func _act() -> void:
	var card: Node = root.get_node("/root/StoryCard")
	var cutscene: Node = root.get_node("/root/Cutscene")
	for node in root.find_children("*", "DialogueBox", true, false):
		var box: Control = node
		if box.is_visible_in_tree() and box._choosing:
			_pick(box)
			return
	for node in root.find_children("*", "DialogueBox", true, false):
		var box: Control = node
		if box.is_visible_in_tree():
			_last_action = "a dialogue line"
			_note_line(box)
			box.advance()
			return
	if cutscene.visible:
		_last_action = "a cutscene"
		cutscene._tapped = true
		return
	if card.visible:
		if card._waiting_for_tap:
			_last_action = "the time-order card"
			card._waiting_for_tap = false
			card._tapped.emit()
		return
	if current_scene == null:
		return
	var path := current_scene.scene_file_path
	if path.ends_with("run_recap.tscn") or path.ends_with("timeline_reveal.tscn"):
		if path.ends_with("run_recap.tscn"):
			_saw_recap = true
		if current_scene._waiting:
			_last_action = "the recap" if path.ends_with("run_recap.tscn") else "the chart"
			current_scene._gui_input(_click())
		return
	if current_scene.has_method("_hint_slots"):
		_tap_in(current_scene)


## Taps what the idle hint would point at, preferring what this run's plan names.
func _tap_in(place: Control) -> void:
	var slots: Array = place._hint_slots()
	if slots.is_empty():
		return
	for node in place.find_children("*", "ArtSlot", true, false):
		var thing: Control = node
		var seen := "%s:%d:%s" % [place.location_key, place._step, thing.display_name]
		if thing.display_name in _run.get("look", []) and thing.interactive and thing.is_visible_in_tree() and not _looked.has(seen):
			_looked[seen] = true
			_last_action = "looking at %s in %s" % [thing.display_name, place.location_key]
			thing.interacted.emit(thing)
			return
	var names: Array = slots.map(func(slot: Control) -> String: return slot.display_name)
	var slot: Control = slots[_preferred(names)]
	_last_action = "tapping %s in %s" % [slot.display_name, place.location_key]
	slot.interacted.emit(slot)


func _pick(box: Control) -> void:
	var texts: Array = []
	for child in box._choices.get_children():
		if child is Button:
			texts.append((child as Button).text)
	if texts.is_empty():
		return
	var index := _preferred(texts)
	_last_action = "choosing \"%s\"" % texts[index]
	_transcript.append("    > " + "  |  ".join(texts) + "   [picked: %s]" % texts[index])
	box.choice_made.emit(index)


## The first option matching this run's preferences, else a ✦ option on an Alaala run, else the
## first option that is not a ✦ one. In the church, the player talks to everyone unless the run
## says to take the shortcut, so the conversations stay covered.
func _preferred(options: Array) -> int:
	for wanted in _run.get("prefer", []) + ["Kausapin muna"]:
		for index in options.size():
			if str(wanted) in str(options[index]):
				return index
	for index in options.size():
		if str(options[index]).begins_with(MARK) == _run.get("alaala", false):
			return index
	return 0


## Writes down the line on screen once, and fails on a placeholder line.
func _note_line(box: Control) -> void:
	var line := "%s: %s" % [box._speaker.text, box._text.text]
	if line == _last_line or box._text.text == "":
		return
	_last_line = line
	_transcript.append(line)
	for placeholder in PLACEHOLDER_LINES:
		if str(placeholder) in box._text.text:
			_fail("a placeholder line showed: \"%s\"" % line)


func _click() -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 360)
	return click
