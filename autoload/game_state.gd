extends Node
## Global game state: where the player is in the story, the flags and decisions of this run, the
## endings this save has seen, and the three save slots.
##
## The player always picks a slot before playing, and progress is saved to it automatically: when
## an objective, a story or a timeline is finished, and when the app goes to the background.

signal state_changed
## Emitted after each save. `noticed` is true for saves the player should see a note for.
signal saved(noticed: bool)

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves"
const SAVE_VERSION := 2
const START_LOCATION := "public_market"

var current_slot := -1
var location := START_LOCATION
var flags: Dictionary = {}
var decisions: Array = []

## The timeline being played ("main", "kumpisal" or "padala"), or "" between runs.
var timeline := ""
## Which story of the timeline is being played, counted from 0.
var chapter := 0
## How many runs this save has finished. The first run is the fixed one.
var runs_finished := 0
## Every ending this save has reached, by id.
var endings: Array = []
## The outcomes reached so far in the run being played, in order.
var run_outcomes: Array = []
## Every reality (finished run) this save has made, by TimelineMap key, in the order made.
var realities: Array = []
## Seconds played in this save.
var play_seconds := 0.0


func _process(delta: float) -> void:
	if current_slot >= 0 and timeline != "":
		play_seconds += delta


## Saves when the app is sent to the background or closed, so nothing is lost.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current()


## Starts a new save in the given slot, replacing anything saved there.
func new_game(slot: int) -> void:
	_reset()
	current_slot = slot if _is_valid_slot(slot) else -1
	save_current()
	state_changed.emit()


## Development only: starts a fresh game in memory without touching any save slot.
func start_unsaved_game() -> void:
	_reset()
	current_slot = -1
	state_changed.emit()


func _reset() -> void:
	flags = {}
	decisions = []
	location = START_LOCATION
	timeline = ""
	chapter = 0
	runs_finished = 0
	endings = []
	run_outcomes = []
	realities = []
	play_seconds = 0.0


func has_finished_first_run() -> bool:
	return runs_finished > 0


func is_run_in_progress() -> bool:
	return timeline != ""


func set_location(key: String) -> void:
	location = key
	save_current()


func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value
	state_changed.emit()


func get_flag(flag_name: String, default: Variant = null) -> Variant:
	return flags.get(flag_name, default)


## Removes every flag whose name starts with `prefix`, for example a story's objective progress
## when that story is played again.
func clear_flags(prefix: String) -> void:
	for key in flags.keys():
		if str(key).begins_with(prefix):
			flags.erase(key)


## Records a player decision. Every decision is a branch point in the story.
func record_decision(decision_id: String, choice: String) -> void:
	decisions.append({"id": decision_id, "choice": choice, "location": location})
	flags[decision_id] = choice
	save_current(true)
	state_changed.emit()


func record_ending(ending_id: String) -> void:
	if ending_id == "":
		return
	run_outcomes.append(ending_id)
	if ending_id not in endings:
		endings.append(ending_id)


## Remembers a finished run's reality, once.
func record_reality(key: String) -> void:
	if key != "" and key not in realities:
		realities.append(key)


## Saves to the current slot. `noticed` shows the player a small "Progress saved" note.
func save_current(noticed := false) -> void:
	if current_slot >= 0 and save_to_slot(current_slot):
		saved.emit(noticed)


func save_to_slot(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"location": location,
		"flags": flags,
		"decisions": decisions,
		"timeline": timeline,
		"chapter": chapter,
		"runs_finished": runs_finished,
		"endings": endings,
		"run_outcomes": run_outcomes,
		"realities": realities,
		"play_seconds": play_seconds,
	}
	# Written to a temporary file first, so a crash mid-write never ruins the save.
	var temp_path := slot_path(slot) + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save slot %d: %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	DirAccess.rename_absolute(temp_path, slot_path(slot))
	current_slot = slot
	return true


func load_slot(slot: int) -> bool:
	var data := read_slot(slot)
	if data.is_empty():
		return false
	location = data["location"]
	flags = data["flags"]
	decisions = data["decisions"]
	timeline = data["timeline"]
	chapter = data["chapter"]
	runs_finished = data["runs_finished"]
	endings = data["endings"]
	run_outcomes = data["run_outcomes"]
	realities = data["realities"]
	play_seconds = data["play_seconds"]
	current_slot = slot
	state_changed.emit()
	return true


func delete_slot(slot: int) -> bool:
	if not _is_valid_slot(slot) or not has_slot(slot):
		return false
	var err := DirAccess.remove_absolute(slot_path(slot))
	if err != OK:
		return false
	if current_slot == slot:
		current_slot = -1
	return true


func has_slot(slot: int) -> bool:
	return _is_valid_slot(slot) and FileAccess.file_exists(slot_path(slot))


## Returns the validated save payload, or an empty dictionary when the slot is empty or corrupt.
## Saves from older versions are brought up to date.
func read_slot(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if not (data.get("location") is String and data.get("flags") is Dictionary and data.get("decisions") is Array):
		return {}
	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		return {}
	if version == 1:
		data = _upgrade_from_v1(data)
	if not (data.get("timeline") is String and data.get("endings") is Array):
		return {}
	data["chapter"] = int(data.get("chapter", 0))
	data["runs_finished"] = int(data.get("runs_finished", 0))
	data["play_seconds"] = float(data.get("play_seconds", 0.0))
	# Saves made before realities were recorded simply have none yet.
	for list_key in ["run_outcomes", "realities"]:
		if not data.get(list_key) is Array:
			data[list_key] = []
	return data


## Version 1 saves only knew the location. They were all made during the first run.
func _upgrade_from_v1(data: Dictionary) -> Dictionary:
	var place := str(data["location"])
	data["timeline"] = "main"
	data["chapter"] = {"public_market": 0, "church_nave": 1, "confessional": 1, "apartment_room": 2}.get(place, 0)
	data["runs_finished"] = 0
	data["endings"] = []
	data["play_seconds"] = 0.0
	data["version"] = SAVE_VERSION
	return data


## What a slot holds, for the slot list.
func slot_summary(slot: int) -> Dictionary:
	var data := read_slot(slot)
	if data.is_empty():
		return {"exists": false}
	return {
		"exists": true,
		"location": data["location"],
		"saved_at": str(data.get("saved_at", "")),
		"timeline": data["timeline"],
		"chapter": data["chapter"],
		"runs_finished": data["runs_finished"],
		"endings": data["endings"].size(),
		"play_seconds": data["play_seconds"],
	}


## The slot saved most recently, or -1 when there are no saves.
func latest_slot() -> int:
	var best := -1
	var best_time := ""
	for slot in SLOT_COUNT:
		var info := slot_summary(slot)
		if info["exists"] and str(info["saved_at"]) > best_time:
			best_time = str(info["saved_at"])
			best = slot
	return best


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT
