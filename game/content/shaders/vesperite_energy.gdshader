// Vesperite energy — the "energy" VFX language (STYLE_GUIDE §7): green additive glow with
// scrolling noise and a fresnel rim, pulsing. Used by machines, conduits and wonder weapons.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 energy_color : source_color = vec4(0.35, 1.0, 0.45, 1.0);
uniform vec4 core_color : source_color = vec4(0.85, 1.0, 0.85, 1.0);
uniform float energy = 2.5;
uniform sampler2D detail_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 scroll = vec2(0.05, 0.35);
uniform float noise_scale = 1.6;
uniform float fresnel_power = 2.5;
uniform float pulse_speed = 1.7;

varying vec3 v_obj_pos;

void vertex() {
	v_obj_pos = VERTEX;
}

void fragment() {
	float n = texture(detail_noise, v_obj_pos.xy * noise_scale + scroll * TIME).r;
	float n2 = texture(detail_noise, v_obj_pos.zy * noise_scale * 1.9 - scroll.yx * TIME * 0.7).r;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), fresnel_power);
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	float body = smoothstep(0.35, 0.85, n * n2 * 2.0);
	vec3 c = mix(energy_color.rgb, core_color.rgb, body * 0.6);
	ALBEDO = c * energy * pulse * (0.25 + body * 0.75 + fres * 1.5);
}
