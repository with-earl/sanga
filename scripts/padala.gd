class_name Padala
extends Location
## Padala, in the apartment.
##
## Opening: Gloria, the luggage, the beating, and the man going for his bath. Then Mercy is alone
## in the room while he bathes, and looks for a way out. What she can do depends on the timeline:
##
## - Main timeline: take the police calling card and use the telephone (Mercy dies), or find the
##   right key among five (Mercy escapes).
## - Kumpisal timeline: find the right key. Each wrong key, Father Eli speaks from the bathroom.
##   Outside, she chooses to run or ride a jeep.
## - Padala timeline: the man is revealed as Father Eli. There are no keys. Mercy takes the police
##   calling card or the food delivery card (taking one puts the other out of reach) and calls.
##   The card she called decides how the rest of the run goes.
##
## The words come from story/padala.json. The right key is picked at random for each run.

const STORY_FILE := "res://story/padala.json"
const KEY_COUNT := 5
const INTRO_FLAG := "objective_padala_intro_seen"
## The name of the card Mercy took, for example "PoliceCard", or "" before she takes one.
const CARD_FLAG := "objective_padala_card_taken"
const RIGHT_KEY_FLAG := "objective_padala_right_key"
const TRIED_FLAG := "objective_padala_tried_keys"

var _story: Dictionary = {}
var _variant: Dictionary = {}
var _variant_name := "main"
var _busy := false


func _ready() -> void:
	_story = _load_story()
	_variant_name = GameState.timeline if _story.get("variants", {}).has(GameState.timeline) else "main"
	_variant = _story["variants"][_variant_name]
	if typeof(GameState.get_flag(CARD_FLAG, "")) == TYPE_BOOL:
		# Saves from before there were two cards kept true for the police card.
		GameState.set_flag(CARD_FLAG, "PoliceCard" if GameState.get_flag(CARD_FLAG, false) else "")
	left_character = "Mercy"
	super._ready()
	# He is in the bath for the whole time Mercy is in the room.
	($Background as ArtSlot).asset_id = "apartment_room_bath"
	if int(GameState.get_flag(RIGHT_KEY_FLAG, 0)) == 0:
		GameState.set_flag(RIGHT_KEY_FLAG, randi_range(1, KEY_COUNT))
	_arrange_room()
	if GameState.get_flag(INTRO_FLAG, false):
		_show_padala_objectives(false)
	else:
		_objectives_panel.set_objectives(PackedStringArray())
		_play_opening.call_deferred()


func _load_story() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Cannot read %s" % STORY_FILE)
		return {}
	return parsed


## Shows only what this timeline uses, and hides what was already taken or tried.
func _arrange_room() -> void:
	var tried: Array = GameState.get_flag(TRIED_FLAG, [])
	var cards: Dictionary = _variant.get("cards", {})
	var nothing_taken := _taken_card() == ""
	for card in ["PoliceCard", "FoodDeliveryCard"]:
		(get_node("Props/" + card) as ArtSlot).visible = cards.has(card) and nothing_taken
	for index in range(1, KEY_COUNT + 1):
		var key_node := get_node("Props/Keys%d" % index) as ArtSlot
		key_node.visible = _variant.get("keys", false) and key_node.name not in tried


func _taken_card() -> String:
	return str(GameState.get_flag(CARD_FLAG, ""))


## The objectives, with the card Mercy took struck through once she has it.
func _show_padala_objectives(animate: bool) -> void:
	var card: Dictionary = _variant.get("cards", {}).get(_taken_card(), {})
	var lines := PackedStringArray()
	var struck := 0
	if not card.is_empty():
		lines.append(str(card["objective"]))
		struck = 1
		lines.append_array(PackedStringArray(_variant["objectives_after_card"]))
	else:
		lines.append_array(PackedStringArray(_variant["objectives"]))
	_objectives_panel.set_objectives(lines, struck, animate, OBJECTIVE_STRIKE_DELAY)


func _play_opening() -> void:
	_busy = true
	await Cutscene.play(_story.get("intro", []) + _variant.get("intro_after", []))
	await Cutscene.release()
	GameState.set_flag(INTRO_FLAG, true)
	GameState.save_current(true)
	_show_padala_objectives(true)
	_busy = false


func _on_slot_interacted(slot: ArtSlot) -> void:
	if _busy or _dialogue.visible or not GameState.get_flag(INTRO_FLAG, false):
		return
	match slot.name:
		"Door":
			await _say_mercy(str(_story.get("locked_door", "")))
		"PoliceCard", "FoodDeliveryCard":
			_take_card(slot)
		"Telephone":
			await _use_telephone()
		_:
			if str(slot.name).begins_with("Keys"):
				await _try_key(slot)


func _hint_names() -> PackedStringArray:
	if _busy or not GameState.get_flag(INTRO_FLAG, false):
		return PackedStringArray()
	if _taken_card() != "":
		return PackedStringArray(["Telephone"])
	var names := PackedStringArray()
	for card in _variant.get("cards", {}):
		names.append((get_node("Props/" + str(card)) as ArtSlot).display_name)
	if _variant.get("keys", false):
		names.append("Keys")
	return names


func _take_card(slot: ArtSlot) -> void:
	GameState.set_flag(CARD_FLAG, str(slot.name))
	_arrange_room()
	GameState.save_current(true)
	_show_padala_objectives(true)


func _use_telephone() -> void:
	var card: Dictionary = _variant.get("cards", {}).get(_taken_card(), {})
	if card.has("call"):
		await _play_ending(str(card["call"]))
	else:
		await _say_mercy(str(_story.get("no_number", "")))


func _try_key(slot: ArtSlot) -> void:
	var index := int(str(slot.name).trim_prefix("Keys"))
	if index == int(GameState.get_flag(RIGHT_KEY_FLAG, 1)):
		await _play_ending(str(_variant["escape"]))
		return
	# A wrong key is put aside, so the search narrows down.
	slot.visible = false
	var tried: Array = GameState.get_flag(TRIED_FLAG, [])
	tried.append(str(slot.name))
	GameState.set_flag(TRIED_FLAG, tried)
	GameState.save_current()
	await _converse(_story.get("wrong_key", {}).get(_variant_name, []), false)


func _say_mercy(text: String) -> void:
	if text != "":
		await _converse([{"speaker": "Mercy", "text": text}], false)


## Plays an ending's cutscene and finishes the story. An ending with a choice in it plays the
## ending that was chosen next.
func _play_ending(key: String) -> void:
	_busy = true
	var ending: Dictionary = _story.get("endings", {}).get(key, {})
	await Cutscene.play(ending.get("steps", []))
	var choices: Array = ending.get("choices", [])
	if not choices.is_empty() and Cutscene.last_choice >= 0:
		ending = _story["endings"].get(choices[Cutscene.last_choice], {})
		await Cutscene.play(ending.get("steps", []))
	if ending.has("chain"):
		# Kumpisal and Tokhang play out differently depending on who Mercy called.
		GameState.set_flag(KumpisalStory.PADALA_CHAIN_FLAG, str(ending["chain"]))
	StoryDirector.finish_story([], str(ending.get("id", "")))
