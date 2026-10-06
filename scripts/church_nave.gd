class_name ChurchNave
extends Location
## Kumpisal, in the church nave.
##
## Who is in church, the route of objectives and the conversations depend on the timeline, and come
## from story/kumpisal.json (see KumpisalStory). Some versions open with a short cutscene the first
## time the nave is entered.

const OPENING_FLAG := "objective_kumpisal_opening_seen"

var _variant: Dictionary = {}


func _ready() -> void:
	_variant = KumpisalStory.load_variant()
	objectives = PackedStringArray(_variant.get("objectives", []))
	objective_targets = PackedStringArray(_variant.get("targets", []))
	conversations = _variant.get("conversations", {})
	super._ready()
	_leave_only_cast(_variant.get("cast", []))
	var opening: Array = _variant.get("opening", [])
	if not opening.is_empty() and not GameState.get_flag(OPENING_FLAG, false):
		_play_opening.call_deferred(opening)


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
	GameState.save_current()
	await Cutscene.release()
