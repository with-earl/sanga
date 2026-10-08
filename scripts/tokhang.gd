class_name Tokhang
extends Location
## Tokhang, at the public market, Sunday afternoon.
##
## Opening: Peter on his last delivery, the news, then a phone call with Gwen and a choice: Peter
## goes to the market, or (from the second run) Gwen does. At the market the buyer talks to
## Gloria, picks the realistic toy gun, and brings it back to Gloria to pay, which leads to the
## shooting. The words all come from story/tokhang.json.
##
## Tokhang is the latest story in time, so what happened earlier in this run can reach it (the
## story file marks those lines with run flags). The one that changes how it ends: Kulas, walked
## home alive from the church, is at the market and warns the buyer away from the realistic gun.
## That offers the water gun, the same choice the Alaala "Ang Laruang Baril" offers. Settling on
## the water gun leads to the Ligtas ending: nobody is shot.

const STORY_FILE := "res://story/tokhang.json"
## Saved progress: who went to the market, "" until the phone call is over.
const BUYER_FLAG := "objective_tokhang_buyer"
## Which step completes when the right gun is picked, and which is the last one.
const STEP_GLORIA := 0
const STEP_CHOOSE := 1
const STEP_RETURN := 2
## Saved progress: "water" once the buyer settled on the water gun (an Alaala choice).
const GUN_FLAG := "objective_tokhang_gun"
## Set in Kumpisal earlier in this run when Father Eli walked Kulas home.
const KULAS_SAFE_FLAG := "run_kulas_safe"

var _story: Dictionary = {}
var _buyer := ""
var _busy := false
## True while a tap is still being handled, including the moment after its dialogue closes, so a
## quick second tap cannot act on the story before the first one has finished (for example, taking
## the realistic gun right after choosing the water gun).
var _handling := false


func _ready() -> void:
	_story = _load_story()
	objectives = PackedStringArray(_story.get("objectives", []))
	objective_targets = PackedStringArray(["Gloria", "Realistic Toy Gun", "Gloria"])
	super._ready()
	_buyer = str(GameState.get_flag(BUYER_FLAG, ""))
	if _buyer == "":
		# Nothing to do yet: the objectives appear once the phone call is over.
		_objectives_panel.set_objectives(PackedStringArray())
		_play_opening.call_deferred()
	else:
		_set_buyer(_buyer)


func _load_story() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Cannot read %s" % STORY_FILE)
		return {}
	return parsed


## Who is doing the buying from now on: they speak on the left, and the guns they would not
## consider are put out of reach.
func _set_buyer(buyer: String) -> void:
	_buyer = buyer
	left_character = buyer
	var guns: Dictionary = _story.get("guns", {})
	for node in find_children("*", "ArtSlot", true, false):
		var slot := node as ArtSlot
		if guns.has(slot.asset_id):
			var buyers: Array = guns[slot.asset_id].get("buyers", [])
			slot.visible = buyer in buyers
	_show_objectives(false)


func _play_opening() -> void:
	_busy = true
	await Cutscene.play(_story.get("intro", []))
	await Cutscene.release()
	# The phone call: Peter on the left, Gwen (and Ben, when he speaks) on the right.
	left_character = "Peter"
	await _converse(_story.get("phone", []), true)
	var choices: Array = []
	for choice in _story.get("choices", []):
		if not choice.get("after_first_run_only", false) or GameState.has_finished_first_run():
			choices.append(choice)
	# Shown as a choice even when there is only one option, so it reads as Peter's decision.
	var texts: Array = []
	for choice in choices:
		texts.append(choice["text"])
	var picked: Dictionary = choices[await _dialogue.choose(texts)]
	GameState.record_decision("tokhang_errand", str(picked["id"]))
	await _converse(picked.get("after", []), false)
	_busy = false
	var buyer := str(picked.get("buyer", ""))
	GameState.set_flag(BUYER_FLAG, buyer)
	# Undo stops here: the opening and the choice are not played again.
	GameState.checkpoint(true)
	GameState.save_current(true)
	_set_buyer(buyer)


func _hint_names() -> PackedStringArray:
	return PackedStringArray() if _busy or _buyer == "" else super._hint_names()


func _on_slot_interacted(slot: ArtSlot) -> void:
	if _busy or _handling or _dialogue.visible or _buyer == "":
		return
	var guns: Dictionary = _story.get("guns", {})
	_handling = true
	if slot.display_name == "Gloria":
		await _tap_gloria(slot)
	elif guns.has(slot.asset_id):
		await _tap_gun(slot, guns[slot.asset_id])
	_handling = false


func _tap_gloria(slot: ArtSlot) -> void:
	var asking: Array = _story.get("ask_gloria", [])
	match _step:
		STEP_GLORIA:
			_hide_characters(_only_if_character(slot))
			await _converse(_with_buyer(asking), false)
			if GameState.get_flag(KULAS_SAFE_FLAG, false):
				# Kulas, alive, knows who is waiting at the market's exit.
				await _converse(_story.get("kulas_warning", []), false)
			_advance_step()
		STEP_CHOOSE:
			# Gloria repeats where the toys are.
			_hide_characters(_only_if_character(slot))
			await _converse(_with_buyer(asking.slice(1)), false)
		STEP_RETURN:
			_advance_step()
			# Paying: a little haggling, and, for a player who remembers, what Gloria does next.
			_hide_characters(_only_if_character(slot))
			await _converse(_story.get("pay", []), false)
			var safe: bool = GameState.get_flag(GUN_FLAG, "") == "water"
			await _play_outcome("safe" if safe else _buyer.to_lower())


func _tap_gun(slot: ArtSlot, gun: Dictionary) -> void:
	if _step == STEP_GLORIA:
		await _converse([{"speaker": _buyer, "text": _story.get("talk_first", "")}], false)
		return
	var lines: Array = [{"speaker": _buyer, "text": gun.get("text", "")}]
	var picked := [""]
	if _step == STEP_CHOOSE and gun.has("choice") and Alaala.prepare_options(gun["choice"]["choices"]).size() > 1:
		# The choice is offered only when something makes it possible: the memory, or Kulas' warning.
		lines.append(gun["choice"])
	var remember := func(id: String) -> void: picked[0] = id
	_dialogue.line_choice_made.connect(remember)
	await _converse(lines, false)
	_dialogue.line_choice_made.disconnect(remember)
	if _step != STEP_CHOOSE:
		return
	if picked[0] == "water_gun":
		GameState.set_flag(GUN_FLAG, "water")
		_advance_step()
	elif gun.get("chosen", false):
		_advance_step()


## Plays the outcome cutscene for `outcome` ("peter", "gwen" or "safe"), then goes on to the
## next story.
func _play_outcome(outcome: String) -> void:
	_busy = true
	var ending: Dictionary = _story.get("endings", {}).get(outcome, {})
	await Cutscene.play(ending.get("steps", []))
	StoryDirector.finish_story([], str(ending.get("id", "")))


## Lines with "$buyer" as the speaker are spoken by whoever went to the market.
func _with_buyer(lines: Array) -> Array:
	var result: Array = []
	for line in lines:
		var copy: Dictionary = (line as Dictionary).duplicate()
		if copy.get("speaker", "") == "$buyer":
			copy["speaker"] = _buyer
		result.append(copy)
	return result
