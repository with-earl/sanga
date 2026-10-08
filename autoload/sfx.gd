extends Node
## Sound effects. Only three: a soft click whenever any button is pressed, a pencil stroke when
## an objective is struck through, and a remembered chime with a golden ripple across the screen
## when the player takes a choice only a memory allows. They play on the Sound bus, so the Sound
## switch in the menu turns them on and off.
##
## Every button in the game gets the click automatically, including ones made in code, so no
## scene needs to do anything. The sounds are made by tools/compose_sounds.py.

const CLICK := preload("res://assets/sounds/click.wav")
const STRIKE := preload("res://assets/sounds/strike.wav")
const MEMORY := preload("res://assets/sounds/memory.wav")
const RIPPLE_SHADER := preload("res://shaders/memory_ripple.gdshader")
const RIPPLE_SECONDS := 1.2
## Above the cutscenes (90), so the ripple shows wherever the choice was taken.
const RIPPLE_LAYER := 95
## Both sounds play well below full scale, so they stay faint under the music.
const VOLUME_DB := -10.0
## A few clicks can overlap, for quick taps.
const CLICK_VOICES := 3

var _clicks: Array[AudioStreamPlayer] = []
var _next_click := 0
var _strike := AudioStreamPlayer.new()
var _memory := AudioStreamPlayer.new()
var _ripple_layer := CanvasLayer.new()
var _ripple := ColorRect.new()


func _ready() -> void:
	for index in CLICK_VOICES:
		var player := AudioStreamPlayer.new()
		player.stream = CLICK
		player.bus = Settings.SOUND_BUS
		player.volume_db = VOLUME_DB
		add_child(player)
		_clicks.append(player)
	_strike.stream = STRIKE
	_strike.bus = Settings.SOUND_BUS
	_strike.volume_db = VOLUME_DB
	add_child(_strike)
	_memory.stream = MEMORY
	_memory.bus = Settings.SOUND_BUS
	_memory.volume_db = VOLUME_DB
	add_child(_memory)
	_ripple_layer.layer = RIPPLE_LAYER
	_ripple_layer.visible = false
	var material := ShaderMaterial.new()
	material.shader = RIPPLE_SHADER
	_ripple.material = material
	_ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ripple.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ripple_layer.add_child(_ripple)
	add_child(_ripple_layer)
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "BaseButton", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(click):
		(node as BaseButton).pressed.connect(click)


func click() -> void:
	var player := _clicks[_next_click]
	_next_click = (_next_click + 1) % CLICK_VOICES
	player.play()


## The pencil stroke, `delay` seconds from now, in time with the line being drawn.
func strike(delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_strike.play()


## A choice only a memory allows was taken: the chime, and a golden ring across the screen.
func memory() -> void:
	_memory.play()
	_ripple_layer.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: (_ripple.material as ShaderMaterial).set_shader_parameter("progress", value), 0.0, 1.0, RIPPLE_SECONDS)
	tween.tween_callback(func() -> void: _ripple_layer.visible = false)
