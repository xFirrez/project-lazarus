// Vesperite camo (GAME_DESIGN §9.2, DEVELOPMENT_PLAN Step 11 scope 3): the Lazarus Forge's animated
// pattern laid over an upgraded weapon as a material overlay — brushed gold plates with flowing,
// pulsing green vesperite veins. World-space triplanar so it needs no UVs (greybox + authored guns).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec3 gold : source_color = vec3(0.86, 0.66, 0.24);
uniform vec3 vein : source_color = vec3(0.3, 1.0, 0.55);
uniform float scale = 18.0;
uniform float flow_speed = 0.35;
uniform float pulse_speed = 2.2;
uniform float coverage = 0.92;

varying vec3 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = abs(NORMAL);
	vec2 uv = (n.x > n.y && n.x > n.z) ? local_pos.zy : ((n.y > n.z) ? local_pos.xz : local_pos.xy);
	uv *= scale;
	float t = TIME * flow_speed;
	float f = fbm(uv + vec2(t, -t * 0.6));
	// Veins: thin bands where the warped noise crosses 0.5.
	float band = 1.0 - smoothstep(0.0, 0.06, abs(fbm(uv * 0.7 + f * 1.8 - t) - 0.5));
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed + f * 6.0);
	float plates = step(0.5, fract(uv.x * 0.25 + uv.y * 0.11)) * 0.08;
	ALBEDO = mix(gold * (0.85 + plates + f * 0.3), vein, band);
	METALLIC = mix(0.9, 0.0, band);
	ROUGHNESS = mix(0.3 + f * 0.2, 0.4, band);
	EMISSION = vein * band * pulse * 2.5 + gold * 0.05;
	ALPHA = coverage;
}
