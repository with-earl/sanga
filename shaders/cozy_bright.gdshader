shader_type canvas_item;
// Cozy bright mood: a warm golden-hour grade, a dreamy glow, a soft sunbeam from the top left, and
// a few slowly floating light specks. It reads the screen behind it, so it grades whatever is
// drawn on the layers below it and leaves everything above it alone.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// Overall brightness, and how much the darkest areas are lifted.
uniform float exposure : hint_range(0.8, 1.4) = 1.07;
uniform float lift : hint_range(0.0, 0.15) = 0.03;
// Golden tint, and how strongly it is applied.
uniform vec3 warm_tint = vec3(1.0, 0.93, 0.8);
uniform float warmth : hint_range(0.0, 1.0) = 0.3;
uniform float saturation : hint_range(0.5, 1.6) = 1.1;
// Dreamy glow around bright areas.
uniform float bloom : hint_range(0.0, 1.0) = 0.35;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float bloom_radius : hint_range(1.0, 12.0) = 5.0;
// Soft warm light from the top left corner, breathing very slowly.
uniform float sunbeam : hint_range(0.0, 0.5) = 0.18;
// Floating specks of light.
uniform float motes : hint_range(0.0, 1.0) = 0.7;

float hash11(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * bloom_radius;

	// Dreamy glow: average a ring of samples and let the bright part of it spill outward.
	vec3 base = texture(screen_tex, uv).rgb;
	vec2 ring[8] = vec2[](
		vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
		vec2(0.7, 0.7), vec2(-0.7, 0.7), vec2(0.7, -0.7), vec2(-0.7, -0.7));
	vec3 halo = base;
	for (int i = 0; i < 8; i++) {
		halo += texture(screen_tex, uv + ring[i] * px).rgb;
	}
	halo /= 9.0;
	float bright = max(dot(halo, vec3(0.299, 0.587, 0.114)) - bloom_threshold, 0.0);
	vec3 rgb = base + halo * bright * bloom * 2.0;

	// Warm, bright grade.
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(vec3(luma), rgb, saturation);
	rgb = rgb * exposure + lift;
	rgb = mix(rgb, rgb * warm_tint * 1.08, warmth);

	// Sunbeam: warm light that fades with distance from the top left corner.
	float reach = length((uv - vec2(0.04, -0.02)) * vec2(1.0, 0.9));
	float breathe = 1.0 + 0.12 * sin(TIME * 0.5);
	rgb += vec3(1.0, 0.86, 0.58) * sunbeam * breathe * exp(-reach * 2.4);

	// Floating light specks that drift upward, sway a little, and twinkle.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 sparkle = vec3(0.0);
	for (int i = 0; i < 14; i++) {
		float seed = float(i) + 1.0;
		float speed = 0.012 + 0.02 * hash11(seed * 2.3);
		vec2 at = vec2(
			hash11(seed * 1.7) + 0.02 * sin(TIME * 0.6 + seed * 3.0),
			fract(hash11(seed * 3.1) - TIME * speed));
		float reach_mote = length(vec2((uv.x - at.x) * aspect, uv.y - at.y));
		float size = 0.004 + 0.007 * hash11(seed * 5.9);
		float twinkle = 0.5 + 0.5 * sin(TIME * 1.5 + seed * 5.0);
		sparkle += vec3(1.0, 0.92, 0.7) * smoothstep(size, 0.0, reach_mote) * twinkle;
	}
	rgb += sparkle * motes;

	COLOR = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
