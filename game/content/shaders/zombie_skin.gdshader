// Zombie skin (STYLE_GUIDE §5): wrap diffuse lighting with a cold subsurface tint so flesh never
// goes pitch black, procedural rot blotches and wet wound patches (world-independent: object
// space, so they ride with the animated mesh), vertex-color dirt (COLOR.r) and a hit flash.
// Variants differ only by uniforms (skin tint, rot, wounds, pattern seed).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 skin_tint : source_color = vec4(0.58, 0.58, 0.47, 1.0);
uniform vec4 rot_color : source_color = vec4(0.32, 0.36, 0.22, 1.0);
uniform vec4 bruise_color : source_color = vec4(0.32, 0.22, 0.3, 1.0);
uniform vec4 wound_color : source_color = vec4(0.35, 0.03, 0.03, 1.0);
uniform vec4 subsurface_color : source_color = vec4(0.45, 0.18, 0.16, 1.0);
uniform float rot_amount : hint_range(0.0, 1.0) = 0.45;
uniform float wound_amount : hint_range(0.0, 1.0) = 0.25;
uniform float wrap : hint_range(0.0, 1.0) = 0.5;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.35;
uniform float pattern_seed = 0.0;
uniform sampler2D detail_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_obj_pos;
varying vec3 v_obj_nrm;

void vertex() {
	v_obj_pos = VERTEX;
	v_obj_nrm = NORMAL;
}

void fragment() {
	vec3 p = v_obj_pos * 2.3 + vec3(pattern_seed * 7.13, pattern_seed * 3.7, 0.0);
	vec3 w = pow(abs(normalize(v_obj_nrm)), vec3(3.0));
	w /= (w.x + w.y + w.z);
	float n = texture(detail_noise, p.zy).r * w.x + texture(detail_noise, p.xz).r * w.y
		+ texture(detail_noise, p.xy).r * w.z;
	float n2 = texture(detail_noise, p.xy * 3.1 + p.zz).r;
	vec3 c = skin_tint.rgb * (0.85 + 0.3 * n2);
	c = mix(c, rot_color.rgb, smoothstep(0.55, 0.7, n) * rot_amount);
	c = mix(c, bruise_color.rgb, smoothstep(0.3, 0.18, n) * rot_amount * 0.7);
	float wound = smoothstep(0.72, 0.78, n2 * (0.7 + 0.6 * n)) * wound_amount;
	c = mix(c, wound_color.rgb, wound);
	c = mix(c, c * 0.45, clamp(COLOR.r * 0.6, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = mix(0.72, 0.18, wound);
	SPECULAR = mix(0.35, 0.7, wound);
	EMISSION = vec3(1.0, 0.85, 0.7) * flash * 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float sss = clamp(d - max(ndl, 0.0), 0.0, 1.0) * subsurface_strength;
	DIFFUSE_LIGHT += (vec3(d) + subsurface_color.rgb * sss) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(8.0, 64.0, 1.0 - ROUGHNESS)) * SPECULAR_AMOUNT;
	SPECULAR_LIGHT += spec * (1.0 - ROUGHNESS) * 0.5 * ATTENUATION * LIGHT_COLOR;
}
