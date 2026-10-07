class_name SoftShapes
extends RefCounted
## Draws simple shapes (boxes, rounded bars, strokes) into small pictures instead of drawing them
## as vectors. The retro text shader softens pictures, not vector drawing, so building HUD shapes
## this way gives them the same soft 90s look as the text.

## A box style from a picture: a fill with a border, optionally with rounded corners. The picture
## is small and stretched by its edges (nine-slice), so it fits any size.
static func box_style(fill: Color, border: Color, border_width: int, radius := 0) -> StyleBoxTexture:
	var margin := maxi(border_width, radius) + 1
	var side := margin * 2 + 2
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var half := Vector2(side, side) / 2.0
	for y in side:
		for x in side:
			var point := Vector2(x + 0.5, y + 0.5)
			# Distance inside the rounded box: positive inside, negative outside.
			var q := (point - half).abs() - (half - Vector2(radius, radius))
			var outside := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var inside := -outside
			var coverage := clampf(inside + 0.5, 0.0, 1.0) if radius > 0 else 1.0
			var color := border if inside < border_width else fill
			if border_width > 0 and inside >= border_width - 0.5 and inside < border_width + 0.5:
				color = border.lerp(fill, inside - (border_width - 0.5))
			color.a *= coverage
			image.set_pixel(x, y, color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	for side_index in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side_index, margin)
	return style


## Round-ended strokes, each a pair of points, with an outline drawn under every stroke first so
## crossing strokes do not cut into each other. Returns a picture `size` big.
static func strokes(size: Vector2i, segments: Array, fill: Color, width: float, outline: Color, outline_width: float) -> ImageTexture:
	var image := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	var fill_radius := width / 2.0
	var outer_radius := fill_radius + outline_width
	for y in image.get_height():
		for x in image.get_width():
			var point := Vector2(x + 0.5, y + 0.5)
			var nearest := INF
			for segment in segments:
				nearest = minf(nearest, _distance_to_segment(point, segment[0], segment[1]))
			var outer := clampf(outer_radius - nearest + 0.5, 0.0, 1.0)
			if outer <= 0.0:
				continue
			var inner := clampf(fill_radius - nearest + 0.5, 0.0, 1.0)
			var color := outline.lerp(fill, inner) if outline_width > 0.0 else fill
			color.a *= outer if outline_width > 0.0 else inner
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## A soft filled triangle with an outline, `size` pixels across, for the little cursors: the ▼
## that says "tap to go on" and the ▶ beside a choice. `points` are the corners, in pixels.
static func triangle(size: Vector2i, points: PackedVector2Array, fill: Color, outline: Color, outline_width: float) -> ImageTexture:
	var image := Image.create(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var point := Vector2(x + 0.5, y + 0.5)
			var edge := INF
			for index in points.size():
				edge = minf(edge, _distance_to_segment(point, points[index], points[(index + 1) % points.size()]))
			# Signed distance: positive inside the triangle, negative outside.
			var inside := edge if Geometry2D.is_point_in_polygon(point, points) else -edge
			var outer := clampf(inside + outline_width + 0.5, 0.0, 1.0)
			if outer <= 0.0:
				continue
			var color := outline.lerp(fill, clampf(inside + 0.5, 0.0, 1.0))
			color.a *= outer
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## A small white four-pointed sparkle with a soft glow, `size` pixels across.
static func sparkle(size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for y in size:
		for x in size:
			var offset := (Vector2(x + 0.5, y + 0.5) - Vector2(half, half)) / half
			# Two thin rays crossing, fading toward their tips, around a bright round core.
			var ray := maxf(_ray(offset.x, offset.y), _ray(offset.y, offset.x))
			var core := clampf(1.0 - offset.length() / 0.28, 0.0, 1.0)
			var alpha := clampf(maxf(ray, core * core), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


## The hint glint: a soft warm four-pointed star inside a wide, faint halo of light, `size` pixels
## across. Gentler and larger than the sparkle, made to breathe slowly in and out.
static func glint(size: int) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size / 2.0
	for y in size:
		for x in size:
			var offset := (Vector2(x + 0.5, y + 0.5) - Vector2(half, half)) / half
			var distance := offset.length()
			var ray := maxf(_ray(offset.x, offset.y), _ray(offset.y, offset.x))
			var core := clampf(1.0 - distance / 0.16, 0.0, 1.0)
			var halo := exp(-distance * distance * 9.0) * 0.28
			var alpha := clampf(maxf(maxf(ray, core * core), halo), 0.0, 1.0)
			# White at the heart, warming to soft gold toward the edge of the halo.
			var tint := Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.86, 0.55), clampf(distance * 1.4, 0.0, 1.0))
			image.set_pixel(x, y, Color(tint, alpha))
	return ImageTexture.create_from_image(image)


static func _ray(along: float, across: float) -> float:
	var length := clampf(1.0 - absf(along), 0.0, 1.0)
	var width := 0.06 + 0.1 * length
	return clampf(1.0 - absf(across) / width, 0.0, 1.0) * length * length


static func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var along := to - from
	var t := 0.0 if along.length_squared() == 0.0 else clampf((point - from).dot(along) / along.length_squared(), 0.0, 1.0)
	return point.distance_to(from + along * t)
