// Lazarus surface — the shared stylized PBR "uber" shader (docs/STYLE_GUIDE.md §5).
// Flat palette albedo broken up by a world-space triplanar detail noise (no UVs needed, so kit
// pieces tile seamlessly), vertex-color grime (COLOR.r, painted by tools/blender), triplanar snow
// accumulation on up-facing surfaces, wet/icy floors, and wind sway (COLOR.g weight).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

group_uniforms base;
uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D detail_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_scale = 0.35;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.25;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
group_uniforms grime;
uniform vec4 grime_color : source_color = vec4(0.1, 0.085, 0.07, 1.0);
uniform float grime_strength : hint_range(0.0, 1.0) = 0.45;
group_uniforms snow;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 snow_color : source_color = vec4(0.86, 0.9, 0.97, 1.0);
uniform float snow_threshold : hint_range(-1.0, 1.0) = 0.45;
group_uniforms wet;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float ice : hint_range(0.0, 1.0) = 0.0;
group_uniforms wind;
uniform float sway_strength = 0.0;
uniform float sway_speed = 1.4;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
	if (sway_strength > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float t = TIME * sway_speed + wp.x * 0.37 + wp.z * 0.29;
		float gust = 0.6 + 0.4 * sin(TIME * 0.31 + wp.x * 0.05);
		vec3 off = vec3(sin(t), 0.0, cos(t * 0.83) * 0.6) * sway_strength * gust * COLOR.g;
		VERTEX += (vec4(off, 0.0) * MODEL_MATRIX).xyz;
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float triplanar(vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(detail_noise, p.zy * s).r * w.x + texture(detail_noise, p.xz * s).r * w.y
		+ texture(detail_noise, p.xy * s).r * w.z;
}

void fragment() {
	vec3 n = normalize(v_world_nrm);
	float d = triplanar(v_world_pos, n, detail_scale);
	float d2 = triplanar(v_world_pos, n, detail_scale * 4.1);
	vec3 base = albedo.rgb * (1.0 - detail_strength + detail_strength * 2.0 * mix(d, d2, 0.35));
	float rough = roughness;
	float metal = metallic;
	float grime = clamp(COLOR.r * grime_strength * (0.55 + 0.9 * d), 0.0, 1.0);
	base = mix(base, grime_color.rgb, grime);
	rough = mix(rough, min(1.0, rough + 0.15), grime);
	// Wet / icy: darker albedo and a glossy film, puddles where the detail noise is low.
	float puddle = smoothstep(0.55, 0.35, d) * wetness;
	base *= 1.0 - 0.3 * wetness - 0.25 * puddle;
	rough = mix(rough, 0.06, max(puddle, wetness * 0.5));
	base = mix(base, base * 0.6 + vec3(0.25, 0.35, 0.42), ice * 0.6);
	rough = mix(rough, 0.04, ice);
	// Snow settles on up-facing surfaces, with a noisy edge.
	float s = smoothstep(snow_threshold, snow_threshold + 0.2, n.y + (d - 0.5) * 0.5) * snow_amount;
	base = mix(base, snow_color.rgb * (0.92 + 0.16 * d2), s);
	rough = mix(rough, 0.7, s);
	metal = mix(metal, 0.0, s);
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = specular;
	EMISSION = emission_color.rgb * emission_energy;
}
