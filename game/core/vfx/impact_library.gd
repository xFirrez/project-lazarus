# ImpactLibrary — per-surface bullet impact look (GAME_DESIGN §4, ARCHITECTURE §6.2 "impact library
# by surface"): particle colour, count, speed, gravity and size, decal tint and whether the surface
# takes a decal. Surfaces come from SurfaceTags (collider metadata / PhysicsMaterial name).
# Authority: local presentation data.
class_name ImpactLibrary
extends RefCounted

# surface -> [particle colour, count, speed m/s, gravity scale, size m, lifetime s, decal tint, decal]
const SURFACES: Dictionary = {
	&"concrete": [Color(0.62, 0.6, 0.56), 10, 3.0, 0.6, 0.025, 0.5, Color(0.08, 0.08, 0.08, 0.9), true],
	&"metal": [Color(1.0, 0.78, 0.35), 14, 6.5, 1.0, 0.012, 0.25, Color(0.15, 0.13, 0.12, 0.9), true],
	&"wood": [Color(0.55, 0.38, 0.2), 9, 3.5, 1.0, 0.03, 0.6, Color(0.18, 0.1, 0.05, 0.95), true],
	&"snow": [Color(0.95, 0.97, 1.0), 16, 2.2, 0.25, 0.05, 0.8, Color(0.55, 0.6, 0.7, 0.6), true],
	&"flesh": [Color(0.6, 0.04, 0.03), 12, 2.5, 1.0, 0.03, 0.45, Color(0.3, 0.0, 0.0, 0.9), false],
	&"gravel": [Color(0.5, 0.47, 0.42), 10, 3.0, 1.0, 0.025, 0.5, Color(0.1, 0.1, 0.1, 0.9), true],
	&"tile": [Color(0.8, 0.82, 0.78), 10, 3.5, 1.0, 0.02, 0.4, Color(0.1, 0.1, 0.1, 0.9), true],
}


static func params(surface: StringName) -> Array:
	return SURFACES.get(surface, SURFACES[&"concrete"])


static func takes_decal(surface: StringName) -> bool:
	return bool(params(surface)[7])
