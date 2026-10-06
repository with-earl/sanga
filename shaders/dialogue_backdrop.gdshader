shader_type canvas_item;
// The look of the scene behind a dialogue: clearly blurred and dimmed, with extra darkness toward
// the bottom where the text box sits, so the conversation stands out from the scene.
// `amount` goes from 0 (the scene as it is) to 1 (fully dimmed and blurred).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Blur radius at full strength, in screen pixels.
uniform float blur_radius : hint_range(0.0, 20.0) = 6.0;
// How much darker the whole scene gets at full strength.
uniform float dim : hint_range(0.0, 0.8) = 0.34;
// Extra darkness at the very bottom, fading out upward, and how far up it reaches (0 to 1).
uniform float bottom_dim : hint_range(0.0, 0.8) = 0.28;
uniform float bottom_reach : hint_range(0.1, 1.0) = 0.45;

const int TAPS = 24;
const float GOLDEN_ANGLE = 2.39996323;

void fragment() {
	// A soft disk blur: taps spiral outward, and nearer ones count for more, so the result is
	// smooth like a gaussian blur with no visible ghost copies.
	float radius = blur_radius * amount;
	vec3 sum = texture(screen_tex, SCREEN_UV).rgb;
	float total = 1.0;
	for (int i = 1; i <= TAPS; i++) {
		float t = float(i) / float(TAPS);
		float angle = float(i) * GOLDEN_ANGLE;
		vec2 at = vec2(cos(angle), sin(angle)) * sqrt(t) * radius * SCREEN_PIXEL_SIZE;
		float weight = exp(-2.2 * t);
		sum += texture(screen_tex, SCREEN_UV + at).rgb * weight;
		total += weight;
	}
	vec3 rgb = sum / total;

	float toward_bottom = smoothstep(1.0 - bottom_reach, 1.0, SCREEN_UV.y);
	float darkness = dim + bottom_dim * toward_bottom;
	rgb *= 1.0 - darkness * amount;
	COLOR = vec4(rgb, 1.0);
}
