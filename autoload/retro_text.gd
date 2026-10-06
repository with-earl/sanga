extends Node
## Gives every Label and Button the 90s retro blur shader, including ones added later.
## Any other node can opt in by joining the "retro_blur" group.
## Buttons that still have the theme's default look also get the game's one button look (see
## UiSkin), so they match the dialogue box and the gameplay menu. The main screen's text buttons
## keep their text-only style.

const SHADER := preload("res://shaders/retro_text.gdshader")

var _material := ShaderMaterial.new()


func _ready() -> void:
	_material.shader = SHADER
	get_tree().node_added.connect(_on_node_added)
	_apply_to_existing.call_deferred()


## The first scene is added before this node is ready, so cover what is already in the tree.
func _apply_to_existing() -> void:
	_apply_to_branch(get_tree().root)


func _apply_to_branch(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_apply_to_branch(child)


func _on_node_added(node: Node) -> void:
	if node is Label or node is Button or node.is_in_group("retro_blur"):
		(node as CanvasItem).material = _material
	if node is Button and UiSkin.wants_default_look(node):
		var button := node as Button
		UiSkin.style_button(button)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
