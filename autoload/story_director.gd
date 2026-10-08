extends Node
## Runs the stories in order.
##
## In story time, Kumpisal comes first (the past), then Padala (the present), then Tokhang (the
## future). The main timeline plays them as future, past, present: the market first, so the
## truth about Kumpisal and Padala is revealed the way a player would piece it together.
##
## A timeline is an ordered list of stories (chapters). The first run of a save is always the main
## timeline: Tokhang, then Kumpisal, then Padala. After that, the player chooses which story to
## begin with, and that choice picks the timeline. A timeline must be finished before another can
## be started. Progress is saved automatically at every step.
##
## Scenes ask `variant()` which version of themselves to play, for example the Kumpisal of the
## Padala timeline, which has fewer people in it.

## Each story: the title on its title card and the scene it starts in.
const STORIES := {
	"tokhang": {"title": "Tokhang", "scene": "public_market"},
	"kumpisal": {"title": "Kumpisal", "scene": "church_nave"},
	"padala": {"title": "Padala", "scene": "apartment_room"},
}
## The stories of each timeline, in the order they are played.
const TIMELINES := {
	"main": ["tokhang", "kumpisal", "padala"],
	"kumpisal": ["kumpisal", "padala"],
	"padala": ["padala", "kumpisal", "tokhang"],
}
## Which timeline each story begins when it is chosen first.
const TIMELINE_STARTING_WITH := {"tokhang": "main", "kumpisal": "kumpisal", "padala": "padala"}
## The reality the last finished run made (see TimelineMap), for the timeline reveal.
var last_reality: Dictionary = {}
## What happened in the last finished run, for its recap (see GameState.run_log).
var last_run_log: Array = []
## The timeline the last finished run was on, so its recap knows where to go next.
var last_timeline := ""

const RUN_FLAG_PREFIX := "run_"
## The voice in the dark confessional that opens a run (see docs/STORY_BIBLE.md). The main
## timeline has none: it starts cold in the market, with no hint of what comes after.
const PROLOGUE_FILE := "res://story/prologue.json"


## The story being played now, for example "kumpisal", or "" between runs.
func current_story() -> String:
	if not GameState.is_run_in_progress():
		return ""
	var stories: Array = TIMELINES.get(GameState.timeline, [])
	return stories[GameState.chapter] if GameState.chapter < stories.size() else ""


## Which version of the current story to play: "<timeline>/<story>", for example "padala/kumpisal".
func variant() -> String:
	return "%s/%s" % [GameState.timeline, current_story()]


func story_title(story: String) -> String:
	return STORIES.get(story, {}).get("title", story.capitalize())


## The flag the priest's answer in the prologue sets: the story to begin with.
const START_FLAG := "prologue_start"


## Starts a run after the first the way the story frames it: the voice in the dark confessional
## confesses and asks where to begin, the player answers as the priest, and that answer picks the
## starting story, and so the timeline (see docs/STORY_BIBLE.md, section 6).
func begin_from_confession() -> void:
	var prologue := _prologue()
	var image := str(prologue.get("image", ""))
	GameState.clear_flags(START_FLAG)
	var lines: Array = (prologue.get("lines", []) as Array) + (prologue.get("ask", []) as Array)
	await Cutscene.play([{"image": image, "lines": lines}])
	var story := str(GameState.get_flag(START_FLAG, "tokhang"))
	GameState.clear_flags(START_FLAG)
	var last: Variant = prologue.get("last_line", {}).get(story, null)
	if last != null:
		await Cutscene.play([{"image": image, "lines": [last]}])
	begin_with(story, false)


## The voice's line after any ending but the true one, so the player knows the confession is not
## over, without being told how much is left.
func more_to_tell() -> Dictionary:
	return _prologue().get("more", {})


func _prologue() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROLOGUE_FILE))
	return parsed if parsed is Dictionary else {}


## Starts the timeline that begins with `story` and plays its title card. With `prologue`, a run
## that does not begin in the market first plays the confession that leads into it.
func begin_with(story: String, prologue := true) -> void:
	var timeline: String = TIMELINE_STARTING_WITH.get(story, "main")
	GameState.timeline = timeline
	GameState.chapter = 0
	# Flags starting with "run_" remember choices that shape later stories of this run only.
	GameState.clear_flags(RUN_FLAG_PREFIX)
	GameState.run_outcomes = []
	GameState.run_log = []
	if timeline != "main" and prologue:
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


## Picks up a save where it left off. Between runs there is nothing to resume, so the caller shows
## the story choice instead.
func resume() -> bool:
	if not GameState.is_run_in_progress():
		return false
	SceneRouter.go_to(GameState.location)
	return true


## Called when the current story is finished. Moves to the next story of the timeline, or ends
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


## Ends the run: records its ending and the reality it made on this save, then closes the run
## with its recap, which puts the run in time order (see RunRecap); the other timelines then show
## the timeline diagram of every reality this save has made. `title` and `line` are kept for a
## plain ending card, which no timeline uses now.
func end_run(ending_id: String, title: String, line: String, lead_in: Array = []) -> void:
	GameState.record_ending(ending_id)
	await _remember(ending_id)
	var finished_timeline := GameState.timeline
	last_run_log = GameState.run_log.duplicate(true)
	last_timeline = finished_timeline
	GameState.run_log = []
	last_reality = TimelineMap.reality_for(finished_timeline, GameState.run_outcomes)
	GameState.record_reality(TimelineMap.key_of(last_reality))
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
		# Every run closes with its recap; the recap goes on to the time order or the chart.
		StoryCard.show_ending("", "", lead_in, "run_recap")


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
