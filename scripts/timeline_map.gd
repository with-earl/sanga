class_name TimelineMap
extends RefCounted
## Every reality the stories can make, read from story/timelines.json (the timelines chart).
##
## A reality is one finished run: its timeline and the outcomes reached along the way, for
## example the main timeline where Peter buys the toy and Mercy escapes with the key. Each has a
## path of cards through the diagram. A save remembers which realities it has finished, by key.

const MAP_FILE := "res://story/timelines.json"

static var _map: Dictionary = {}


static func data() -> Dictionary:
	if _map.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Cannot read %s" % MAP_FILE)
			return {}
		_map = parsed
	return _map


## The reality a run made, or an empty dictionary if its outcomes match none.
static func reality_for(timeline: String, outcomes: Array) -> Dictionary:
	for reality in data().get("realities", []):
		if reality.get("timeline", "") != timeline:
			continue
		var matched := true
		for needed in reality.get("needs", []):
			if needed not in outcomes:
				matched = false
				break
		if matched:
			return reality
	return {}


## A reality's lasting name, for example "main:tokhang_peter+padala_key".
static func key_of(reality: Dictionary) -> String:
	if reality.is_empty():
		return ""
	return "%s:%s" % [reality.get("timeline", ""), "+".join(PackedStringArray(reality.get("needs", [])))]


## The realities with these keys, in the chart's order.
static func realities_with(keys: Array) -> Array:
	var found: Array = []
	for reality in data().get("realities", []):
		if key_of(reality) in keys:
			found.append(reality)
	return found
