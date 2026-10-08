extends Node
## Runs the stories in order.
##
## The three stories are one weekend in one parish, the same in every run. In story time Kumpisal
## comes first (Saturday afternoon), then Padala (Saturday night), then Tokhang (Sunday afternoon).
## A run plays all three, beginning with the story the player picks on the start screen and going
## on around the circle: Tokhang, Kumpisal, Padala, Tokhang. Where a run begins only changes what
## the player knows first, and which choices can still reach which story: a cause reaches only
## stories later in story time that are played after it in this run (see docs/STORY_BIBLE.md, R10).
##
## The first run of a save always begins with Tokhang, with no prologue. Progress is saved
## automatically at every step.

## Each story: the title on its title card and the scene it starts in.
const STORIES := {
	"tokhang": {"title": "Tokhang", "scene": "public_market"},
	"kumpisal": {"title": "Kumpisal", "scene": "church_nave"},
	"padala": {"title": "Padala", "scene": "apartment_room"},
}
## The order a run plays the stories in, by where it begins. The keys are the names saves already
## use: "main" is the run that begins at the market.
const TIMELINES := {
	"main": ["tokhang", "kumpisal", "padala"],
	"kumpisal": ["kumpisal", "padala", "tokhang"],
	"padala": ["padala", "tokhang", "kumpisal"],
}
## Which order each story begins when it is picked first.
const TIMELINE_STARTING_WITH := {"tokhang": "main", "kumpisal": "kumpisal", "padala": "padala"}
## The true ending: nobody dies at the church, in the room or at the market, and Father Eli
## confessed. It is recorded as one more outcome of the run.
const TRUE_ENDING := "walang_namatay"
const TRUE_ENDING_NEEDS := ["kumpisal_sinamahan", "padala_pinalaya", "tokhang_safe"]
## The outcomes of the last finished run, in the order they were reached, for its recap.
var last_outcomes: Array = []
## What happened in the last finished run, for its recap (see GameState.run_log).
var last_run_log: Array = []

const RUN_FLAG_PREFIX := "run_"
## The voice in the dark confessional that opens every run after the first, and the true
## ending's epilogue (see docs/STORY_BIBLE.md).
const PROLOGUE_FILE := "res://story/prologue.json"


## The story being played now, for example "kumpisal", or "" between runs.
func current_story() -> String:
	if not GameState.is_run_in_progress():
		return ""
	var stories: Array = TIMELINES.get(GameState.timeline, [])
	return stories[GameState.chapter] if GameState.chapter < stories.size() else ""


func story_title(story: String) -> String:
	return STORIES.get(story, {}).get("title", story.capitalize())


## The voice's line after any ending but the true one, so the player knows the confession is not
## over, without being told how much is left.
func more_to_tell() -> Dictionary:
	return _prologue().get("more", {})


func _prologue() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROLOGUE_FILE))
	return parsed if parsed is Dictionary else {}


## Starts a run that begins with `story` and plays its title card. With `prologue`, every run
## after the first opens with the voice in the confessional, beginning where the player chose.
func begin_with(story: String, prologue := true) -> void:
	var timeline: String = TIMELINE_STARTING_WITH.get(story, "main")
	GameState.timeline = timeline
	GameState.chapter = 0
	# Flags starting with "run_" remember choices that shape later stories of this run only.
	GameState.clear_flags(RUN_FLAG_PREFIX)
	GameState.run_outcomes = []
	GameState.run_log = []
	if prologue and GameState.has_finished_first_run():
		await Cutscene.play(_prologue_for(story))
	_enter_chapter([])


## The prologue for a run that begins with `story`: the same confession each time, ending on where
## the voice decides to start.
func _prologue_for(story: String) -> Array:
	var prologue := _prologue()
	if prologue.is_empty():
		return []
	var lines: Array = (prologue.get("lines", []) as Array).duplicate()
	var last: Variant = prologue.get("last_line", {}).get(story, null)
	if last != null:
		lines.append(last)
	return [{"image": str(prologue.get("image", "")), "lines": lines}]


