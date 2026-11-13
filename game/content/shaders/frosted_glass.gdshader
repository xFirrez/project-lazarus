// Frosted glass — frost creeps in from the pane edges (object-space distance to the bounds) with
// world noise; optional warm interior glow for lit windows seen from the storm (STYLE_GUIDE §5).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.62, 0.74, 0.82, 1.0);
uniform float clear_alpha : hint_range(0.0, 1.0) = 0.25;
uniform float frost_alpha : hint_range(0.0, 1.0) = 0.85;
uniform sampler2D detail_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.55;
uniform vec4 glow_color : source_color = vec4(1.0, 0.68, 0.32, 1.0);
uniform float glow_energy = 0.0;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(detail_noise, v_world_pos.xy * 1.7 + v_world_pos.zz * 0.9).r;
	float n2 = texture(detail_noise, v_world_pos.xz * 6.0 + v_world_pos.yy * 3.0).r;
	float frost = smoothstep(1.0 - frost_amount, 1.0 - frost_amount + 0.25, n * 0.7 + n2 * 0.4);
	ALBEDO = mix(tint.rgb * 0.5, vec3(0.85, 0.9, 0.95), frost);
	ROUGHNESS = mix(0.05, 0.6, frost);
	METALLIC = 0.0;
	ALPHA = mix(clear_alpha, frost_alpha, frost);
	if (glow_energy > 0.0) {
		// A lit room behind the glass: brighter through the clear patches, diffused by frost.
		EMISSION = glow_color.rgb * glow_energy * mix(1.0, 0.55, frost) * (0.85 + 0.3 * n2);
		ALPHA = 1.0;
	}
}
