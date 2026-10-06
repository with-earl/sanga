extends Node
## Loads every scene and every piece of art when the game starts, and keeps it in memory.
##
## Work is split into stages (scenes, backgrounds, characters, and so on). Each stage loads in
## background threads, and `current_label` names the stage in progress so the startup screen can
## say exactly what is loading. Nothing is read from storage mid-game, and a missing or broken
## file is reported once, up front.

const ASSET_ROOT := "res://assets"
const ART_EXTENSIONS := ["png", "ogv"]
## Each stage stays up at least this long so its name is readable.
const MIN_STAGE_SECONDS := 0.35
const STAGE_LABELS := {
	"backgrounds": "Loading backgrounds",
	"characters": "Loading characters",
	"props": "Loading props",
	"ui": "Loading interface",
	"videos": "Loading video",
	"montage": "Loading montage",
	"portraits": "Loading portraits",
}

## Name of the stage in progress, for example "Loading characters".
var current_label := ""
## Paths that could not be loaded.
var failed: Array[String] = []

var _stages: Array[Dictionary] = []
var _stage_index := 0
var _stage_elapsed := 0.0
var _pending: Array[String] = []
var _held: Array[Resource] = []


func start() -> void:
	failed.clear()
	_held.clear()
	_load_scripts_first()
	_stages = _build_stages()
	_stage_index = 0
	_begin_stage()


## Loads every game script on the main thread before anything loads in the background. Scenes are
## loaded several at a time on other threads, and two scenes whose scripts build on the same base
## script (such as Location) could otherwise both try to load that base at the same moment, which
## can fail. Scripts are small, so this takes a moment.
func _load_scripts_first() -> void:
	for folder in ["res://scripts", "res://autoload"]:
		for file in DirAccess.get_files_at(folder):
			var clean := file.trim_suffix(".remap")
			if clean.get_extension() in ["gd", "gdc"]:
				_held.append(load(folder.path_join(clean.get_basename() + ".gd")))


## Call every frame with the frame time. Returns true once every stage has finished.
func poll(delta: float) -> bool:
	if _stage_index >= _stages.size():
		return true
	_stage_elapsed += delta
	_collect_finished()
	if _pending.is_empty() and _stage_elapsed >= MIN_STAGE_SECONDS:
		_stage_index += 1
		if _stage_index >= _stages.size():
			return true
		_begin_stage()
	return false


func loaded_count() -> int:
	return _held.size()


func _begin_stage() -> void:
	var stage := _stages[_stage_index]
	current_label = stage["label"]
	_stage_elapsed = 0.0
	_pending.assign(stage["paths"])
	for path in _pending:
		ResourceLoader.load_threaded_request(path, "", true)


func _collect_finished() -> void:
	for path in _pending.duplicate():
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				_held.append(ResourceLoader.load_threaded_get(path))
				_pending.erase(path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Could not load %s" % path)
				failed.append(path)
				_pending.erase(path)


func _build_stages() -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	var scene_paths: Array[String] = []
	for key in SceneRouter.SCENES:
		scene_paths.append(SceneRouter.SCENES[key])
	stages.append({"label": "Loading scenes", "paths": scene_paths})
	var folders := DirAccess.get_directories_at(ASSET_ROOT)
	folders.sort()
	for folder in folders:
		var paths: Array[String] = []
		_collect_art(ASSET_ROOT.path_join(folder), paths)
		if not paths.is_empty():
			stages.append({"label": STAGE_LABELS.get(folder, "Loading assets"), "paths": paths})
	return stages


func _collect_art(dir_path: String, out: Array[String]) -> void:
	for file in DirAccess.get_files_at(dir_path):
		# Exported builds list imported files as "name.png.import".
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if not ART_EXTENSIONS.has(clean.get_extension()):
			continue
		var path := dir_path.path_join(clean)
		if not out.has(path):
			out.append(path)
	for sub_dir in DirAccess.get_directories_at(dir_path):
		_collect_art(dir_path.path_join(sub_dir), out)
