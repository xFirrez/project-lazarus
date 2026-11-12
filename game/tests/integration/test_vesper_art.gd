# Step 13 (Vesper Peak art & atmosphere): AC-13.1 every gameplay node keeps its Step 8–12 transform
# (diff against maps/vesper_peak/gameplay_baseline.json, 0.01 m / 0.01 rad), AC-13.4 every zone has
# ambience, a reverb zone and at least one vignette, and the ten VESPER_PEAK §6.2 vignettes exist,
# AC-13.5 landmark sightlines (radar tower from the dock, the Courtyard, the Operating Theater dome
# and the Sky Bridge; the reactor core from the Z12 observation glass) by physics rays that treat
# `glass` bodies as see-through, plus the art layer's invariants: dressing never collides, the
# atmosphere profiles cover every zone, and the shadow budget follows the viewer (≤ 8).
extends GutTest

const MAP: String = "res://maps/vesper_peak/"
const TOL_POS: float = 0.01
const TOL_ROT: float = 0.01
const REQUIRED_VIGNETTES: Array[String] = [
	"V01_FamilyLuggage",
	"V02_Portrait",
	"V03_Room3Notation",
	"V04_VargaSeat",
	"V05_Coffins",
	"V06_FrozenOperator",
	"V07_ChalkTally",
	"V08_ChainedDrawer",
	"V09_Chamber6",
	"V10_HaemmerCap",
]
const TOWER_TOP: Vector3 = Vector3(-12, 53.6, -126)
const CORE: Vector3 = Vector3(28, -44, -50)
const REACH: float = 6.0

var _root: Node3D = null


func before_all() -> void:
	_root = (load(MAP + "vesper_peak.tscn") as PackedScene).instantiate() as Node3D
	add_child(_root)
	for i: int in 4:
		await get_tree().physics_frame


func after_all() -> void:
	_root.free()


func _zones() -> Array[VesperZone]:
	var out: Array[VesperZone] = []
	for c: Node in _root.get_children():
		if c is VesperZone:
			out.append(c as VesperZone)
	return out


func test_gameplay_markers_unchanged() -> void:
	var f: FileAccess = FileAccess.open(MAP + "gameplay_baseline.json", FileAccess.READ)
	var base: Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary)["nodes"]
	var live: Dictionary = _collect()
	var moved: PackedStringArray = PackedStringArray()
	for path: String in base:
		if not live.has(path):
			moved.append("%s missing" % path)
			continue
		var a: Array = base[path]
		var b: Array = live[path]
		var dp: float = Vector3(a[0], a[1], a[2]).distance_to(Vector3(b[0], b[1], b[2]))
		var dr: float = Vector3(a[3], a[4], a[5]).distance_to(Vector3(b[3], b[4], b[5]))
		if dp > TOL_POS or dr > TOL_ROT:
			moved.append("%s moved %.3f m / %.3f rad" % [path, dp, dr])
	for path: String in live:
		if not base.has(path):
			moved.append("%s added" % path)
	assert_eq(moved.size(), 0, "gameplay nodes unchanged: %s" % ", ".join(moved.slice(0, 8)))
	assert_eq(live.size(), base.size(), "%d gameplay nodes" % base.size())


# Mirrors tools/art/gen_gameplay_baseline.gd collect().
func _collect() -> Dictionary:
	var out: Dictionary = {}
	for z: Node in _root.get_children():
		var gp: Node = z.get_node_or_null(^"Gameplay")
		if gp != null:
			for n: Node in gp.find_children("*", "Node3D", true, false):
				_add(n as Node3D, out)
		var geo: Node = z.get_node_or_null(^"Geometry")
		if geo != null:
			for d: Node in geo.find_children("*", "NavDoor", true, false):
				_add(d as Node3D, out)
	return out


func _add(n: Node3D, out: Dictionary) -> void:
	var p: String = String(_root.get_path_to(n))
	if p.contains("@"):
		return
	var t: Transform3D = n.global_transform
	var e: Vector3 = t.basis.get_euler()
	out[p] = [t.origin.x, t.origin.y, t.origin.z, e.x, e.y, e.z]


func test_every_zone_has_ambience_reverb_and_a_vignette() -> void:
	var zones: Array[VesperZone] = _zones()
	assert_eq(zones.size(), 12)
	for z: VesperZone in zones:
		var amb: int = 0
		var rev: int = 0
		for c: Node in z.audio.get_children():
			if c is AmbienceEmitter:
				amb += 1
			elif c is ReverbZone:
				rev += 1
				assert_true(Audio.REVERBS.has((c as ReverbZone).preset), "%s reverb preset" % c.name)
		assert_gt(amb, 0, "%s has ambience" % z.zone_id)
		assert_gt(rev, 0, "%s has a reverb zone" % z.zone_id)
		assert_gt(z.vignettes.size(), 0, "%s has a vignette" % z.zone_id)
		for v: Node3D in z.vignettes:
			assert_gt(v.get_child_count() + _decals_near(z, v.global_position), 0, "%s is dressed" % v.name)


