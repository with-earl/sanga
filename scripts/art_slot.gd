@tool
class_name ArtSlot
extends Control
## A spot where art goes. Draws a labeled placeholder until a matching PNG exists.
##
## The image is looked up at res://assets/<category>/<asset_id>.png, so adding art
## only means dropping a file with the right name into the right folder.

signal interacted(slot: ArtSlot)

const ASSET_PATH := "res://assets/%s/%s.png"
const SHAPE_ALPHA_THRESHOLD := 0.1
const CHARACTER_SOFTNESS := 1.2
const RETRO_SHADER := preload("res://shaders/retro_image.gdshader")
const CATEGORY_COLORS := {
	"backgrounds": Color(0.84, 0.76, 0.62, 1.0),
	"characters": Color(0.91, 0.64, 0.48, 1.0),
	"props": Color(0.62, 0.74, 0.6, 1.0),
	"ui": Color(0.7, 0.62, 0.78, 1.0),
}

@export var asset_id := "":
	set(value):
		asset_id = value
		_refresh()
@export_enum("backgrounds", "characters", "props", "ui") var category := "props":
	set(value):
		category = value
		_refresh()
@export var display_name := "":
	set(value):
		display_name = value
		queue_redraw()
## Stretch the image over the whole slot (backgrounds) instead of fitting it inside.
@export var stretch_to_fit := false
@export var interactive := false
## Absorbs taps without reacting, so art in front of a tappable slot does not let taps through.
@export var block_taps := false
## Only the visible (non-transparent) pixels of the image react to taps, so the tap area
## matches the shape of the art instead of its bounding box.
@export var shape_hit_test := false:
	set(value):
		shape_hit_test = value
		_refresh()
## Gives the art the 90s anime film look (soft focus, glow, faded colors). Props never get it,
## whatever this is set to, so cutouts like the confessional booth and the vase stay clean.
@export var retro_look := true:
	set(value):
		retro_look = value
		_refresh()
## Mirrors the art left to right, and its tap shape with it. Kept on the node, so it stays
## flipped when the image file is replaced.
@export var flip_horizontal := false:
	set(value):
		flip_horizontal = value
		queue_redraw()
## A tap area only, with nothing drawn, for things already painted into the background (such as
## the toy guns in the market). The editor shows a thin outline so it can still be placed.
@export var hotspot := false:
	set(value):
		hotspot = value
		queue_redraw()
@export var font_size := 22

static var _retro_material: ShaderMaterial
static var _character_material: ShaderMaterial

var _texture: Texture2D
var _shape: BitMap
var _pressed := false


## One material shared by all art, so a single change to its settings restyles everything.
static func retro_material() -> ShaderMaterial:
	if _retro_material == null:
		_retro_material = ShaderMaterial.new()
		_retro_material.shader = RETRO_SHADER
	return _retro_material


## Characters are drawn softer than the scenery, to take the hard edge off the cutouts. Same
## shader with a higher softness (screen pixels), shared by every character.
static func character_material() -> ShaderMaterial:
	if _character_material == null:
		_character_material = retro_material().duplicate() as ShaderMaterial
		_character_material.set_shader_parameter("softness", CHARACTER_SOFTNESS)
	return _character_material



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if (interactive or block_taps) and not Engine.is_editor_hint() else Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_refresh()


## With shape_hit_test on, a point only counts when it lands on a visible pixel of the art.
func _has_point(point: Vector2) -> bool:
	if not shape_hit_test or _shape == null:
		return Rect2(Vector2.ZERO, size).has_point(point)
	var art := _art_rect(Rect2(Vector2.ZERO, size))
	if not art.has_point(point):
		return false
	var texel := (point - art.position) / art.size * Vector2(_shape.get_size())
	if flip_horizontal:
		texel.x = _shape.get_size().x - texel.x
	return _shape.get_bitv(Vector2i(texel))


## Touch is emulated as the left mouse button. A tap fires when the finger lifts on the slot.
func _gui_input(event: InputEvent) -> void:
	if not interactive or Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
		else:
			var tapped := _pressed and _has_point(event.position)
			_pressed = false
			if tapped:
				interacted.emit(self)
		accept_event()


func has_art() -> bool:
	return _texture != null


func expected_path() -> String:
	return ASSET_PATH % [category, asset_id]


func _refresh() -> void:
	_texture = null
	_shape = null
	if asset_id != "" and ResourceLoader.exists(expected_path()):
		_texture = load(expected_path()) as Texture2D
	if _texture != null and shape_hit_test:
		_shape = _build_shape(_texture)
	var shaded := _texture != null and retro_look and category != "props"
	if not shaded:
		material = null
	else:
		material = character_material() if category == "characters" else retro_material()
	# Art is scaled to fit, so it always uses smooth sampling. The shader's blur needs it too.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if _texture != null else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	queue_redraw()


func _build_shape(texture: Texture2D) -> BitMap:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	var shape := BitMap.new()
	shape.create_from_image_alpha(image, SHAPE_ALPHA_THRESHOLD)
	return shape


## Where the art is drawn inside the slot: stretched over all of it, or fitted and bottom aligned.
func _art_rect(rect: Rect2) -> Rect2:
	if stretch_to_fit:
		return rect
	var tex_size := _texture.get_size()
	var factor := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var fitted := tex_size * factor
	return Rect2(Vector2((rect.size.x - fitted.x) / 2.0, rect.size.y - fitted.y), fitted)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if hotspot:
		if Engine.is_editor_hint():
			draw_rect(rect, Color(1.0, 0.85, 0.3, 0.8), false, 2.0)
		return
	if _texture != null:
		var art := _art_rect(rect)
		if flip_horizontal:
			# A negative width draws the picture mirrored inside the same rectangle.
			art.size.x = -art.size.x
		draw_texture_rect(_texture, art, false)
	else:
		_draw_placeholder(rect)


func _draw_placeholder(rect: Rect2) -> void:
	var fill: Color = CATEGORY_COLORS.get(category, CATEGORY_COLORS["props"])
	draw_rect(rect, Color(fill, 0.55 if category == "backgrounds" else 0.85), true)
	draw_rect(rect, fill.darkened(0.45), false, 3.0)
	var font := ThemeDB.fallback_font
	var title := display_name if display_name != "" else asset_id
	var ink := Color(0.2, 0.12, 0.1, 1.0)
	var mid_y := rect.size.y / 2.0
	draw_string(font, Vector2(0, mid_y), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, ink)
	draw_string(font, Vector2(0, mid_y + font_size), expected_path().trim_prefix("res://"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxi(font_size - 10, 10), ink.lightened(0.2))
