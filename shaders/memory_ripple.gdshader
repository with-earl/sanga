// A soft golden ring spreading out from the middle of the screen, bending what is under it a
// little as it passes, when the player takes a choice only a memory allows (see Sfx.memory).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
// 0 when the ring starts, 1 when it has passed the edges.
uniform float progress = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 away = uv - vec2(0.5);
	float wide = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 round_away = vec2(away.x * wide, away.y);
	float distance = length(round_away);
	float ring = exp(-pow((distance - progress * 1.1) / 0.07, 2.0)) * (1.0 - progress);
	uv -= normalize(round_away + 1e-5) * ring * 0.012 * vec2(1.0 / wide, 1.0);
	vec3 color = texture(screen, uv).rgb + vec3(1.0, 0.86, 0.55) * ring * 0.45;
	COLOR = vec4(color, 1.0);
}
