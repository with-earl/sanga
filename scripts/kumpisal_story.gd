class_name KumpisalStory
extends RefCounted
## Reads Kumpisal's words from story/kumpisal.json.
##
## Kumpisal is the earliest story in time (Saturday afternoon), so it plays the same in every run:
## everyone is in church, four people confess, and after the confessions Kulas is shot (or walked
## home, with the Alaala choice), Father Eli takes Mercy across the street, and prays.

const STORY_FILE := "res://story/kumpisal.json"


## The story, with only the conversations its route uses and the confessions listed in order.
static func load_story() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Cannot read %s" % STORY_FILE)
		return {}
	var story: Dictionary = parsed
	var targets: Array = story.get("targets", [])
	var all_conversations: Dictionary = story.get("conversations", {})
	var conversations := {}
	for key in all_conversations:
		if key in targets:
			conversations[key] = all_conversations[key]
	story["conversations"] = conversations
	var all_confessions: Dictionary = story.get("confessions", {})
	var confessions: Array = []
	for who in story.get("order", []):
		if all_confessions.has(who):
			confessions.append(all_confessions[who])
	story["confessions"] = confessions
	return story
