// Living light over a place, drawn above the room and the people in it and below the HUD.
// Everything is very faint, so the room feels alive without anything pulling the eye:
// - flames: small warm glows that flicker, like candles and wall lamps;
// - motes: specks of dust that float up and twinkle in the sunlight;
// - steam: soft white wisps drifting up, like steam from a bathroom door;
// - clouds: slow, wide shadows passing over, as if clouds crossed the sun outside.
// It uses premultiplied blending, so one pass can both add light and dim.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

// Up to four flames: x, y (0 to 1 across the place), size, strength.
uniform vec4 flames[4];
uniform int flame_count = 0;
uniform vec3 flame_color = vec3(1.0, 0.7, 0.36);
// Dust in the sunlight, inside an area given as x, y, width, height (0 to 1).
uniform float motes = 0.0;
uniform vec4 motes_area = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 mote_color = vec3(1.0, 0.9, 0.7);
// Steam, inside an area given the same way.
uniform float steam = 0.0;
uniform vec4 steam_area = vec4(0.0, 0.0, 0.0, 0.0);
// How much a passing cloud shadow dims the place at its darkest.
uniform float clouds = 0.0;
// Width over height of the place, so round things stay round.
uniform float aspect = 1.7777778;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amount = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amount;
		p *= 2.03;
		amount *= 0.5;
	}
	return total;
}

// 1 inside the area, fading softly to 0 at its edges.
float soft_area(vec2 uv, vec4 area) {
	vec2 inside = (uv - area.xy) / max(area.zw, vec2(0.0001));
	vec2 edge = smoothstep(vec2(0.0), vec2(0.25), inside) * smoothstep(vec2(0.0), vec2(0.25), 1.0 - inside);
	return edge.x * edge.y;
}

void fragment() {
	vec2 uv = UV;
	vec3 light = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		if (i >= flame_count) {
			break;
		}
		vec4 flame = flames[i];
		vec2 away = (uv - flame.xy) * vec2(aspect, 1.0);
		float seed = float(i) * 7.31;
		// A slow, gentle swell, like a flame in still air. Anything quicker reads as a flicker or
		// a buzz on a small screen.
		float flicker = 0.84 + 0.16 * noise(vec2(TIME * 0.45 + seed, seed));
		light += flame_color * flame.w * flicker * exp(-dot(away, away) / (flame.z * flame.z));
	}
	if (motes > 0.0) {
		float inside = soft_area(uv, motes_area);
		for (int layer = 0; layer < 2; layer++) {
			float depth = 1.0 + float(layer);
			vec2 grid = uv * vec2(aspect, 1.0) * (16.0 + 10.0 * float(layer));
			grid += vec2(sin(TIME * 0.2 + float(layer)) * 0.4, TIME * 0.12 * depth);
			vec2 cell = floor(grid);
			float seed = hash(cell + float(layer) * 13.0);
			vec2 spot = vec2(hash(cell + 1.7), hash(cell + 4.1)) * 0.6 + 0.2;
			float near = length(fract(grid) - spot);
			float twinkle = 0.5 + 0.5 * sin(TIME * (1.0 + seed * 2.0) + seed * 40.0);
			light += mote_color * motes * inside * step(0.86, seed) * twinkle * smoothstep(0.09, 0.0, near) * 0.5;
		}
	}
	if (steam > 0.0) {
		float wisps = fbm(uv * vec2(9.0, 4.0) + vec2(sin(TIME * 0.3) * 0.3, -TIME * 0.35));
		light += vec3(0.95) * steam * soft_area(uv, steam_area) * smoothstep(0.45, 0.8, wisps);
	}
	float shade = 0.0;
	if (clouds > 0.0) {
		// Wide soft shapes sliding slowly from left to right.
		float cloud = fbm(vec2(uv.x * 1.2 - TIME * 0.025, uv.y * 0.6 + TIME * 0.01));
		shade = clouds * smoothstep(0.45, 0.75, cloud);
	}
	COLOR = vec4(light, shade);
}
