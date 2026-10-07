class_name DevJump
extends RefCounted
## Development only: points in the game the main screen's "Jump to" menu can open directly,
## without playing from the start. Each point sets up a run as if it had been played up to there
## (the timeline, the story, the outcomes reached before, and the flags a place reads, such as who
## bought the toy gun), then opens the place. Runs started here are never saved to a slot.

## Each group is one timeline. A point names its story's place ("scene"), which story of the
## timeline it is ("chapter", from 0), the outcomes reached before it, and flags to set. A point
## with "confessions" opens the confessional with the confessions about to play.
const GROUPS := [
	{"title": "Main timeline", "points": [
		{"label": "Tokhang: start", "timeline": "main", "chapter": 0, "scene": "public_market"},
		{"label": "Tokhang: Peter is buying", "timeline": "main", "chapter": 0, "scene": "public_market",
			"flags": {"objective_tokhang_buyer": "Peter"}},
		{"label": "Tokhang: Gwen is buying", "timeline": "main", "chapter": 0, "scene": "public_market",
			"flags": {"objective_tokhang_buyer": "Gwen"}},
		{"label": "Kumpisal: start", "timeline": "main", "chapter": 1, "scene": "church_nave",
			"outcomes": ["tokhang_peter"]},
		{"label": "Kumpisal: in the church", "timeline": "main", "chapter": 1, "scene": "church_nave",
			"outcomes": ["tokhang_peter"], "flags": {"objective_kumpisal_opening_seen": true}},
		{"label": "Kumpisal: confessions", "timeline": "main", "chapter": 1, "scene": "confessional",
			"outcomes": ["tokhang_peter"], "confessions": true},
		{"label": "Padala: start", "timeline": "main", "chapter": 2, "scene": "apartment_room",
			"outcomes": ["tokhang_peter", "kumpisal_main"]},
		{"label": "Padala: in the room", "timeline": "main", "chapter": 2, "scene": "apartment_room",
			"outcomes": ["tokhang_peter", "kumpisal_main"], "flags": {"objective_padala_intro_seen": true}},
	]},
	{"title": "Kumpisal timeline", "points": [
		{"label": "Kumpisal: start", "timeline": "kumpisal", "chapter": 0, "scene": "church_nave"},
		{"label": "Kumpisal: in the church", "timeline": "kumpisal", "chapter": 0, "scene": "church_nave",
			"flags": {"objective_kumpisal_opening_seen": true}},
		{"label": "Kumpisal: confessions", "timeline": "kumpisal", "chapter": 0, "scene": "confessional",
			"confessions": true},
		{"label": "Padala: start", "timeline": "kumpisal", "chapter": 1, "scene": "apartment_room",
			"outcomes": ["kumpisal_kumpisal"]},
		{"label": "Padala: in the room", "timeline": "kumpisal", "chapter": 1, "scene": "apartment_room",
			"outcomes": ["kumpisal_kumpisal"], "flags": {"objective_padala_intro_seen": true}},
	]},
	{"title": "Padala timeline", "points": [
		{"label": "Padala: start", "timeline": "padala", "chapter": 0, "scene": "apartment_room"},
		{"label": "Padala: in the room", "timeline": "padala", "chapter": 0, "scene": "apartment_room",
			"flags": {"objective_padala_intro_seen": true}},
		{"label": "Kumpisal after Police: start", "timeline": "padala", "chapter": 1, "scene": "church_nave",
			"outcomes": ["padala_police"], "flags": {"run_padala_chain": "police"}},
		{"label": "Kumpisal after Police: confessions", "timeline": "padala", "chapter": 1, "scene": "confessional",
			"outcomes": ["padala_police"], "flags": {"run_padala_chain": "police"}, "confessions": true},
		{"label": "Kumpisal after Food: start", "timeline": "padala", "chapter": 1, "scene": "church_nave",
			"outcomes": ["padala_food"], "flags": {"run_padala_chain": "food"}},
		{"label": "Kumpisal after Food: confessions", "timeline": "padala", "chapter": 1, "scene": "confessional",
			"outcomes": ["padala_food"], "flags": {"run_padala_chain": "food"}, "confessions": true},
		{"label": "Tokhang after Police: start", "timeline": "padala", "chapter": 2, "scene": "public_market",
			"outcomes": ["padala_police", "kumpisal_padala_police"], "flags": {"run_padala_chain": "police"}},
	]},
]
## Where the church nave keeps its route progress, and the flag that skips its opening.
const NAVE_STEP_FLAG := "objective_step:church_nave"
const KUMPISAL_OPENING_FLAG := "objective_kumpisal_opening_seen"


## Starts an unsaved run set up as `point` describes, and opens its place.
static func jump(point: Dictionary) -> void:
	GameState.start_unsaved_game()
	GameState.timeline = str(point["timeline"])
	GameState.chapter = int(point["chapter"])
	GameState.clear_flags(StoryDirector.RUN_FLAG_PREFIX)
	GameState.clear_flags("objective_")
	GameState.run_outcomes = (point.get("outcomes", []) as Array).duplicate()
	var flags: Dictionary = point.get("flags", {})
	for flag_name in flags:
		GameState.set_flag(flag_name, flags[flag_name])
	if point.get("confessions", false):
		# The church is done: every step of its route but the last ("Go to confessional booth").
		GameState.set_flag(KUMPISAL_OPENING_FLAG, true)
		var targets: Array = KumpisalStory.load_variant().get("targets", [])
		GameState.set_flag(NAVE_STEP_FLAG, maxi(targets.size() - 1, 0))
	var scene := str(point["scene"])
	GameState.location = scene
	GameState.checkpoint(true)
	SceneRouter.go_to(scene)
