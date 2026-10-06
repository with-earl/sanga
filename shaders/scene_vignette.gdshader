shader_type canvas_item;
// A soft vignette for a whole screen. It reads everything drawn below it, darkens the corners
// gently, and blurs the edges with a gaussian blur, so it covers the backgrounds, props and
// characters together instead of being baked into each image.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// How dark the corners get.
uniform float vignette : hint_range(0.0, 0.8) = 0.18;
// Where the darkening starts and where it is complete, measured from the screen center.
// A wide gap makes the falloff gradual and soft.
uniform float vignette_start : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_end : hint_range(0.0, 1.0) = 0.8;
// Blur at the very edge of the screen, in screen pixels. It fades to nothing toward the center.
uniform float edge_blur : hint_range(0.0, 12.0) = 5.0;

void fragment() {
	vec2 centered = (SCREEN_UV - 0.5) * vec2(1.0, 0.9);
	float edge = smoothstep(vignette_start, vignette_end, length(centered));

	// Gaussian blur that grows toward the edges. Two taps per side with these offsets and weights
	// reproduce a 5 tap binomial gaussian (1 4 6 4 1) using linear filtering, so nine reads give
	// a full 5x5 gaussian. The spacing scales with the blur radius.
	float spread = edge_blur * edge * 0.5;
	float tap_offset[3] = float[](0.0, 1.2, -1.2);
	float tap_weight[3] = float[](0.375, 0.3125, 0.3125);
	vec3 rgb = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			vec2 at = vec2(tap_offset[i], tap_offset[j]) * spread * SCREEN_PIXEL_SIZE;
			rgb += texture(screen_tex, SCREEN_UV + at).rgb * (tap_weight[i] * tap_weight[j]);
		}
	}

	rgb *= 1.0 - vignette * edge;
	COLOR = vec4(rgb, 1.0);
}
