class_name Alaala
extends RefCounted
## The Alaala (memories): the heart of SANGA's design (see docs/STORY_BIBLE.md).
##
## Every death the player sees becomes an Alaala that the save keeps for good. Holding one does
## two things:
## - It opens one new choice somewhere in the story (an "Alaala choice"), marked with ✦.
## - It can add lines to scenes the player has already seen, so replays reveal more of the truth.
##
## The story files say what needs which Alaala. Any line, cutscene step or choice option can have:
##   "needs": "father_eli"       shown only when the save holds that Alaala
##   "needs_not": "father_eli"   shown only when it does not
##   "if_flag": "run_x"          shown only while that flag of the run is set
##   "unless_flag": "run_x"      shown only while it is not
## A line can also change who speaks once an Alaala is held, for a voice that gets a name:
##   {"speaker": "???", "text": "...", "reveal": {"needs": "father_eli", "speaker": "Batista"}}

const STORY_FILE := "res://story/alaala.json"
## The mark in front of a choice that only a memory made possible.
const MARK := "✦  "
## The line on the card shown when an Alaala is gained.
const GAINED_LINE := "Hindi mo na ito makakalimutan."

static var _all: Array = []


## Every Alaala, in the order of the story file.
static func all() -> Array:
	if _all.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
		if typeof(parsed) == TYPE_DICTIONARY:
			_all = (parsed as Dictionary).get("alaala", [])
		else:
			push_error("Cannot read %s" % STORY_FILE)
	return _all


static func info(id: String) -> Dictionary:
	for item in all():
		if str(item.get("id", "")) == id:
			return item
	return {}


static func has(id: String) -> bool:
	return id in GameState.alaala


## Gives the save every Alaala that `ending_id` teaches and it does not hold yet, and returns
## those new ones.
static func remember_from(ending_id: String) -> Array:
	var gained: Array = []
	if ending_id == "":
		return gained
	for item in all():
		var id := str(item.get("id", ""))
		if ending_id in item.get("from", []) and not has(id):
			GameState.alaala.append(id)
			gained.append(item)
	return gained


## The cutscene card shown for each Alaala just gained.
static func cards_for(gained: Array) -> Array:
	var cards: Array = []
	for item in gained:
		cards.append({"card": str(item.get("name", "")), "line": "%s\n\n%s" % [item.get("memory", ""), GAINED_LINE]})
	return cards


## True when something with "needs" / "needs_not" may be shown with the memories held now.
static func allows(entry: Variant) -> bool:
	if not entry is Dictionary:
		return true
	var data := entry as Dictionary
	if data.has("needs") and not has(str(data["needs"])):
		return false
	if data.has("needs_not") and has(str(data["needs_not"])):
		return false
	if data.has("if_flag") and not GameState.get_flag(str(data["if_flag"]), false):
		return false
	if data.has("unless_flag") and GameState.get_flag(str(data["unless_flag"]), false):
		return false
	return true


## The lines to play: those the memories allow, with revealed speakers named.
static func prepare_lines(lines: Array) -> Array:
	var result: Array = []
	for line in lines:
		if not allows(line):
			continue
		if line is Dictionary and (line as Dictionary).has("reveal"):
			var copy := (line as Dictionary).duplicate()
			var reveal: Dictionary = copy["reveal"]
			if has(str(reveal.get("needs", ""))):
				copy["speaker"] = str(reveal.get("speaker", copy.get("speaker", "")))
			result.append(copy)
		else:
			result.append(line)
	return result


## The options of a choice that may be shown, each with its text ready to display: an Alaala
## choice (one with "needs") starts with the mark. Options can be plain strings.
static func prepare_options(options: Array) -> Array:
	var result: Array = []
	for option in options:
		var data: Dictionary = option if option is Dictionary else {"text": str(option)}
		if not allows(data):
			continue
		var shown := data.duplicate()
		shown["label"] = (MARK if data.has("needs") else "") + str(data.get("text", ""))
		shown["index"] = options.find(option)
		result.append(shown)
	return result


## Does what a picked option asks: sets its flag, so later scenes of this run can react.
static func apply_option(option: Dictionary) -> void:
	if option.has("flag"):
		GameState.set_flag(str(option["flag"]), option.get("value", true))
