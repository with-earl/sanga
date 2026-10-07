class_name SoftWindow
extends ColorRect
## The game's one window look, in the spirit of 90s anime and visual novels: a rounded, see-through
## warm plum-brown window with a soft gradient, a thin cream outer line, a golden ochre inner line
## and a soft shadow. It is drawn by a shader, so it is smooth and sharp at any size and costs
## almost nothing to draw.
##
## It sits behind another control (a panel or a button) and follows its size, so that control can
## stay see-through and only hold the text.

enum Look { WINDOW, PLATE, BUTTON }

const SHADER := preload("res://shaders/soft_window.gdshader")
## Room around the window for its soft shadow.
const PAD := 14.0
## The window: warm plum-brown, a little lighter at the top, see-through enough to hint at the
## scene behind it.
const FILL_TOP := Color(0.227, 0.141, 0.188, 0.84)
const FILL_BOTTOM := Color(0.118, 0.071, 0.098, 0.9)
## The name plate is a warmer brown, so the speaker's name stands apart from what they say.
const PLATE_TOP := Color(0.38, 0.22, 0.13, 0.96)
const PLATE_BOTTOM := Color(0.25, 0.13, 0.08, 0.96)
const OUTER_LINE := Color(1.0, 0.953, 0.839, 0.95)
const INNER_LINE := Color(0.851, 0.643, 0.255, 0.85)
## Pressed buttons light up a little and settle back when let go.
const LIGHT_SECONDS := 0.12

## 0 normally, 1 while lit, for example while a button is held down.
var lit := 0.0:
	set(value):
		lit = value
		(material as ShaderMaterial).set_shader_parameter("lit", value)

var _light_tween: Tween


## Puts a soft window behind `host` that always matches its size, and returns it.
static func behind(host: Control, look := Look.WINDOW) -> SoftWindow:
	var window := SoftWindow.new()
	window.name = "SoftWindow"
	window.setup(look)
	host.add_child(window, false, Node.INTERNAL_MODE_FRONT)
	if host is Container:
		# A container lays out every child, this one too, inside its own padding. Put the window
		# back over the whole host each time the container has finished its layout.
		host.sort_children.connect(window._cover_host.bind(host))
		window._cover_host(host)
	else:
		window.set_anchors_preset(Control.PRESET_FULL_RECT)
		window.offset_left = -PAD
		window.offset_top = -PAD
		window.offset_right = PAD
		window.offset_bottom = PAD
	return window


## Puts a soft window behind a button and lights it up while the button is held down.
static func behind_button(button: BaseButton) -> SoftWindow:
	var window := behind(button, Look.BUTTON)
	button.button_down.connect(window.light.bind(true))
	button.button_up.connect(window.light.bind(false))
	return window


func setup(look: Look) -> void:
	color = Color.WHITE
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material
	shader_material.set_shader_parameter("pad", PAD)
	shader_material.set_shader_parameter("outer_line", OUTER_LINE)
	shader_material.set_shader_parameter("inner_line", INNER_LINE)
	match look:
		Look.WINDOW:
			_set_fill(FILL_TOP, FILL_BOTTOM)
			shader_material.set_shader_parameter("radius", 16.0)
		Look.PLATE:
			_set_fill(PLATE_TOP, PLATE_BOTTOM)
			shader_material.set_shader_parameter("radius", 10.0)
			shader_material.set_shader_parameter("outer_width", 1.5)
			shader_material.set_shader_parameter("line_gap", 2.0)
			shader_material.set_shader_parameter("inner_width", 1.0)
			shader_material.set_shader_parameter("shadow_alpha", 0.3)
		Look.BUTTON:
			_set_fill(FILL_TOP, FILL_BOTTOM)
			shader_material.set_shader_parameter("radius", 12.0)
			shader_material.set_shader_parameter("outer_width", 1.5)
			shader_material.set_shader_parameter("line_gap", 2.5)
			shader_material.set_shader_parameter("inner_width", 1.0)
			shader_material.set_shader_parameter("shadow_alpha", 0.3)
	resized.connect(_sync_size)
	_sync_size()


## Lights the window up, or lets it settle back.
func light(on: bool) -> void:
	if _light_tween != null and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_light_tween.tween_property(self, "lit", 1.0 if on else 0.0, LIGHT_SECONDS)


func _cover_host(host: Control) -> void:
	position = Vector2(-PAD, -PAD)
	size = host.size + Vector2(PAD, PAD) * 2.0


func _set_fill(top: Color, bottom: Color) -> void:
	(material as ShaderMaterial).set_shader_parameter("fill_top", top)
	(material as ShaderMaterial).set_shader_parameter("fill_bottom", bottom)


func _sync_size() -> void:
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
