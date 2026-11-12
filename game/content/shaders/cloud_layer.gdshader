// Cloud sea / drifting cloud layer (Step 13, VESPER_PEAK §8.1): a huge transparent plane with
// scrolling fbm noise, lit faintly from the moon side and faded toward its rim. Used below the
// peak (valley cloud sea) and as a thin layer the storm drags past the ridge.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.18, 0.22, 0.28);
uniform vec3 lit_color : source_color = vec3(0.42, 0.48, 0.58);
uniform float coverage = 0.55;
uniform float scale = 0.004;
uniform vec2 speed = vec2(0.006, 0.002);
uniform float alpha = 0.85;
uniform float rim = 0.45;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.1 + 3.1; a *= 0.5; }
	return v;
}

varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz * scale + TIME * speed;
	float n = fbm(p * 8.0);
	float c = smoothstep(1.0 - coverage, 1.0 - coverage + 0.3, n);
	float edge = 1.0 - smoothstep(rim, 0.5, length(UV - 0.5));
	ALBEDO = mix(color, lit_color, smoothstep(0.5, 0.9, n));
	ALPHA = c * alpha * edge;
}
