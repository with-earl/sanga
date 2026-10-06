extends CanvasLayer
## The screen vignette: one overlay above each scene's art, instead of a copy on every image.
##
## In gameplay scenes it sits above the backgrounds, props and characters (the scene's HUD, the
## game menu and the story card are on layers above it, so text and buttons stay sharp). On the
## boot and main screens it sits above the background video but below their buttons.

const SHADER := preload("res://shaders/scene_vignette.gdshader")
const BOOT_SCENE := "res://scenes/boot.tscn"
const MAIN_SCENE := "res://scenes/main_menu.tscn"
## Layer for scenes whose buttons are part of the scene itself (layer 0): the overlay goes under them.
const BEHIND_SCENE_LAYER := -8
## Layer for gameplay scenes: above their art (layer 0), below their HUD (layer 20).
const ABOVE_ART_LAYER := 10


func _ready() -> void:
	visible = false
	var overlay := ColorRect.new()
	overlay.material = make_material()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	get_tree().node_added.connect(_on_node_added)
	_sync_with_current_scene.call_deferred()


## A material using the vignette shader, for any other screen that needs the same vignette.
func make_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	return material


## The first scene is added before this node is ready, so check it once at startup.
func _sync_with_current_scene() -> void:
	var current := get_tree().current_scene
	if current != null:
		_show_for(current.scene_file_path)


func _on_node_added(node: Node) -> void:
	if node.get_parent() != get_tree().root or node == self:
		return
	_show_for(node.scene_file_path)


func _show_for(scene_path: String) -> void:
	var is_menu_screen := scene_path == BOOT_SCENE or scene_path == MAIN_SCENE
	visible = is_menu_screen or SceneRouter.SCENES.values().has(scene_path)
	layer = BEHIND_SCENE_LAYER if is_menu_screen else ABOVE_ART_LAYER
