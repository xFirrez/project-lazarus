// Wind sway for cables, tarps, banners and hanging lamps (Step 13): vertex displacement scaled by
// the storm's global `wind_strength` (StormSystem) and by the vertex's distance from the anchor
// (`anchor_axis` = local axis the mesh hangs from; 0 sway at the anchor, full at the far end).
shader_type spatial;
render_mode cull_disabled;

global uniform float wind_strength;
uniform vec3 albedo : source_color = vec3(0.3, 0.32, 0.28);
uniform float roughness = 0.9;
uniform float metallic = 0.0;
uniform float sway = 0.25;
uniform float length_m = 2.0;
uniform vec3 anchor_axis = vec3(0.0, 1.0, 0.0);
uniform vec3 wind_dir = vec3(0.9, 0.0, 0.35);
uniform float flutter = 1.0;

void vertex() {
	float along = clamp(1.0 - dot(VERTEX, anchor_axis) / length_m - 0.5, 0.0, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * (1.2 + wind_strength);
	float w = sin(t + wp.x * 0.3 + wp.z * 0.2) * 0.6 + sin(t * 2.7 + wp.y) * 0.25 * flutter;
	vec3 local_wind = (inverse(MODEL_MATRIX) * vec4(normalize(wind_dir), 0.0)).xyz;
	VERTEX += local_wind * along * along * sway * wind_strength * (0.6 + w);
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
