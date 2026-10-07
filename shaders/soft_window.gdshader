shader_type canvas_item;
// The game's soft 90s anime window, worked out per pixel so it stays smooth at any size: rounded
// corners, a gentle top-to-bottom gradient, a thin double border (a light outer line and a coloured
// inner line), and a soft shadow underneath. Every edge is a little blurred, like the art.
//
// The node is larger than the window by `pad` on every side, to leave room for the shadow.

uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float pad = 14.0;
uniform float radius = 14.0;
uniform vec4 fill_top : source_color = vec4(0.227, 0.141, 0.188, 0.84);
uniform vec4 fill_bottom : source_color = vec4(0.118, 0.071, 0.098, 0.9);
uniform vec4 outer_line : source_color = vec4(1.0, 0.953, 0.839, 0.95);
uniform float outer_width = 2.0;
uniform float line_gap = 3.0;
uniform vec4 inner_line : source_color = vec4(0.851, 0.643, 0.255, 0.85);
uniform float inner_width = 1.5;
uniform float shadow_alpha : hint_range(0.0, 1.0) = 0.35;
uniform vec2 shadow_offset = vec2(0.0, 4.0);
// How soft every edge is, in pixels.
uniform float softness : hint_range(0.3, 3.0) = 1.2;
// 0 normally, up to 1 to light the window up a little, for example while a button is pressed.
uniform float lit : hint_range(0.0, 1.0) = 0.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// 1 between depths a and b (measured inward from the edge), with soft ends.
float band(float depth, float a, float b, float s) {
	return smoothstep(a - s, a + s, depth) * (1.0 - smoothstep(b - s, b + s, depth));
}

void fragment() {
	vec4 base = COLOR;
	vec2 point = UV * rect_size;
	vec2 centre = rect_size * 0.5;
	vec2 half_size = max(centre - vec2(pad), vec2(1.0));
	float r = min(radius, min(half_size.x, half_size.y));
	float dist = rounded_box(point - centre, half_size, r);
	float depth = -dist;
	float s = softness * 0.5;

	float coverage = 1.0 - smoothstep(-s, s, dist);
	float t = clamp((point.y - pad) / max(rect_size.y - 2.0 * pad, 1.0), 0.0, 1.0);
	vec4 box = mix(fill_top, fill_bottom, t);
	box.rgb += lit * 0.14;

	float inner_start = outer_width + line_gap;
	float inner_band = band(depth, inner_start, inner_start + inner_width, s) * inner_line.a;
	box.rgb = mix(box.rgb, inner_line.rgb, inner_band);
	box.a = mix(box.a, 1.0, inner_band);
	float outer_band = band(depth, 0.0, outer_width, s) * outer_line.a;
	box.rgb = mix(box.rgb, outer_line.rgb, outer_band);
	box.a = mix(box.a, 1.0, outer_band);
	box.a *= coverage;

	float shadow_dist = rounded_box(point - centre - shadow_offset, half_size, r);
	float shadow = shadow_alpha * (1.0 - smoothstep(-pad * 0.4, pad, shadow_dist));

	float alpha = box.a + shadow * (1.0 - box.a);
	vec3 rgb = box.rgb * box.a / max(alpha, 0.0001);
	COLOR = vec4(rgb * base.rgb, alpha * base.a);
}
