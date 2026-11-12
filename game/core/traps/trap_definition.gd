# TrapDefinition — data for one map trap (GAME_DESIGN §12 generic rules, VESPER_PEAK §5 T1-T3):
# price, power, active / cooldown times, the damage rules and the area (an oriented box at the
# trap's area marker, or a ring sector around `ring_centre`). `effect` picks the kill behavior and
# the generic presentation preset: &"electric" (floor plates), &"steam" (jets), &"freeze" (coolant:
# zombies freeze and shatter). Lives with the map (maps/<map>/traps/<id>.tres).
# Authority: read-only data.
class_name TrapDefinition
extends Resource

@export var id: StringName = &""  # lower-case canonical id: &"t1"
@export var display_name: String = ""
@export var effect: StringName = &"electric"
@export var cost: int = 1000
@export var requires_power: bool = true
@export var active_time: float = 25.0
@export var cooldown: float = 60.0
@export var player_dps: float = 110.0  # downs a 100 HP player in ~1 s, Ironhide (250) in ~2.3 s
@export var special_fraction_per_s: float = 0.5  # trap-resistant enemies (Galvanics) lose 50 % max HP / s
@export var freeze_time: float = 2.5  # &"freeze": seconds frozen before shattering
@export_group("Area")
@export var shape: StringName = &"box"  # &"box" | &"ring"
@export var box_size: Vector3 = Vector3(4, 3, 15)  # local to the area marker (yaw only)
@export var ring_centre: Vector3 = Vector3.ZERO
@export var ring_inner: float = 19.0
@export var ring_outer: float = 25.0
@export var ring_arc_deg: float = 90.0  # centred on the area marker's angle around the centre
@export var ring_height: float = 3.0
@export_group("Presentation")
@export var color: Color = Color(0.4, 0.7, 1.0)


# Point `p` (world) inside the area described relative to `area` (the area marker's transform).
func contains(area: Transform3D, p: Vector3) -> bool:
	if shape == &"ring":
		var d: Vector3 = p - ring_centre
		if d.y < -0.5 or d.y > ring_height:
			return false
		var r: float = Vector2(d.x, d.z).length()
		if r < ring_inner or r > ring_outer:
			return false
		var m: Vector3 = area.origin - ring_centre
		var diff: float = absf(angle_difference(atan2(m.z, m.x), atan2(d.z, d.x)))
		return rad_to_deg(diff) <= ring_arc_deg * 0.5
	var lp: Vector3 = area.affine_inverse() * p
	var h: Vector3 = box_size * 0.5
	return absf(lp.x) <= h.x and absf(lp.z) <= h.z and lp.y >= -0.5 and lp.y <= box_size.y


# Sample points covering the area (presentation: plates, jets, mist), in world space.
func sample_points(area: Transform3D, spacing: float) -> PackedVector3Array:
	var out: PackedVector3Array = []
	if shape == &"ring":
		var m: Vector3 = area.origin - ring_centre
		var mid: float = atan2(m.z, m.x)
		var half: float = deg_to_rad(ring_arc_deg * 0.5)
		var r: float = (ring_inner + ring_outer) * 0.5
		var n: int = maxi(int(r * half * 2.0 / spacing), 2)
		for i: int in n + 1:
			var a: float = mid - half + 2.0 * half * float(i) / float(n)
			for rr: float in [ring_inner + 1.2, r, ring_outer - 1.2]:
				out.append(Vector3(ring_centre.x + cos(a) * rr, area.origin.y, ring_centre.z + sin(a) * rr))
		return out
	var nx: int = maxi(int(box_size.x / spacing), 1)
	var nz: int = maxi(int(box_size.z / spacing), 1)
	for ix: int in nx:
		for iz: int in nz:
			var lp: Vector3 = Vector3(
				-box_size.x * 0.5 + (ix + 0.5) * box_size.x / nx, 0.0, -box_size.z * 0.5 + (iz + 0.5) * box_size.z / nz
			)
			out.append(area * lp)
	return out
