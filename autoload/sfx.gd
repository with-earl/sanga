extends Node
## Sound effects. Only two: a soft click whenever any button is pressed, and a pencil stroke when
## an objective is struck through. They play on the Sound bus, so the Sound switch in the menu
## turns them on and off.
##
## Every button in the game gets the click automatically, including ones made in code, so no
## scene needs to do anything. The sounds are made by tools/compose_sounds.py.

const CLICK := preload("res://assets/sounds/click.wav")
const STRIKE := preload("res://assets/sounds/strike.wav")
## Both sounds play well below full scale, so they stay faint under the music.
const VOLUME_DB := -10.0
## A few clicks can overlap, for quick taps.
const CLICK_VOICES := 3

var _clicks: Array[AudioStreamPlayer] = []
var _next_click := 0
var _strike := AudioStreamPlayer.new()


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
