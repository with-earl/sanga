extends Node
## Central scene navigation. Every scene is preloaded at startup, so changes are immediate.

const SCENES := {
	"main_menu": "res://scenes/main_menu.tscn",
	"church_nave": "res://scenes/church_nave.tscn",
	"confessional": "res://scenes/confessional.tscn",
	"apartment_room": "res://scenes/apartment_room.tscn",
	"public_market": "res://scenes/public_market.tscn",
	"timeline_reveal": "res://scenes/timeline_reveal.tscn",
}


func go_to(key: String) -> void:
	if not SCENES.has(key):
		push_error("Unknown scene key: %s" % key)
		return
	get_tree().change_scene_to_file(SCENES[key])
