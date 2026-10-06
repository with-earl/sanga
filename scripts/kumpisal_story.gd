class_name KumpisalStory
extends RefCounted
## Reads Kumpisal's words from story/kumpisal.json and picks the version for the current run.
##
## Kumpisal plays differently in each timeline:
## - "main": everyone is in church. After the confessions, Kulas runs and a gunshot is heard.
## - "kumpisal": everyone is in church. Father Eli asks God for forgiveness after the confessions.
## - "padala_police": Mercy and Batista are gone. Batista does not confess.
## - "padala_food": Father Eli asks for forgiveness first. Mercy is gone. The run ends in the
##   Sacrifice ending.

const STORY_FILE := "res://story/kumpisal.json"
## Which way Padala went in the Padala timeline: "police" or "food".
const PADALA_CHAIN_FLAG := "run_padala_chain"


## The version for the current run, for example "padala_food".
static func variant_name() -> String:
	match GameState.timeline:
		"kumpisal":
			return "kumpisal"
		"padala":
			return "padala_%s" % str(GameState.get_flag(PADALA_CHAIN_FLAG, "police"))
	return "main"


## The current version, with its conversations and confessions filled in.
static func load_variant() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Cannot read %s" % STORY_FILE)
		return {}
	var story: Dictionary = parsed
	var variants: Dictionary = story.get("variants", {})
	var name := variant_name()
	var variant: Dictionary = variants.get(name, variants.get("main", {})).duplicate(true)
	var targets: Array = variant.get("targets", [])
	var all_conversations: Dictionary = story.get("conversations", {})
	var conversations := {}
	for key in all_conversations:
		if key in targets:
			conversations[key] = all_conversations[key]
	variant["conversations"] = conversations
	var all_confessions: Dictionary = story.get("confessions", {})
	var confessions: Array = []
	for who in variant.get("confessions", []):
		if all_confessions.has(who):
			confessions.append(all_confessions[who])
	variant["confessions"] = confessions
	return variant
