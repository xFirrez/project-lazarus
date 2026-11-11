// Red damage vignette (GAME_DESIGN §3.2): `intensity` scales with missing HP, `flash` pulses on hit.
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.55, 0.0, 0.0, 1.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv * vec2(1.0, 0.85));
	float strength = clamp(intensity * 0.85 + flash * 0.5, 0.0, 1.0);
	float inner = mix(1.25, 0.45, strength);
	float v = smoothstep(inner, inner + 0.75, d);
	COLOR = vec4(tint.rgb, v * clamp(strength * 1.2, 0.0, 0.92));
}
