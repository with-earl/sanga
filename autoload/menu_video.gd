extends CanvasLayer
## Background for the boot screen and the main screen.
##
## The boot screen shows the still image. When the main screen appears, the video fades in over
## it, so the change from still to video is gradual instead of a visible jump. A cozy bright grade
## (see shaders/cozy_bright.gdshader) sits above both and below the buttons and text. Everything
## is hidden during gameplay, and the video picks up where it left off on return.
##
## It lives outside the scenes so it survives scene changes.

const VIDEO_PATH := "res://assets/videos/main_screen.ogv"
const COZY_SHADER := preload("res://shaders/cozy_bright.gdshader")
const BOOT_SCENE := "res://scenes/boot.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const FADE_IN_SECONDS := 0.7

var video := VideoStreamPlayer.new()

var _cozy_layer := CanvasLayer.new()
var _on_menu := false
var _tween: Tween


func _ready() -> void:
	layer = -10
	visible = false
	var still := ArtSlot.new()
	still.asset_id = "main_screen"
	still.category = "backgrounds"
	still.stretch_to_fit = true
	add_child(still)
	_fill_screen(still)
	if ResourceLoader.exists(VIDEO_PATH):
		video.stream = load(VIDEO_PATH)
	# The video's own soundtrack is muted: the main screen's music comes from MusicDirector.
	video.bus = Settings.MUSIC_BUS
	video.volume = 0.0
	video.expand = true
	video.loop = true
	video.modulate.a = 0.0
	# The video keeps its shape and fills the screen's width, like every full-screen picture.
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(video)
	get_viewport().size_changed.connect(_cover_screen_with_video)
	_cover_screen_with_video()

	# The cozy grade reads whatever is drawn below it, so it covers the still and the video.
	_cozy_layer.layer = -9
	_cozy_layer.visible = false
	var grade := ColorRect.new()
	grade.material = ShaderMaterial.new()
	grade.material.shader = COZY_SHADER
	_fill_screen(grade)
	_cozy_layer.add_child(grade)
	add_child(_cozy_layer)

	get_tree().node_added.connect(_on_node_added)
	_sync_with_current_scene.call_deferred()


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
	var shown := scene_path == BOOT_SCENE or scene_path == MENU_SCENE
	visible = shown
	_cozy_layer.visible = shown
	if scene_path == BOOT_SCENE:
		_stop_video()
		_on_menu = false
	elif scene_path == MENU_SCENE:
		video.paused = false
		if not video.is_playing():
			video.play()
		if not _on_menu:
			_fade_video_in()
		_on_menu = true
	else:
		video.paused = true
		_on_menu = false


func _fade_video_in() -> void:
	_kill_tween()
	video.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(video, "modulate:a", 1.0, FADE_IN_SECONDS)


func _stop_video() -> void:
	_kill_tween()
	video.stop()
	video.modulate.a = 0.0


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _cover_screen_with_video() -> void:
	var stream_size := Vector2(ScreenFit.DESIGN_SIZE)
	var texture := video.get_video_texture()
	if texture != null and texture.get_width() > 0:
		stream_size = texture.get_size()
	var area := ScreenFit.width_rect(stream_size, get_viewport().get_visible_rect().size)
	video.position = area.position
	video.size = area.size


func _fill_screen(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
