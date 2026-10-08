class_name DevJump
extends RefCounted
## Development only: points in the game the developer tools can open directly, without playing
## from the start. Each point sets up a run as if it had been played up to there (where the run
## began, which story of it, the outcomes reached before, and the run flags earlier stories set,
## such as Kulas walked home), then opens the place. Runs started here are never saved to a slot.

## Each group is one section of the developer tools. A point names its story's place ("scene"),
## where the run began ("timeline", as StoryDirector.TIMELINES names it), which story of the run it
## is ("chapter", from 0), the outcomes reached before it, and flags to set. A point with
## "confessions" opens the confessional with the confessions about to play. The first group is the
## start of each story; the second, the stories that react to what came before them in a run.
const GROUPS := [
	{"title": "Start Points", "points": [
		{"label": "Tokhang", "timeline": "main", "chapter": 0, "scene": "public_market"},
		{"label": "Kumpisal", "timeline": "kumpisal", "chapter": 0, "scene": "church_nave"},
		{"label": "Kumpisal Confessions", "timeline": "kumpisal", "chapter": 0, "scene": "confessional",
			"confessions": true},
		{"label": "Padala", "timeline": "padala", "chapter": 0, "scene": "apartment_room"},
	]},
	{"title": "Later In A Run", "points": [
		{"label": "Padala After Eli Confessed", "timeline": "kumpisal", "chapter": 1, "scene": "apartment_room",
			"outcomes": ["kumpisal_kulas"], "flags": {"run_eli_confessed": true}},
		{"label": "Tokhang After Food Delivery", "timeline": "padala", "chapter": 1, "scene": "public_market",
			"outcomes": ["padala_food"], "flags": {"run_peter_seen": true}},
		{"label": "Tokhang With Kulas Alive", "timeline": "kumpisal", "chapter": 2, "scene": "public_market",
			"outcomes": ["kumpisal_sinamahan", "padala_police"], "flags": {"run_kulas_safe": true}},
	]},
]
## Where the church nave keeps its route progress, and the flag that skips its opening.
const NAVE_STEP_FLAG := "objective_step:church_nave"
const KUMPISAL_OPENING_FLAG := "objective_kumpisal_opening_seen"


## Starts an unsaved run set up as `point` describes, and opens its place. Memories (Alaala)
## held when jumping are kept.
static func jump(point: Dictionary) -> void:
	# The memories held now come along, so the Alaala choices can be tested from any point.
	var memories := GameState.alaala.duplicate()
	GameState.start_unsaved_game()
	GameState.alaala = memories
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
		var targets: Array = KumpisalStory.load_story().get("targets", [])
		GameState.set_flag(NAVE_STEP_FLAG, maxi(targets.size() - 1, 0))
	var scene := str(point["scene"])
	GameState.location = scene
	GameState.checkpoint(true)
	SceneRouter.go_to(scene)
