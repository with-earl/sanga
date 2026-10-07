class_name ScreenFit
extends RefCounted
## Helps the game fit any phone screen. The game is drawn for a 1280 x 720 (16:9) screen. The
## window grows to the phone's shape, and each place is enlarged, keeping its shape, to fill the
## screen's width: on a phone wider than 16:9 a thin strip at the top and bottom is cut off, and on
## a taller screen, such as a tablet, dark bars show above and below. The HUD and dialogue are laid out on the real screen, so they stay in view.

## The screen size every place, prop position and piece of art is made for.
const DESIGN_SIZE := Vector2(1280, 720)


## How much to enlarge the 1280 x 720 picture so it fills the width of a screen of the given size.
## On a screen taller than 16:9 the picture keeps its shape and leaves dark bars above and below.
static func width_scale(screen_size: Vector2) -> float:
	return screen_size.x / DESIGN_SIZE.x


## Where to draw a picture of `content` size so it covers all of `area` without being stretched,
## centred, cutting off whatever spills over.
static func cover_rect(content: Vector2, area: Vector2) -> Rect2:
	var factor := maxf(area.x / content.x, area.y / content.y)
	var drawn := content * factor
	return Rect2((area - drawn) / 2.0, drawn)


## How far in from each edge of the screen the game should keep buttons and text, so they stay
## clear of a phone's notch, camera cut-out and rounded corners. Given in game units, as
## (left, top, right, bottom). Zero on screens with nothing in the way. In a phone's browser the
## page fills the whole screen (viewport-fit=cover), so the browser is asked for the safe area.
static func safe_insets(viewport: Viewport) -> Vector4:
	if OS.has_feature("web"):
		return _web_safe_insets(viewport)
	if not (OS.has_feature("android") or OS.has_feature("ios")):
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


## The browser's safe area (the CSS env(safe-area-inset-*) values), measured with a hidden element
## and turned into game units. Zero when the browser has none, for example on a computer.
static func _web_safe_insets(viewport: Viewport) -> Vector4:
	var script := """(function () {
		var probe = document.createElement('div');
		probe.style.cssText = 'position:fixed;visibility:hidden;padding-left:env(safe-area-inset-left);' +
			'padding-top:env(safe-area-inset-top);padding-right:env(safe-area-inset-right);' +
			'padding-bottom:env(safe-area-inset-bottom);';
		document.body.appendChild(probe);
		var s = getComputedStyle(probe);
		var out = [s.paddingLeft, s.paddingTop, s.paddingRight, s.paddingBottom, window.innerWidth]
			.map(function (v) { return parseFloat(v) || 0; }).join(',');
		document.body.removeChild(probe);
		return out;
	})()"""
	var answer: Variant = JavaScriptBridge.eval(script, true)
	var parts := str(answer).split(",")
	if parts.size() != 5 or float(parts[4]) <= 0.0:
		return Vector4.ZERO
	var to_game := viewport.get_visible_rect().size.x / float(parts[4])
	return Vector4(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])) * to_game
