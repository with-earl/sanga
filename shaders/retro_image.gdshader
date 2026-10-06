shader_type canvas_item;
// 90s anime film look for art: soft focus, a soft glow around bright areas, faded warm colors and
// a slight color bleed. The screen vignette is separate (see scene_vignette.gdshader). There are
// no scanlines and no grain. The art it draws must use linear texture filtering.

// Soft focus, in screen pixels, so art looks equally soft however much it is scaled down.
uniform float softness : hint_range(0.0, 3.0) = 0.93;
uniform float glow : hint_range(0.0, 1.0) = 0.22;
uniform float color_bleed : hint_range(0.0, 3.0) = 1.2;
uniform float fade : hint_range(0.0, 0.3) = 0.05;
uniform float saturation : hint_range(0.0, 1.5) = 0.9;
// Color multiplier for the warm film tint. White means no tint.
uniform vec3 tint = vec3(1.03, 1.0, 0.97);

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;

	// Soft focus. Two taps per side with these offsets and weights reproduce a 5 tap binomial
	// gaussian (1 4 6 4 1) using the sampler's linear filtering, so nine reads give a full 5x5
	// gaussian. Premultiplied, so transparent edges stay clean.
	// Source texels per screen pixel: 1 when drawn at full size, 3 when drawn at a third.
	float texels_per_pixel = max(abs(fwidth(UV.x)) / texel.x, 0.01);
	float spread = softness * 0.5 * texels_per_pixel;
	float tap_offset[3] = float[](0.0, 1.2, -1.2);
	float tap_weight[3] = float[](0.375, 0.3125, 0.3125);
	vec4 acc = vec4(0.0);
	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			vec2 at = vec2(tap_offset[i], tap_offset[j]) * spread * texel;
			vec4 c = texture(TEXTURE, UV + at);
			acc += vec4(c.rgb * c.a, c.a) * (tap_weight[i] * tap_weight[j]);
		}
	}
	float alpha = acc.a;
	vec3 rgb = acc.rgb / max(alpha, 0.001);

	// Color bleed: red leans one way and blue the other, like an old broadcast transfer.
	float red = texture(TEXTURE, UV + vec2(texel.x * color_bleed, 0.0)).r;
	float blue = texture(TEXTURE, UV - vec2(texel.x * color_bleed, 0.0)).b;
	rgb.r = mix(rgb.r, red, 0.5);
	rgb.b = mix(rgb.b, blue, 0.5);

	// Glow: bright areas bleed light into their surroundings.
	vec3 halo = vec3(0.0);
	halo += texture(TEXTURE, UV + vec2(4.0, 4.0) * texel).rgb;
	halo += texture(TEXTURE, UV + vec2(-4.0, 4.0) * texel).rgb;
	halo += texture(TEXTURE, UV + vec2(4.0, -4.0) * texel).rgb;
	halo += texture(TEXTURE, UV + vec2(-4.0, -4.0) * texel).rgb;
	halo *= 0.25;
	float bright = max(dot(halo, vec3(0.299, 0.587, 0.114)) - 0.6, 0.0);
	rgb += halo * bright * glow * 2.0;

	// Faded pastel grade: lifted blacks, slightly less saturated, a touch warm.
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(vec3(luma), rgb, saturation);
	rgb = rgb * (1.0 - fade) + fade;
	rgb *= tint;

	COLOR = vec4(clamp(rgb, 0.0, 1.0) * vertex_color.rgb, alpha * vertex_color.a);
}
