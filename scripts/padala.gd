class_name Padala
extends Location
## Padala, in the apartment, Saturday night.
##
## Opening: Gloria, the empty suitcase, the beating, and the man going for his bath. Then Mercy is
## alone in the room while he bathes, and looks for a way out. There are three, the same in every
## run:
##
## - Read the police emergency poster and call: the police come, and the man at the door is their
##   friend. Mercy dies.
## - Take the food delivery flyer and call: a rider comes, sees, and is sent away. Mercy dies, and
##   the rider (Peter) has been seen, which Tokhang remembers if it is played later in the run.
## - Find the right key among five and get out into the street.
##
## Taking one card puts the other out of reach. The words come from story/padala.json. The right
## key is picked at random for each run.
##
## The Alaala choices (see Alaala) are in the story file's cutscenes: asking the rider to bring a
## tanod, and hiding until morning outside. And when Father Eli confessed in Kumpisal earlier in
## this run, the first thing Mercy touches brings him to the door to let her go (Pinalaya).

const STORY_FILE := "res://story/padala.json"
const KEY_COUNT := 5
const INTRO_FLAG := "objective_padala_intro_seen"
## The name of the card Mercy took, for example "PoliceCard", or "" before she takes one.
const CARD_FLAG := "objective_padala_card_taken"
const RIGHT_KEY_FLAG := "objective_padala_right_key"
const TRIED_FLAG := "objective_padala_tried_keys"
## After two wrong keys Mercy notices which key is worn from use, and it catches the light, so the
## search is a little less blind.
const CLUE_AFTER := 2
const WORN_KEY := Color(1.25, 1.15, 0.92)
## Set in Kumpisal this run when Father Eli confessed his own sin.
const ELI_CONFESSED_FLAG := "run_eli_confessed"
## Set when Mercy asked the rider to bring a tanod.
const TANOD_FLAG := "run_tanod"
const TANOD_OUTCOME := "padala_tanod"
## Set for the rest of the run when the rider saw Father Eli at the door and was sent away.
const PETER_SEEN_FLAG := "run_peter_seen"
const FOOD_OUTCOME := "padala_food"

var _story: Dictionary = {}
var _busy := false
## True while a tap is still being handled, including the moment after its dialogue closes, so a
## quick second tap cannot take the other card or try another key before the first is done.
var _handling := false


func _ready() -> void:
	_story = _load_story()
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


## Hides what was already taken or tried.
func _arrange_room() -> void:
	var tried: Array = GameState.get_flag(TRIED_FLAG, [])
	var nothing_taken := _taken_card() == ""
	for card in ["PoliceCard", "FoodDeliveryCard"]:
		var slot := get_node("Props/" + card) as ArtSlot
		if card == "PoliceCard":
			# The police poster is taped to the wall: it stays up once read, but cannot be read twice.
			slot.interactive = nothing_taken
		else:
			slot.visible = nothing_taken
	for index in range(1, KEY_COUNT + 1):
		var key_node := get_node("Props/Keys%d" % index) as ArtSlot
		key_node.visible = key_node.name not in tried
		var worn := tried.size() >= CLUE_AFTER and index == int(GameState.get_flag(RIGHT_KEY_FLAG, 1))
		key_node.self_modulate = WORN_KEY if worn else Color.WHITE


func _taken_card() -> String:
	return str(GameState.get_flag(CARD_FLAG, ""))


## The objectives, with the card Mercy took struck through once she has it.
func _show_padala_objectives(animate: bool) -> void:
	var card: Dictionary = _story.get("cards", {}).get(_taken_card(), {})
	var lines := PackedStringArray()
	var struck := 0
	if not card.is_empty():
		lines.append(str(card["objective"]))
		struck = 1
		lines.append_array(PackedStringArray(_story["objectives_after_card"]))
	else:
		lines.append_array(PackedStringArray(_story["objectives"]))
	_objectives_panel.set_objectives(lines, struck, animate, OBJECTIVE_STRIKE_DELAY)


func _play_opening() -> void:
	_busy = true
	await Cutscene.play(_story.get("intro", []))
	await Cutscene.release()
	GameState.set_flag(INTRO_FLAG, true)
	# Undo stops here: the opening is not played again.
	GameState.checkpoint(true)
	GameState.save_current(true)
	_show_padala_objectives(true)
	_busy = false


func _on_slot_interacted(slot: ArtSlot) -> void:
	if _busy or _handling or _dialogue.visible or not GameState.get_flag(INTRO_FLAG, false):
		return
	_handling = true
	await _handle_tap(slot)
	_handling = false


func _handle_tap(slot: ArtSlot) -> void:
	if GameState.get_flag(ELI_CONFESSED_FLAG, false):
		# He confessed. The door opens before she can do anything.
		await _play_ending("pinalaya")
		return
	match slot.name:
		"Door":
			await _say_mercy(str(_story.get("locked_door", "")))
		"PoliceCard", "FoodDeliveryCard":
			await _take_card(slot)
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
	for card in _story.get("cards", {}):
		names.append((get_node("Props/" + str(card)) as ArtSlot).display_name)
	names.append("Keys")
	return names


func _take_card(slot: ArtSlot) -> void:
	await _say_mercy(str(_story.get("read", {}).get(str(slot.name), "")))
	GameState.set_flag(CARD_FLAG, str(slot.name))
	_arrange_room()
	GameState.checkpoint()
	GameState.save_current(true)
	_show_padala_objectives(true)


func _use_telephone() -> void:
	var card: Dictionary = _story.get("cards", {}).get(_taken_card(), {})
	if card.has("call"):
		await _play_ending(str(card["call"]))
	else:
		await _say_mercy(str(_story.get("no_number", "")))


func _try_key(slot: ArtSlot) -> void:
	var index := int(str(slot.name).trim_prefix("Keys"))
	if index == int(GameState.get_flag(RIGHT_KEY_FLAG, 1)):
		await _play_ending("outside")
		return
	# A wrong key is put aside, so the search narrows down.
	slot.visible = false
	var tried: Array = GameState.get_flag(TRIED_FLAG, [])
	tried.append(str(slot.name))
	GameState.set_flag(TRIED_FLAG, tried)
	GameState.checkpoint()
	GameState.save_current()
	# The first wrong key is heard from the bathroom.
	var lines: Array = _story.get("wrong_key", [])
	if tried.size() == 1:
		lines = lines + _story.get("wrong_key_first", [])
	await _converse(lines, false)
	if tried.size() == CLUE_AFTER:
		_arrange_room()
		await _say_mercy(str(_story.get("worn_key", "")))


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
	var outcome := str(ending.get("id", ""))
	if GameState.get_flag(TANOD_FLAG, false):
		# The rider came back with the tanods, and Father Eli was caught at the door.
		outcome = TANOD_OUTCOME
	elif outcome == FOOD_OUTCOME:
		# Father Eli read the rider's name on the receipt.
		GameState.set_flag(PETER_SEEN_FLAG, true)
	StoryDirector.finish_story([], outcome)
