// Vesper Peak night sky (Step 13, VESPER_PEAK §8.1 / §8.3): navy-to-teal gradient, stars that
// fade behind racing storm clouds, a low cold moon with a halo, and an aurora-like green flash
// (`aurora`, driven by the reactor's energy pulses). Procedural: no textures.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.012, 0.02, 0.045);
uniform vec3 horizon_color : source_color = vec3(0.075, 0.11, 0.15);
uniform vec3 ground_color : source_color = vec3(0.02, 0.024, 0.03);
uniform vec3 moon_dir = vec3(-0.45, 0.42, 0.79);
uniform vec3 moon_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_size = 0.035;
uniform float cloud_cover = 0.62;
uniform float cloud_speed = 0.012;
uniform vec3 cloud_color : source_color = vec3(0.1, 0.13, 0.18);
uniform float aurora = 0.0;
uniform float energy = 1.0;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.55, h));
	col = mix(col, ground_color, smoothstep(0.0, -0.08, h));
	// stars (above the horizon haze only)
	vec2 sp = d.xz / max(d.y, 0.05) * 60.0;
	float star = step(0.9965, hash(floor(sp))) * smoothstep(0.08, 0.35, h);
	// clouds on a plane above the camera, scrolling with the storm
	vec2 cp = d.xz / max(d.y + 0.15, 0.08) * 1.6 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
	float c = fbm(cp);
	float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, c) * smoothstep(-0.05, 0.12, h);
	// moon + halo (dimmed by the clouds)
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	float disc = smoothstep(1.0 - moon_size * 0.06, 1.0 - moon_size * 0.05, m);
	float halo = pow(max(m, 0.0), 220.0) * 0.6 + pow(max(m, 0.0), 18.0) * 0.12;
	col += moon_color * (disc * 2.2 + halo) * (1.0 - cover * 0.75);
	col += vec3(star) * 0.8 * (1.0 - cover);
	// clouds lit from the moon side
	vec3 cl = cloud_color + moon_color * 0.08 * pow(max(m, 0.0), 6.0);
	col = mix(col, cl, cover * 0.9);
	// aurora band
	float band = smoothstep(0.12, 0.3, h) * smoothstep(0.65, 0.3, h);
	float wave = 0.5 + 0.5 * sin(d.x * 9.0 + TIME * 0.4 + fbm(d.xz * 3.0 + TIME * 0.05) * 4.0);
	col += vec3(0.2, 1.0, 0.45) * band * wave * aurora * 0.8;
	COLOR = col * energy;
}