func _decals_near(z: VesperZone, p: Vector3) -> int:
	var n: int = 0
	for d: Node in z.art.find_children("*", "Decal", true, false):
		if (d as Decal).global_position.distance_to(p) < 3.0:
			n += 1
	return n


func test_ten_storytelling_vignettes() -> void:
	var found: Dictionary = {}
	for v: Node in get_tree().get_nodes_in_group(&"vignette"):
		found[String(v.get_meta(&"vignette"))] = v
	for id: String in REQUIRED_VIGNETTES:
		assert_true(found.has(id), "vignette %s (VESPER_PEAK §6.2)" % id)
	assert_true(found.has("S1_DirectorsOffice"), "S1 office dressed")


func test_art_layer_never_collides() -> void:
	var bad: PackedStringArray = PackedStringArray()
	for z: VesperZone in _zones():
		for b: Node in z.art.find_children("*", "CollisionObject3D", true, false):
			var co: CollisionObject3D = b as CollisionObject3D
			if co.collision_layer != 0:
				bad.append(String(co.get_path()))
	assert_eq(bad.size(), 0, "art bodies with collision: %s" % ", ".join(bad))
	var props: int = 0
	for z2: VesperZone in _zones():
		props += z2.art.find_children("Prop_*", "", true, false).size()
	assert_gt(props, 100, "dressed with props (%d)" % props)


func test_atmosphere_profiles_cover_every_zone() -> void:
	var set_res: AtmosphereSet = load(MAP + "art/zone_atmosphere.tres") as AtmosphereSet
	assert_not_null(set_res)
	for z: VesperZone in _zones():
		var p: AtmosphereProfile = set_res.profiles.get(z.zone_id, null) as AtmosphereProfile
		assert_not_null(p, "profile %s" % z.zone_id)
		if p != null and z.global_position.y >= 0.0 and z.zone_id in [&"Z08", &"Z09", &"Z10", &"Z11", &"Z12", &"Z13"]:
			assert_eq(p.snow, 0.0, "%s underground: no snow" % z.zone_id)
	var art: VesperArt = _root.get(&"art") as VesperArt
	assert_not_null(art)
	assert_eq(art.atmosphere.zone_at(Vector3(28, -7, -49)), &"Z06")
	assert_eq(art.atmosphere.zone_at(Vector3(28, -47, -50 + 22)), &"Z13")


# Physics ray from a to b that passes through `glass` bodies; returns the blocking collider or null.
# Hitting the landmark itself (within REACH of the target point: the dish, a tower leg) counts as
# seeing it.
func _blocked(a: Vector3, b: Vector3) -> Object:
	var space: PhysicsDirectSpaceState3D = _root.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for i: int in 16:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, 1, exclude)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return null
		var c: Object = hit["collider"]
		if (hit["position"] as Vector3).distance_to(b) <= REACH or _is_landmark(c):
			return null
		if c is Node and (c as Node).get_meta(&"glass", false):
			exclude.append(hit["rid"])
			continue
		return c
	return null


# The radar tower's own legs / dish are the landmark.
static func _is_landmark(c: Object) -> bool:
	return c is Node and (String((c as Node).name).begins_with("TowerLeg") or (c as Node).name == &"Dish")


func test_landmark_sightlines() -> void:
	var views: Array = [
		["Z01 gondola dock", Vector3(-4.5, 1.7, -12.2), TOWER_TOP],
		["Z06 fountain north", Vector3(28, -6.3, -38), TOWER_TOP],
		["Z06 motor pool", Vector3(10, -6.3, -60), TOWER_TOP],
		["Z06 east beds", Vector3(50, -6.3, -42), TOWER_TOP],
		["Z06 greenhouse", Vector3(40, -6.3, -68), TOWER_TOP],
		["Z05 dome (east gallery)", Vector3(82.0, 8.8, -88), TOWER_TOP],
		["Sky Bridge", Vector3(42.0, 14.0, -101.0), TOWER_TOP],
		["Z12 observation glass", Vector3(64.6, -26.4, -43.5), CORE],
	]
	for v: Array in views:
		var c: Object = _blocked(v[1], v[2])
		assert_null(c, "%s sees its landmark (blocked by %s)" % [v[0], (c as Node).get_path() if c is Node else ""])


func test_shadow_budget_is_local() -> void:
	var art: VesperArt = _root.get(&"art") as VesperArt
	var cam: Camera3D = Camera3D.new()
	_root.add_child(cam)
	cam.current = true
	var worst: int = 0
	for p: Vector3 in [
		Vector3(0, 3, 0), Vector3(53, -5, -3), Vector3(74, 7, -88), Vector3(-34, -10, -19), Vector3(28, -45, -40)
	]:
		cam.global_position = p
		art.shadows.refresh()
		var n: int = 0
		for l: Node in get_tree().get_nodes_in_group(&"shadow_light"):
			if l is Light3D and not l is DirectionalLight3D and (l as Light3D).shadow_enabled:
				n += 1
		worst = maxi(worst, n)
		assert_lte(n, Graphics.preset.max_shadow_lights, "shadow lights at %s" % p)
	assert_lte(worst, 8, "never more than 8 shadow-casting lights")
	cam.queue_free()
