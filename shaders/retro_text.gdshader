shader_type canvas_item;
// 90s retro blur: a soft 3x3 blur over text and thin graphics.
// The blur is measured in the game's own pixels (its 1280x720 picture), not in the pixels of the
// font's texture, so text looks equally soft on every screen: a phone draws its letters from a
// sharper, larger texture than a small window does, and a blur counted in texture pixels was
// nearly invisible there and heavy here.

// How far the blur reaches, in the game's pixels.
uniform float blur : hint_range(0.0, 3.0) = 0.7;
// How many screen pixels one game pixel covers; RetroText keeps it up to date.
uniform float screen_scale = 1.0;
// Thickens glyphs a little. Use 1.0 for things that must keep their exact opacity.
uniform float alpha_boost : hint_range(1.0, 2.0) = 1.2;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	// How far one game pixel reaches in the texture, across and down.
	vec2 px = vec2(length(dFdx(UV)), length(dFdy(UV))) * blur * screen_scale;
	// 3x3 gaussian, weights add up to 1.
	vec2 offsets[9] = vec2[](
		vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
		vec2(1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0));
	float weights[9] = float[](0.25, 0.125, 0.125, 0.125, 0.125, 0.0625, 0.0625, 0.0625, 0.0625);
	// Premultiplied, so transparent pixels do not darken the edges.
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 9; i++) {
		vec4 c = texture(TEXTURE, UV + offsets[i] * px);
		acc += vec4(c.rgb * c.a, c.a) * weights[i];
	}
	float a = clamp(acc.a * alpha_boost, 0.0, 1.0);
	vec3 rgb = acc.rgb / max(acc.a, 0.001);
	COLOR = vec4(rgb * vertex_color.rgb, vertex_color.a * a);
}
