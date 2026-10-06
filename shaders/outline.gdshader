shader_type canvas_item;
// An outline around the sides and top of the combined silhouette of a CanvasGroup's children. The
// group draws all of its children into one picture first, so several characters in one group
// share one outline around their joined shape, and overlapping parts do not get lines between
// them. There is no outline along the bottom, where the characters are cut off or stand on the
// ground.

uniform sampler2D group_tex : hint_screen_texture, filter_linear;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Outline thickness in screen pixels.
uniform float outline_width : hint_range(0.0, 12.0) = 1.4;
// 1 shows the outline, 0 hides it. Faded to 0 while a dialogue is open.
uniform float outline_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 body = texture(group_tex, SCREEN_UV);
	// The widest reach of the picture's shape within the outline radius, sampled on two rings so
	// the outline is round and has no gaps.
	float reach = 0.0;
	for (int ring = 1; ring <= 2; ring++) {
		float radius = outline_width * float(ring) * 0.5;
		for (int i = 0; i < 16; i++) {
			float angle = float(i) * 0.39269908;
			// Looking upward from a pixel means the shape is above it, so the pixel is below the
			// shape. Skipping those looks leaves the bottom edge without an outline.
			if (sin(angle) < -0.05) {
				continue;
			}
			vec2 at = vec2(cos(angle), sin(angle)) * radius * SCREEN_PIXEL_SIZE;
			reach = max(reach, texture(group_tex, SCREEN_UV + at).a);
		}
	}
	// The outline lives only where the shape is absent but close by. Everything is worked out
	// from alpha, so a half-faded character (or one mid-fade with its outline) fades cleanly
	// instead of turning dark.
	reach = max(reach, body.a);
	float excess = (reach - body.a) * outline_color.a * outline_opacity;
	float out_alpha = body.a + excess;
	vec3 out_rgb = (body.rgb * body.a + outline_color.rgb * excess) / max(out_alpha, 0.0001);
	COLOR = vec4(out_rgb, out_alpha);
}
