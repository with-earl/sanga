class_name ScreenFit
extends RefCounted
## Helps the game fit any phone screen. The game is drawn for a 1280 x 720 screen and keeps that
## shape: on a wider phone it shows black bars at the sides rather than stretching. The helpers
## below also cope with a window that grows to the phone's shape (project setting
## display/window/stretch/aspect = "expand"): then every place keeps its 1280 x 720 "stage" in the
## middle and a soft blurred copy of the background fills the extra space.

## The screen size every place, prop position and piece of art is made for.
const DESIGN_SIZE := Vector2(1280, 720)
## How small the background is shrunk for the side fill. Tiny pictures stretched back up look like
## a heavy, smooth blur, and cost almost nothing to draw.
const SIDE_FILL_SIZE := Vector2i(48, 27)
## The side fill is dimmed so it reads as "outside the stage" and never competes with it.
const SIDE_FILL_BRIGHTNESS := 0.6


## The 1280 x 720 stage, centred in a screen of the given size.
static func stage_rect(screen_size: Vector2) -> Rect2:
	return Rect2((screen_size - DESIGN_SIZE) / 2.0, DESIGN_SIZE)


## Where to draw a picture of `content` size so it covers all of `area` without being stretched,
## centred, cutting off whatever spills over.
static func cover_rect(content: Vector2, area: Vector2) -> Rect2:
	var factor := maxf(area.x / content.x, area.y / content.y)
	var drawn := content * factor
	return Rect2((area - drawn) / 2.0, drawn)


## How far in from each edge of the screen the game should keep buttons and text, so they stay
## clear of a phone's notch, camera cut-out and rounded corners. Given in game units, as
## (left, top, right, bottom). Zero on screens with nothing in the way, and in the web build,
## where the browser already keeps the page clear of them.
static func safe_insets(viewport: Viewport) -> Vector4:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	# With the 16:9 shape kept, the black bars already keep the game clear of the notch.
	if str(ProjectSettings.get_setting("display/window/stretch/aspect", "keep")) != "expand":
		return Vector4.ZERO
	var window := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window.x <= 0.0 or window.y <= 0.0 or safe.size.x <= 0.0:
		return Vector4.ZERO
	var to_game := viewport.get_visible_rect().size / window
	return Vector4(
		maxf(safe.position.x, 0.0) * to_game.x,
		maxf(safe.position.y, 0.0) * to_game.y,
		maxf(window.x - safe.end.x, 0.0) * to_game.x,
		maxf(window.y - safe.end.y, 0.0) * to_game.y)


## A very blurry copy of a picture, for filling the sides of the screen around the stage.
static func blurred_copy(texture: Texture2D) -> ImageTexture:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.resize(SIDE_FILL_SIZE.x, SIDE_FILL_SIZE.y, Image.INTERPOLATE_CUBIC)
	return ImageTexture.create_from_image(image)
