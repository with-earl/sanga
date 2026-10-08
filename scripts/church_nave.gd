class_name ChurchNave
extends Location
## Kumpisal, in the church nave.
##
## Who is in church, the route of objectives and the conversations come from story/kumpisal.json
## (see KumpisalStory). The story opens with a short cutscene the first time the nave is entered.

const OPENING_FLAG := "objective_kumpisal_opening_seen"
## On a replay where every conversation here was heard before and none of them has changed, Father
## Eli can go straight to the confessional. Offered once per visit to this story.
const SHORTCUT := "Dumiretso sa kumpisalan."
const STAY := "Kausapin muna sila."
const SHORTCUT_FLAG := "objective_kumpisal_shortcut_offered"
const CONFESSIONAL := "confessional"

var _story: Dictionary = {}


func _ready() -> void:
	_story = KumpisalStory.load_story()
	objectives = PackedStringArray(_story.get("objectives", []))
	objective_targets = PackedStringArray(_story.get("targets", []))
	conversations = _story.get("conversations", {})
	super._ready()
	_leave_only_cast(_story.get("cast", []))
	var opening: Array = _story.get("opening", [])
	if not opening.is_empty() and not GameState.get_flag(OPENING_FLAG, false):
		_play_opening.call_deferred(opening)
	else:
		_offer_shortcut.call_deferred()


## Hides everyone who is not in church in this version, with their outline group when it empties.
func _leave_only_cast(cast: Array) -> void:
	for node in find_children("*", "ArtSlot", true, false):
		var slot := node as ArtSlot
		if slot.category == "characters" and slot.display_name not in cast:
			slot.visible = false
	for node in find_children("*", "OutlineGroup", true, false):
		var group := node as OutlineGroup
		var anyone := false
		for child in group.get_children():
			if child is ArtSlot and (child as ArtSlot).visible:
				anyone = true
		group.visible = anyone


func _play_opening(steps: Array) -> void:
	await Cutscene.play(steps)
	GameState.set_flag(OPENING_FLAG, true)
	# Undo stops here: the opening is not played again.
	GameState.checkpoint(true)
	GameState.save_current()
	await Cutscene.release()
	_offer_shortcut()


## Offers to skip the conversations when they hold nothing new for this save.
func _offer_shortcut() -> void:
	if GameState.get_flag(SHORTCUT_FLAG, false) or _step != 0 or not _all_heard():
		return
	GameState.set_flag(SHORTCUT_FLAG, true)
	if await _dialogue.choose([SHORTCUT, STAY]) != 0:
		return
	# Every conversation counts as done; the confessional's step is the route's last one.
	_step = maxi(objective_targets.size() - 1, 0)
	GameState.set_flag(_step_flag(), _step)
	GameState.checkpoint()
	GameState.save_current()
	SceneRouter.go_to(CONFESSIONAL)


## True when every line the conversations here would show now was shown before on this save. For a
## choice, hearing the answer to any one option is enough: the others are only other words.
func _all_heard() -> bool:
	if conversations.is_empty():
		return false
	for key in conversations:
		if not _heard(conversations[key]):
			return false
	return true


func _heard(lines: Array) -> bool:
	for line in Alaala.prepare_lines(lines):
		if not line is Dictionary:
			return false
		var entry: Dictionary = line
		if entry.has("choices"):
			if not Alaala.prepare_options(entry["choices"]).any(func(option: Dictionary) -> bool: return _heard(option.get("after", []))):
				return false
		elif entry.has("text") and not GameState.seen_lines.has(GameState.line_key(str(entry.get("speaker", "")), str(entry["text"]))):
			return false
	return true
