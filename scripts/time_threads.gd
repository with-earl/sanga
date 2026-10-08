class_name TimeThreads
extends RefCounted
## "Ayusin ayon sa oras": a run's moments put back in true time order, with the causes joined to
## their effects. The recap book (run_recap.gd) shows it after the run's own pages.
##
## The stories were played out of order; in time, Kumpisal is the past, Padala the present and
## Tokhang the future. A thread joins two moments of the same run: a choice and its echo (bible
## R9), or a choice or ending and the ending it led to (story/threads.json). A thread is only drawn
## when both ends happened in this run, so it never tells the player more than they saw, and only
## forward in time, never from the future into the past.

const THREADS_FILE := "res://story/threads.json"
## Each story's place in time, and the word the book writes beside it.
const STORY_TIME := {"Kumpisal": 0, "Padala": 1, "Tokhang": 2}
const TIME_WORDS := ["Nakaraan", "Kasalukuyan", "Hinaharap"]


## The run's stories in time order, each with the positions (in the run log) of its moments.
static func sections(run_log: Array) -> Array:
	var found := {}
	var current := ""
	for index in run_log.size():
		var moment: Dictionary = run_log[index]
		if moment.has("story"):
			current = str(moment["story"])
			if not found.has(current):
				found[current] = []
			continue
		if current != "":
			(found[current] as Array).append(index)
	var stories: Array = found.keys()
	stories.sort_custom(func(a: String, b: String) -> bool: return STORY_TIME.get(a, 9) < STORY_TIME.get(b, 9))
	return stories.map(func(story: String) -> Dictionary: return {"story": story, "moments": found[story]})


## The threads of this run, each [cause, effect] as positions in the run log, both pointing at
## moments the book writes (a choice, an echo, or an ending's line).
static func threads(run_log: Array) -> Array:
	var story_of := _story_of_each(run_log)
	var pairs: Array = []
	# A choice and its echo share a flag.
	for index in run_log.size():
		var moment: Dictionary = run_log[index]
		if moment.has("echo") and str(moment.get("flag", "")) != "":
			for earlier in index:
				if str((run_log[earlier] as Dictionary).get("flag", "")) == str(moment["flag"]) and (run_log[earlier] as Dictionary).has("choice"):
					pairs.append([earlier, index])
	for link in _links():
		var cause := _find(run_log, link.get("from", {}))
		var effect := _find(run_log, link.get("to", {}))
		if cause >= 0 and effect >= 0 and cause != effect:
			pairs.append([cause, effect])
	# Forward in time only: never from a later story into an earlier one.
	return pairs.filter(func(pair: Array) -> bool:
		return STORY_TIME.get(story_of[pair[0]], 9) <= STORY_TIME.get(story_of[pair[1]], 9))


## The moment a link end points at: a choice by its words, or an outcome by its ending id, which
## the book shows as that ending's line (the ending card logged just before it).
static func _find(run_log: Array, end: Dictionary) -> int:
	for index in run_log.size():
		var moment: Dictionary = run_log[index]
		if end.has("choice") and str(moment.get("choice", "")) == str(end["choice"]):
			return index
		if end.has("outcome") and str(moment.get("outcome", "")) in end["outcome"]:
			for earlier in range(index - 1, -1, -1):
				var before: Dictionary = run_log[earlier]
				if before.has("ending"):
					return earlier
				if before.has("story") or before.has("outcome"):
					break
			return -1
	return -1


static func _story_of_each(run_log: Array) -> Array:
	var stories: Array = []
	var current := ""
	for moment in run_log:
		if (moment as Dictionary).has("story"):
			current = str(moment["story"])
		stories.append(current)
	return stories


static func _links() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(THREADS_FILE))
	return (parsed as Dictionary).get("threads", []) if parsed is Dictionary else []