## Picks up a save where it left off. Between runs there is nothing to resume.
func resume() -> bool:
	if not GameState.is_run_in_progress():
		return false
	SceneRouter.go_to(GameState.location)
	return true


## Called when the current story is finished. Moves to the next story of the run, or ends
## the run after the last one. `lead_in` is an optional list of pictures played before the next
## title card, for example the cutscene that closes this story.
func finish_story(lead_in: Array = [], outcome_id := "") -> void:
	GameState.record_ending(outcome_id)
	await _remember(outcome_id)
	GameState.chapter += 1
	if GameState.chapter >= TIMELINES.get(GameState.timeline, []).size():
		end_run("", "", "", lead_in)
		return
	_enter_chapter(lead_in)


## Ends the run: plays the true ending if the run earned it, records the run's outcomes on this
## save, then closes the run with its recap, which puts the run in time order (see RunRecap).
## `title` and `line` are kept for a plain ending card, which no run uses now.
func end_run(ending_id: String, title: String, line: String, lead_in: Array = []) -> void:
	GameState.record_ending(ending_id)
	await _remember(ending_id)
	if is_true_ending(GameState.run_outcomes):
		if Cutscene.visible:
			Cutscene.hand_over()
		await Cutscene.play(_prologue().get("epilogue", []))
		GameState.record_ending(TRUE_ENDING)
	last_run_log = GameState.run_log.duplicate(true)
	last_outcomes = GameState.run_outcomes.duplicate()
	GameState.run_log = []
	GameState.record_reality("%s:%s" % [GameState.timeline, "+".join(PackedStringArray(last_outcomes))])
	GameState.run_outcomes = []
	GameState.runs_finished += 1
	GameState.timeline = ""
	GameState.chapter = 0
	GameState.location = "main_menu"
	GameState.clear_flags("objective_")
	GameState.clear_flags(RUN_FLAG_PREFIX)
	GameState.checkpoint(true)
	GameState.save_current(true)
	if Cutscene.visible:
		Cutscene.hand_over()
	if title != "":
		StoryCard.show_ending(title, line, lead_in)
	else:
		# Every run closes with its recap.
		StoryCard.show_ending("", "", lead_in, "run_recap")


## True when these outcomes make the true ending (and it has not been recorded yet).
func is_true_ending(outcomes: Array) -> bool:
	if TRUE_ENDING in outcomes:
		return false
	for needed in TRUE_ENDING_NEEDS:
		if needed not in outcomes:
			return false
	return true


## True when `story` was already played earlier in the run in progress, so what happened there can
## reach the story being played now.
func played_before(story: String) -> bool:
	var stories: Array = TIMELINES.get(GameState.timeline, [])
	var index := stories.find(story)
	return index >= 0 and index < GameState.chapter


## A death the player has seen for the first time becomes an Alaala: it is saved at once, and a
## card names it before the story moves on.
func _remember(ending_id: String) -> void:
	var gained := Alaala.remember_from(ending_id)
	if gained.is_empty():
		return
	for item in gained:
		GameState.log_moment({"alaala": str(item.get("id", ""))})
	GameState.save_current()
	await Cutscene.play(Alaala.cards_for(gained))


func _enter_chapter(lead_in: Array) -> void:
	if Cutscene.visible:
		Cutscene.hand_over()
	var story := current_story()
	var info: Dictionary = STORIES[story]
	GameState.log_moment({"story": str(info["title"])})
	# Each story starts fresh, even if it was played before in another run.
	GameState.clear_flags("objective_")
	GameState.location = info["scene"]
	# Undo never reaches back into the story before.
	GameState.checkpoint(true)
	GameState.save_current(true)
	StoryCard.start(info["title"], info["scene"], lead_in)
