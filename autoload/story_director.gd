extends Node
## Runs the stories in order.
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

## Story order shown to the player when choosing where to begin.
const STORY_ORDER := ["tokhang", "kumpisal", "padala"]
const RUN_FLAG_PREFIX := "run_"


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


## Starts the timeline that begins with `story` and plays its title card.
func begin_with(story: String) -> void:
	var timeline: String = TIMELINE_STARTING_WITH.get(story, "main")
	GameState.timeline = timeline
	GameState.chapter = 0
	# Flags starting with "run_" remember choices that shape later stories of this run only.
	GameState.clear_flags(RUN_FLAG_PREFIX)
	GameState.run_outcomes = []
	_enter_chapter([])


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
	GameState.chapter += 1
	if GameState.chapter >= TIMELINES.get(GameState.timeline, []).size():
		end_run("", "", "", lead_in)
		return
	_enter_chapter(lead_in)


## Ends the run: records its ending and the reality it made on this save, then closes the run.
## The main timeline closes by showing when each story happens; the other timelines close with
## the timeline diagram of every reality this save has made. `title` and `line` are kept for a
## plain ending card, which no timeline uses now.
func end_run(ending_id: String, title: String, line: String, lead_in: Array = []) -> void:
	GameState.record_ending(ending_id)
	var finished_timeline := GameState.timeline
	last_reality = TimelineMap.reality_for(finished_timeline, GameState.run_outcomes)
	GameState.record_reality(TimelineMap.key_of(last_reality))
	GameState.run_outcomes = []
	GameState.runs_finished += 1
	GameState.timeline = ""
	GameState.chapter = 0
	GameState.location = "main_menu"
	GameState.clear_flags("objective_")
	GameState.clear_flags(RUN_FLAG_PREFIX)
	GameState.save_current(true)
	if Cutscene.visible:
		Cutscene.hand_over()
	if title != "":
		StoryCard.show_ending(title, line, lead_in)
	elif finished_timeline == "main":
		StoryCard.show_time_order(lead_in)
	else:
		StoryCard.show_ending("", "", lead_in, "timeline_reveal")


func _enter_chapter(lead_in: Array) -> void:
	if Cutscene.visible:
		Cutscene.hand_over()
	var story := current_story()
	var info: Dictionary = STORIES[story]
	# Each story starts fresh, even if it was played before in another run.
	GameState.clear_flags("objective_")
	GameState.location = info["scene"]
	GameState.save_current(true)
	StoryCard.start(info["title"], info["scene"], lead_in)
