# VesperZoneArt — base of VesperZone holding the zone's shared nodes and the Step 13 art-pass
# helpers: props (VesperProps), imported prop GLBs, visual-only deco boxes, decals, signage, FX
# and fog volumes (AtmosFx), reverb zones, environmental-storytelling vignettes, light fixtures
# with animated / powered lights, greybox skinning and the automatic trim pass. Everything the
# helpers create lives under `Art/` (or `Lighting/` / `Audio/`) and is visual only: no collision,
# never a gameplay node (D-076).
# Authority: static map presentation.
class_name VesperZoneArt
extends Node3D

const CASCADE_STEP: float = 0.7  # power-on cascade delay per zone step (s)
const STYLES: Dictionary = {
	&"concrete": ["res://content/materials/stone_grey.tres", &"concrete"],
	&"marble": ["res://content/materials/marble_floor.tres", &"tile"],
	&"tile": ["res://content/materials/marble_floor_wet.tres", &"tile"],
	&"wood": ["res://content/materials/wood_dark.tres", &"wood"],
	&"metal": ["res://content/materials/metal_dark.tres", &"metal"],
	&"olive": ["res://content/materials/metal_olive.tres", &"metal"],
	&"snow": ["res://content/materials/cobble_snow.tres", &"snow"],
	&"cobble": ["res://content/materials/cobble_icy.tres", &"gravel"],
	&"plaster": ["res://content/materials/plaster_rose.tres", &"concrete"],
	&"facade": ["res://content/materials/stone_facade.tres", &"concrete"],
	&"stone": ["res://content/materials/stone_grey.tres", &"concrete"],
	&"ice": ["res://content/materials/ice.tres", &"tile"],
	&"brass": ["res://content/materials/brass.tres", &"metal"],
	&"vesperite": ["res://content/materials/vesperite.tres", &"tile"],
	&"sandbag": ["res://content/materials/sandbag.tres", &"gravel"],
}

# Ambience bed preset → [AmbienceLibrary event, volume dB, unit size, max distance].
const AMBIENCE: Dictionary = {
	&"interior_wind": [&"amb_storm_wind", -20.0, 8.0, 30.0],
	&"exterior_storm": [&"amb_storm_wind", -8.0, 30.0, 0.0],
	&"generator_hall": [&"amb_machinery", -10.0, 10.0, 40.0],
	&"boiler_room": [&"amb_furnace", -10.0, 8.0, 32.0],
	&"tunnel_drip": [&"amb_drips", -8.0, 8.0, 30.0],
	&"refrigeration": [&"amb_fridge", -12.0, 8.0, 28.0],
	&"interior_hum": [&"amb_room_tone", -14.0, 8.0, 28.0],
	&"lab_hum": [&"amb_buzz", -16.0, 6.0, 26.0],
	&"reactor_drone": [&"amb_reactor", -4.0, 25.0, 0.0],
	&"radio_static": [&"amb_radio", -14.0, 4.0, 18.0],
	&"room_tone": [&"amb_room_tone", -16.0, 6.0, 24.0],
}

const DECALS: String = "res://content/decals/%s.png"

# kind -> [width, depth, height, wall-mounted (no floor footprint)]
const FURNITURE: Dictionary = {
	&"radiator": [1.05, 0.2, 0.85, false],
	&"cabinet": [0.9, 0.45, 1.9, false],
	&"chair": [0.5, 0.5, 1.0, false],
	&"bench": [2.2, 0.5, 1.0, false],
	&"filing_cabinet": [0.5, 0.62, 1.3, false],
	&"bookcase": [1.8, 0.42, 2.6, false],
	&"wheelchair": [0.7, 0.65, 1.0, false],
	&"trolley": [0.85, 0.52, 1.1, false],
	&"notice_board": [1.2, 0.06, 2.1, true],
	&"extinguisher": [0.32, 0.16, 1.7, true],
	&"sink": [0.6, 0.46, 1.75, false],
	&"desk_cluttered": [1.5, 0.76, 1.2, false],
	&"crate": [0.92, 0.82, 0.82, false],
	&"locker": [0.92, 0.5, 1.95, false],
	&"shelf": [1.6, 0.46, 2.1, false],
	&"jar_shelf": [1.6, 0.46, 2.1, false],
	&"pallet": [1.2, 1.2, 0.65, false],
	&"barrel": [0.62, 0.62, 0.9, false],
	&"barrel_cluster": [1.9, 1.3, 0.9, false],
	&"pipe_stack": [2.25, 0.9, 0.5, false],
	&"toolrack": [1.6, 0.06, 2.0, true],
	&"wall_pipes": [0.85, 0.32, 3.2, true],
	&"gas_tank": [0.3, 0.3, 1.5, false],
	&"lab_bench": [2.5, 0.86, 1.3, false],
	&"bed": [1.0, 2.05, 1.05, false],
	&"rocks": [1.9, 1.4, 0.9, false],
	&"scaffold": [2.1, 1.0, 4.0, false],
	&"drum_rack": [1.95, 0.62, 0.95, false],
	&"rubble": [1.4, 1.0, 0.35, false],
	&"papers": [0.9, 0.8, 0.05, false],
	&"book_pile": [0.5, 0.4, 0.3, false],
	&"mop_bucket": [0.45, 0.45, 1.3, false],
}
# kit -> [[kind, weight], ...]
const FURNISH_KITS: Dictionary = {
	"sanatorium":
	[
		[&"radiator", 3],
		[&"cabinet", 2],
		[&"chair", 2],
		[&"bench", 2],
		[&"filing_cabinet", 1],
		[&"bookcase", 1],
		[&"wheelchair", 1],
		[&"notice_board", 2],
		[&"extinguisher", 1],
		[&"desk_cluttered", 1],
		[&"crate", 1],
		[&"papers", 2],
		[&"rubble", 1],
		[&"book_pile", 1],
	],
	"ward":
	[
		[&"bed", 3],
		[&"radiator", 2],
		[&"trolley", 2],
		[&"wheelchair", 2],
		[&"cabinet", 2],
		[&"sink", 2],
		[&"locker", 1],
		[&"notice_board", 1],
		[&"extinguisher", 1],
		[&"papers", 2],
		[&"rubble", 1],
		[&"mop_bucket", 1],
		[&"chair", 1],
	],
	"military":
	[
		[&"locker", 3],
		[&"crate", 3],
		[&"filing_cabinet", 2],
		[&"shelf", 1],
		[&"notice_board", 2],
		[&"extinguisher", 1],
		[&"pallet", 2],
		[&"barrel", 1],
		[&"desk_cluttered", 1],
		[&"papers", 2],
		[&"rubble", 1],
	],
	"industrial":
	[
		[&"barrel_cluster", 2],
		[&"barrel", 2],
		[&"crate", 2],
		[&"pipe_stack", 2],
		[&"toolrack", 2],
		[&"wall_pipes", 3],
		[&"gas_tank", 1],
		[&"shelf", 1],
		[&"locker", 1],
		[&"pallet", 2],
		[&"extinguisher", 1],
		[&"rubble", 2],
		[&"drum_rack", 1],
	],
	"lab":
	[
		[&"lab_bench", 2],
		[&"cabinet", 2],
		[&"trolley", 2],
		[&"sink", 2],
		[&"gas_tank", 2],
		[&"filing_cabinet", 1],
		[&"notice_board", 1],
		[&"extinguisher", 1],
		[&"locker", 1],
		[&"jar_shelf", 1],
		[&"papers", 2],
		[&"rubble", 1],
		[&"mop_bucket", 1],
	],
	"cavern": [[&"rocks", 4], [&"rubble", 3], [&"crate", 1], [&"barrel", 1], [&"scaffold", 1], [&"pallet", 1]],
	"exterior": [[&"crate", 3], [&"barrel_cluster", 2], [&"pallet", 2], [&"barrel", 2], [&"rocks", 2], [&"rubble", 2]],
}
const FURNISH_FILL: float = 0.62  # chance a free wall slot gets something
const LIGHT_AREA: float = 55.0
const AUTO_LIGHTS: Dictionary = {
	"sanatorium": [&"pendant", Color(1.0, 0.8, 0.55), 1.2],
	"military": [&"fluoro", Color(0.85, 0.95, 0.88), 0.5],
	"lab": [&"fluoro", Color(0.85, 1.0, 1.0), 0.5],
	"industrial": [&"caged_bulb", Color(1.0, 0.72, 0.42), 0.0],
	"cavern": [&"caged_bulb", Color(1.0, 0.75, 0.5), 0.0],
}

static var _mats: Dictionary = {}
static var _decal_tex: Dictionary = {}

@export var zone_id: StringName = &""
@export var display_name: String = ""
@export var cascade: int = 0  # power-on order (lights wake after cascade × CASCADE_STEP s)
## Automatic trim pass: "sanatorium" (wainscot + baseboard + crown), "military" (baseboard +
## cable tray), "industrial" (pipes + soot band), "lab" (tile band + baseboard), "exterior" (snow
## drifts at wall feet), "cavern" (rock rubble at wall feet), "" = none.
@export var trim: String = ""
## Automatic furnishing kit placed along the walls after dressing (map quality pass): one of
## FURNISH_KITS' keys; "" = use `trim`'s kit, "none" = no furnishing.
@export var furnish: String = ""

var geometry: Node3D = null
var gameplay: Node3D = null
var lighting: Node3D = null
var audio: Node3D = null
var art: Node3D = null
var vignettes: Array[Node3D] = []
var furnished: int = 0
var auto_lights: int = 0
var _trim_batch: MeshBatch = null
var _spinners: Array = []  # [Node3D, axis, rad/s]


func _process(delta: float) -> void:
	for s: Array in _spinners:
		var n: Node3D = s[0] as Node3D
		if is_instance_valid(n):
			n.rotate_object_local(s[1] as Vector3, float(s[2]) * delta)


# Rotates an art node forever (radar dish, fans): local presentation.
func spin(n: Node3D, axis: Vector3, speed: float) -> void:
	_spinners.append([n, axis.normalized(), speed])


static func _basis_along(dir: Vector3) -> Basis:
	# Local -Z points along `dir` (pitched), local Y is the slope normal.
	var up: Vector3 = Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.FORWARD
	return Basis.looking_at(dir.normalized(), up)


func _mat(style: StringName) -> Material:
	if not _mats.has(style):
		var st: Array = STYLES.get(style, STYLES[&"concrete"])
		var m: Material = load(st[0]) as Material
		if m == null:
			var sm: StandardMaterial3D = StandardMaterial3D.new()
			sm.albedo_color = Color(0.5, 0.5, 0.5)
			m = sm
		_mats[style] = m
	return _mats[style]


func ambience(pos: Vector3, preset: StringName, volume_offset: float = 0.0) -> AmbienceEmitter:
	var cfg: Array = AMBIENCE.get(preset, AMBIENCE[&"room_tone"])
	var e: AmbienceEmitter = AmbienceEmitter.new()
	e.name = "Ambience_%s_%d" % [preset, audio.get_child_count()]
	e.position = pos
	e.set_meta(&"ambience", preset)
	e.event = cfg[0]
	e.volume_db = float(cfg[1]) + volume_offset
	e.spatial = true
	e.unit_size = float(cfg[2])
	e.max_distance = float(cfg[3])
	audio.add_child(e)
	return e


static func clear_cache() -> void:
	_mats.clear()
	_decal_tex.clear()


func _art_group(group_name: String) -> Node3D:
	var g: Node3D = art.get_node_or_null(group_name) as Node3D
	if g == null:
		g = Node3D.new()
		g.name = group_name
		art.add_child(g)
	return g


func prop(
	kind: StringName, pos: Vector3, yaw: float = 0.0, parent: Node3D = null, tilt: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mi: MeshInstance3D = VesperProps.make(kind)
	mi.position = pos
	mi.rotation = Vector3(tilt.x, yaw, tilt.z)
	(parent if parent != null else _art_group("Props")).add_child(mi)
	return mi


# A row of props from a to b (inclusive), every `step` metres.
func prop_row(kind: StringName, a: Vector3, b: Vector3, step: float, yaw: float = 0.0) -> void:
	var n: int = maxi(int(a.distance_to(b) / step), 0)
	for i: int in n + 1:
		prop(kind, a.lerp(b, float(i) / float(maxi(n, 1))), yaw)


# Instances an imported prop GLB for dressing; its colliders are stripped (visual only).
func glb(path: String, pos: Vector3, yaw: float = 0.0, scale_f: float = 1.0) -> Node3D:
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	for b: Node in n.find_children("*", "CollisionObject3D", true, false):
		(b as CollisionObject3D).collision_layer = 0
		(b as CollisionObject3D).collision_mask = 0
		for c: Node in b.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).disabled = true
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = VesperProps.CULL
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * scale_f
	_art_group("Props").add_child(n)
	return n


# Visual-only box (no collision): trims, panels, rubble, set dressing.
func deco(
	node_name: String, center: Vector3, size: Vector3, style: StringName = &"concrete", rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(style) if STYLES.has(style) else VesperProps.m(style)
	mi.position = center
	mi.rotation = rot
	if size.length() < 4.0:
		mi.visibility_range_end = 60.0
	_art_group("Deco").add_child(mi)
	return mi


# Projected decal: `normal` = the surface's outward normal (the decal projects against it).
func decal(
	tex: StringName,
	pos: Vector3,
	size: Vector2,
	normal: Vector3 = Vector3.UP,
	spin: float = 0.0,
	tint: Color = Color.WHITE,
	depth: float = 0.4
) -> Decal:
	if not _decal_tex.has(tex):
		_decal_tex[tex] = load(DECALS % tex) as Texture2D
	var d: Decal = Decal.new()
	d.name = "Decal_%s" % tex
	d.texture_albedo = _decal_tex[tex]
	d.modulate = tint
	d.size = Vector3(size.x, depth, size.y)
	d.cull_mask = 1
	d.distance_fade_enabled = true
	d.distance_fade_begin = 30.0
	d.distance_fade_length = 10.0
	var up: Vector3 = normal.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = ref.cross(up).normalized()
	var z: Vector3 = x.cross(up).normalized()
	d.basis = Basis(x, up, z) * Basis(Vector3.UP, spin)
	d.position = pos
	_art_group("Decals").add_child(d)
	return d


# Painted stencil / sign text (original Group Vesper and sanatorium branding).
func signage(
	text: String, pos: Vector3, yaw: float, px: int = 48, color: Color = Color(0.9, 0.88, 0.8), outline: bool = false
) -> Label3D:
	var l: Label3D = Label3D.new()
	l.name = "Sign"
	l.text = text
	l.font_size = px
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 6 if outline else 0
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	l.visibility_range_end = 40.0
	_art_group("Signage").add_child(l)
	return l


func fx(kind: AtmosFx.Kind, pos: Vector3, extents: Vector3 = Vector3.ONE, dir: Vector3 = Vector3.UP) -> GPUParticles3D:
	var p: GPUParticles3D = AtmosFx.emitter(kind, pos, extents, dir)
	_art_group("Fx").add_child(p)
	return p


func fog(pos: Vector3, size: Vector3, albedo: Color, density: float = 0.5, emission: Color = Color.BLACK) -> FogVolume:
	var f: FogVolume = AtmosFx.fog(pos, size, albedo, density, emission)
	_art_group("Fx").add_child(f)
	return f


func reverb(preset: StringName, lo: Vector3, hi: Vector3, amount: float = 0.8) -> ReverbZone:
	var r: ReverbZone = ReverbZone.new()
	r.name = "Reverb_%s_%d" % [preset.trim_prefix("Reverb_"), audio.get_child_count()]
	r.preset = preset
	r.size = (hi - lo).abs()
	r.position = (lo + hi) * 0.5
	r.amount = amount
	r.zone = zone_id
	audio.add_child(r)
	return r


# Environmental storytelling vignette (VESPER_PEAK §6.2): a named group the props hang off.
func vignette(id: String, pos: Vector3, title: String, yaw: float = 0.0) -> Node3D:
	var v: Node3D = Node3D.new()
	v.name = "Vignette_%s" % id
	v.position = pos
	v.rotation.y = yaw
	v.set_meta(&"vignette", id)
	v.set_meta(&"title", title)
	v.add_to_group(&"vignette")
	_art_group("Vignettes").add_child(v)
	vignettes.append(v)
	return v


# A light with its fixture: `fixture` prop at the bulb, an animated / powered light, optional
# shadow (budgeted by Graphics via `shadow_light` + priority).
# gdlint: ignore=function-arguments-number
func fixture_light(
	fixture: StringName,
	pos: Vector3,
	color: Color,
	energy: float = 1.2,
	rng: float = 10.0,
	pattern: PoweredLight.Pattern = PoweredLight.Pattern.NONE,
	powered: bool = true,
	shadow_priority: int = 0,
	yaw: float = 0.0
) -> Light3D:
	if fixture != &"":
		prop(fixture, pos, yaw)
	var o: OmniLight3D = OmniLight3D.new()
	o.light_color = color
	o.light_energy = energy
	o.omni_range = rng
	o.omni_attenuation = 1.4
	o.distance_fade_enabled = true
	o.distance_fade_begin = 35.0
	o.distance_fade_length = 12.0
	o.light_specular = 0.4
	if shadow_priority > 0:
		o.shadow_enabled = true
		o.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID  # 2 passes instead of 6
		o.add_to_group(&"shadow_light")
		o.set_meta(&"shadow_priority", shadow_priority)
	var pl: PoweredLight = PoweredLight.new()
	pl.name = "ArtLight_%d" % lighting.get_child_count()
	pl.always_on = not powered
	pl.pattern = pattern
	pl.delay = cascade * CASCADE_STEP + randf_range(0.0, 0.3)
	pl.off_fraction = 0.12 if powered else 0.0
	pl.position = pos + (Vector3(0, -0.15, 0) if fixture != &"" else Vector3.ZERO)
	pl.add_child(o)
	lighting.add_child(pl)
	return o


func spot_light(
	pos: Vector3,
	target: Vector3,
	color: Color,
	energy: float,
	rng: float,
	angle: float,
	powered: bool = false,
	pattern: PoweredLight.Pattern = PoweredLight.Pattern.NONE
) -> SpotLight3D:
	var s: SpotLight3D = SpotLight3D.new()
	s.light_color = color
	s.light_energy = energy
	s.spot_range = rng
	s.spot_angle = angle
	s.light_volumetric_fog_energy = 2.0
	s.distance_fade_enabled = true
	s.distance_fade_begin = 60.0
	s.distance_fade_length = 20.0
	var pl: PoweredLight = PoweredLight.new()
	pl.name = "ArtSpot_%d" % lighting.get_child_count()
	pl.always_on = not powered
	pl.pattern = pattern
	pl.delay = cascade * CASCADE_STEP
	pl.add_child(s)
	lighting.add_child(pl)
	pl.look_at_from_position(pos, target, Vector3.UP if absf((target - pos).normalized().y) < 0.98 else Vector3.FORWARD)
	return s


# --- automatic furnishing (map quality pass) --------------------------------------------------------


# Walks the zone's straight wall boxes (like the trim pass) and stands kit props against both
# faces where: there is floor under the slot at the wall's base, the slot is inside one of the
# zone's volumes, nothing gameplay (doors, windows, wall-buys, machines, spawners, links, clips)
# or already-authored dressing is near, the prop intersects no collider, and 1.4 m in front of it
# stays clear so passages keep their width. Visual only (D-076); deterministic per zone.
func _auto_furnish() -> void:
	var kit_name: String = furnish if furnish != "" else trim
	if kit_name == "none" or not FURNISH_KITS.has(kit_name):
		return
	var kit: Array = FURNISH_KITS[kit_name]
	var total_w: int = 0
	for k: Array in kit:
		total_w += int(k[1])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(zone_id)) + 7
	var solids: Array[AABB] = []
	var walls: Array[StaticBody3D] = []
	for b: Node in geometry.find_children("*", "StaticBody3D", true, false):
		var body: StaticBody3D = b as StaticBody3D
		if body.collision_layer & 1 == 0:
			continue
		var bb: AABB = _collider_aabb(body)
		if bb.size == Vector3.ZERO:
			continue
		solids.append(bb)
		if body.get_parent() == geometry and body.basis.is_equal_approx(Basis.IDENTITY):
			walls.append(body)
	var volumes: Array[ZoneVolume] = []
	var avoid: PackedVector3Array = PackedVector3Array()
	for g: Node in gameplay.find_children("*", "Node3D", true, false):
		if g is ZoneVolume:
			volumes.append(g as ZoneVolume)
		else:
			avoid.append((g as Node3D).global_position)
	for d: Node in geometry.find_children("*", "NavDoor", true, false):
		avoid.append((d as Node3D).global_position)
	var dressed: PackedVector3Array = PackedVector3Array()
	for n: Node in art.find_children("*", "Node3D", true, false):
		if n is MeshInstance3D or n is Label3D or n is Decal:
			dressed.append((n as Node3D).global_position)
	var holder: Node3D = _art_group("Furnish")
	for body: StaticBody3D in walls:
		var name_s: String = String(body.name)
		if name_s.contains("Bay") or name_s.contains("Vent") or name_s.contains("Closet") or name_s.contains("Seal"):
			continue
		if body.get_meta(&"wall_part", &"") == &"lintel":
			continue
		var bb: AABB = _collider_aabb(body)
		var sz: Vector3 = bb.size
		var along_z: bool = sz.x <= 0.6 and sz.z >= 2.4
		var along_x: bool = sz.z <= 0.6 and sz.x >= 2.4
		if not (along_z or along_x) or sz.y < 2.2:
			continue
		var y0: float = bb.position.y
		var a0: float = bb.position.z if along_z else bb.position.x
		var a1: float = bb.end.z if along_z else bb.end.x
		for side: float in [-1.0, 1.0]:
			var nrm: Vector3 = Vector3(side, 0, 0) if along_z else Vector3(0, 0, side)
			var face: float = (
				(bb.get_center().x if along_z else bb.get_center().z) + side * (sz.x if along_z else sz.z) * 0.5
			)
			var t: float = a0 + rng.randf_range(0.5, 1.4)
			while t < a1 - 0.5:
				var pick: int = rng.randi_range(1, total_w)
				var kind: StringName = kit[0][0]
				for k: Array in kit:
					pick -= int(k[1])
					if pick <= 0:
						kind = k[0]
						break
				var spec: Array = FURNITURE[kind]
				var w: float = float(spec[0])
				var dep: float = float(spec[1])
				var hgt: float = float(spec[2])
				var centre_a: float = t + w * 0.5
				if centre_a + w * 0.5 > a1 - 0.3:
					break
				var place: bool = rng.randf() < FURNISH_FILL
				var gap: float = rng.randf_range(0.3, 1.6)
				if place:
					var off: float = dep * 0.5 + 0.03
					var base: Vector3 = Vector3(face, y0, centre_a) if along_z else Vector3(centre_a, y0, face)
					var pos: Vector3 = base + nrm * off
					if _furnish_ok(pos, nrm, w, dep, hgt, bool(spec[3]), y0, solids, volumes, avoid, dressed):
						var mi: MeshInstance3D = prop(
							kind, pos, atan2(nrm.x, nrm.z) + rng.randf_range(-0.04, 0.04), holder
						)
						mi.set_meta(&"furnish", true)
						dressed.append(pos)
						furnished += 1
						t = centre_a + w * 0.5 + gap
						continue
				t += 0.8 + gap * 0.5


# gdlint: ignore=function-arguments-number
func _furnish_ok(
	pos: Vector3,
	nrm: Vector3,
	w: float,
	dep: float,
	hgt: float,
	mounted: bool,
	y0: float,
	solids: Array[AABB],
	volumes: Array[ZoneVolume],
	avoid: PackedVector3Array,
	dressed: PackedVector3Array
) -> bool:
	var inside: bool = false
	for v: ZoneVolume in volumes:
		if v.contains(pos + Vector3(0, 0.5, 0)) and v.contains(pos + nrm * (dep * 0.5 + 1.2) + Vector3(0, 0.5, 0)):
			inside = true
			break
	if not inside:
		return false
	var flat: Vector2 = Vector2(pos.x, pos.z)
	for a: Vector3 in avoid:
		if absf(a.y - pos.y) < 3.5 and Vector2(a.x, a.z).distance_to(flat) < 1.9 + w * 0.5:
			return false
	for dpos: Vector3 in dressed:
		if absf(dpos.y - pos.y) < 3.0 and Vector2(dpos.x, dpos.z).distance_to(flat) < 1.0 + w * 0.5:
			return false
	var tangent: Vector3 = Vector3(nrm.z, 0, nrm.x).abs()
	var half: Vector3 = tangent * (w * 0.5) + nrm.abs() * (dep * 0.5)
	var body: AABB = AABB(pos - half + Vector3(0, 0.06, 0), half * 2.0 + Vector3(0, maxf(hgt - 0.1, 0.05), 0))
	# the passage in front (shoulder height) and the prop itself must be free of colliders
	var lane_c: Vector3 = pos + nrm * (dep * 0.5 + 0.75)
	var lane_half: Vector3 = tangent * (w * 0.5) + nrm.abs() * 0.7
	var lane: AABB = AABB(lane_c - lane_half + Vector3(0, 0.3, 0), lane_half * 2.0 + Vector3(0, 1.5, 0))
	var floor_found: bool = mounted
	for s: AABB in solids:
		if s.intersects(body):
			return false
		if s.intersects(lane):
			return false
		if not floor_found and absf(s.end.y - y0) < 0.12 and s.has_point(Vector3(pos.x, s.get_center().y, pos.z)):
			floor_found = true
	return floor_found


static func _collider_aabb(body: StaticBody3D) -> AABB:
	for c: Node in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var sz: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
			return body.global_transform * (c as CollisionShape3D).transform * AABB(-sz * 0.5, sz)
	return AABB()


# Ceiling fixtures per roofed room so no room is left in the dark (map quality pass): about one
# light per LIGHT_AREA m² of floor, counting the lights the zone already has inside the room.
# Unshadowed, powered (dim until the power is on), fixture style per trim.
func _auto_light() -> void:
	if not AUTO_LIGHTS.has(trim):
		return
	var spec: Array = AUTO_LIGHTS[trim]
	var existing: PackedVector3Array = PackedVector3Array()
	for l: Node in lighting.find_children("*", "Light3D", true, false):
		existing.append((l as Node3D).global_position)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(String(zone_id)) + 31
	for r: Array in get(&"rooms"):
		var lo: Vector3 = r[0]
		var hi: Vector3 = r[1]
		var size: Vector3 = hi - lo
		var area: float = size.x * size.z
		var have: int = 0
		for e: Vector3 in existing:
			if e.x > lo.x and e.x < hi.x and e.z > lo.z and e.z < hi.z and e.y > lo.y - 0.5 and e.y < hi.y + 0.5:
				have += 1
		var want: int = maxi(1, roundi(area / LIGHT_AREA))
		if have >= want:
			continue
		var nx: int = maxi(1, roundi(sqrt(float(want) * size.x / size.z)))
		var nz: int = maxi(1, ceili(float(want) / nx))
		var cell: Vector2 = Vector2(size.x / nx, size.z / nz)
		var rng_len: float = clampf(cell.length() * 0.85, 7.0, 14.0)
		for ix: int in nx:
			for iz: int in nz:
				var p: Vector3 = Vector3(
					lo.x + cell.x * (ix + 0.5), hi.y - float(spec[2]) - 0.05, lo.z + cell.y * (iz + 0.5)
				)
				var crowded: bool = false
				for e: Vector3 in existing:
					if Vector2(e.x, e.z).distance_to(Vector2(p.x, p.z)) < 3.0 and absf(e.y - p.y) < 3.0:
						crowded = true
						break
				if crowded:
					continue
				var pattern: PoweredLight.Pattern = (
					PoweredLight.Pattern.FLICKER if rng.randf() < 0.18 else PoweredLight.Pattern.NONE
				)
				fixture_light(spec[0], p, spec[1], 0.9, rng_len, pattern, true, 0, 0.0 if size.x < size.z else PI / 2.0)
				existing.append(p)
				auto_lights += 1


# --- automatic trims ------------------------------------------------------------------------------


func _trim_add(size: Vector3, pos: Vector3, mat_key: StringName, rot: Vector3 = Vector3.ZERO) -> void:
	if _trim_batch == null:
		_trim_batch = MeshBatch.new()
	var mat: Material = _mat(mat_key) if STYLES.has(mat_key) else VesperProps.m(mat_key)
	_trim_batch.box(size, pos, mat, rot)


# Walks the zone's wall boxes (tall, thin, long) and adds architectural detail along both faces
# per `trim` style, merged into one mesh. Visual only; sits within 6 cm of the wall face.
func _auto_trim() -> void:
	var n_walls: int = 0
	for b: Node in geometry.get_children():
		if not b is StaticBody3D:
			continue
		var body: StaticBody3D = b as StaticBody3D
		if (
			body.name.contains("Bay")
			or body.name.contains("Vent")
			or body.name.contains("Closet")
			or not body.basis.is_equal_approx(Basis.IDENTITY)
		):
			continue
		var mi: MeshInstance3D = body.get_child(0) as MeshInstance3D if body.get_child_count() > 0 else null
		if mi == null or not mi.mesh is BoxMesh:
			continue
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		var along_z: bool = sz.x <= 0.6 and sz.z >= 1.2
		var along_x: bool = sz.z <= 0.6 and sz.x >= 1.2
		if not (along_z or along_x) or sz.y < 2.0:
			continue
		n_walls += 1
		var c: Vector3 = body.position
		var y0: float = c.y - sz.y * 0.5
		var y1: float = c.y + sz.y * 0.5
		var lintel: bool = body.get_meta(&"wall_part", &"") == &"lintel"
		var length: float = sz.z if along_z else sz.x
		var half_t: float = (sz.x if along_z else sz.z) * 0.5
		for side: float in [-1.0, 1.0]:
			var off: Vector3 = Vector3(side * half_t, 0, 0) if along_z else Vector3(0, 0, side * half_t)
			var strip: Callable = func(h: float, y: float, depth: float, mat: StringName) -> void:
				var s3: Vector3 = Vector3(depth, h, length) if along_z else Vector3(length, h, depth)
				_trim_add(s3, Vector3(c.x, y, c.z) + off + off.normalized() * depth * 0.5, mat)
			if lintel:
				if trim == "sanatorium" and sz.y < 8.0:
					strip.call(0.22, y1 - 0.11, 0.07, &"plaster")
				continue
			match trim:
				"sanatorium":
					strip.call(1.1, y0 + 0.55, 0.03, &"wood")
					strip.call(0.08, y0 + 1.14, 0.05, &"wood")
					strip.call(0.16, y0 + 0.08, 0.05, &"wood")
					if sz.y < 8.0:
						strip.call(0.22, y1 - 0.11, 0.07, &"plaster")
				"military":
					strip.call(0.14, y0 + 0.07, 0.04, &"olive")
					if sz.y >= 2.8:
						strip.call(0.06, y0 + 2.5, 0.12, &"metal")
				"industrial":
					strip.call(0.5, y0 + 0.25, 0.02, &"black")
					if sz.y >= 3.0:
						var py: float = minf(y1 - 0.5, y0 + 3.0)
						var pipe_r: float = 0.09
						var pc: Vector3 = Vector3(c.x, py, c.z) + off + off.normalized() * 0.16
						var rot: Vector3 = Vector3(PI / 2.0, 0, 0) if along_z else Vector3(0, 0, PI / 2.0)
						if _trim_batch == null:
							_trim_batch = MeshBatch.new()
						_trim_batch.cyl(pipe_r, length, pc, VesperProps.m(&"rust"), rot)
						_trim_batch.cyl(pipe_r * 0.6, length, pc + Vector3(0, -0.28, 0), _mat(&"metal"), rot)
				"lab":
					strip.call(1.4, y0 + 0.7, 0.02, &"tile_white")
					strip.call(0.12, y0 + 0.06, 0.04, &"metal")
					strip.call(0.05, y0 + 1.42, 0.03, &"book_green")
				"exterior":
					if y0 < c.y and sz.y >= 2.4:
						strip.call(0.35, y0 + 0.12, 0.45, &"snow")
				"cavern":
					strip.call(0.6, y0 + 0.2, 0.5, &"stone")
	if _trim_batch != null and not _trim_batch.is_empty():
		var mi2: MeshInstance3D = _trim_batch.instance("AutoTrim", 90.0)
		mi2.set_meta(&"walls", n_walls)
		art.add_child(mi2)
		_trim_batch = null


# Replaces a greybox body's box mesh with a prop (the collider stays the gameplay truth). The prop
# stands on the body's base; `offset` / `yaw` adjust it.
func skin(body_name: String, kind: StringName, offset: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> MeshInstance3D:
	var body: StaticBody3D = geometry.get_node_or_null(body_name) as StaticBody3D
	if body == null:
		return null
	var mi: MeshInstance3D = body.get_child(0) as MeshInstance3D
	var h: float = (mi.mesh as BoxMesh).size.y if mi != null and mi.mesh is BoxMesh else 0.0
	if mi != null:
		mi.visible = false
	return prop(kind, body.position - Vector3(0, h * 0.5, 0) + offset, yaw)


# Hides a greybox body's mesh (its collider stays) — for pieces the art pass rebuilds.
func hide_greybox(body_name: String) -> void:
	var body: Node = geometry.get_node_or_null(body_name)
	if body != null and body.get_child_count() > 0 and body.get_child(0) is MeshInstance3D:
		(body.get_child(0) as MeshInstance3D).visible = false


# Static batching (Step 13 performance pass): merges the zone's visible greybox boxes, procedural
# props and deco boxes into one mesh per material (shadow casters) plus one for small props (no
# shadows). The original nodes stay (colliders, names, metadata) with their meshes hidden. Moving
# or toggled pieces are left alone: NavDoors, gameplay nodes, spinners, lights' fixtures under
# animated parents, and anything flagged `no_batch`.
func batch_static() -> void:
	var casters: MeshBatch = MeshBatch.new()
	var small: MeshBatch = MeshBatch.new()
	var inv: Transform3D = global_transform.affine_inverse()
	var spinning: Array[Node] = []
	for s: Array in _spinners:
		spinning.append(s[0])
	var merged: int = 0
	for mi_node: Node in (
		geometry.find_children("*", "MeshInstance3D", true, false)
		+ art.find_children("*", "MeshInstance3D", true, false)
	):
		var mi: MeshInstance3D = mi_node as MeshInstance3D
		if not mi.visible or mi.mesh == null or not mi.is_visible_in_tree() or mi.has_meta(&"no_batch"):
			continue
		if _under_any(mi, spinning) or _is_dynamic(mi):
			continue
		var xf: Transform3D = inv * mi.global_transform
		var target: MeshBatch = (
			small if mi.visibility_range_end > 0.0 and mi.visibility_range_end <= VesperProps.SMALL_CULL else casters
		)
		if mi.mesh is BoxMesh:
			target.add(
				MeshBatch.Shape.BOX,
				(mi.mesh as BoxMesh).size,
				xf,
				mi.material_override if mi.material_override != null else MeshBatch._default_material()
			)
		elif mi.mesh is ArrayMesh:
			target.add_mesh(mi.mesh, xf, mi.material_override)
		else:
			continue
		mi.visible = false
		mi.set_meta(&"batched", true)
		merged += 1
	if not casters.is_empty():
		var c: MeshInstance3D = casters.instance("StaticBatch")
		c.set_meta(&"merged", merged)
		add_child(c)
	if not small.is_empty():
		var sm: MeshInstance3D = small.instance("StaticBatchSmall", 45.0)
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sm)


static func _under_any(n: Node, roots: Array[Node]) -> bool:
	for r: Node in roots:
		if r == n or r.is_ancestor_of(n):
			return true
	return false


# Doors, machines and lights' animated parents move or toggle: keep them as separate meshes.
static func _is_dynamic(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and not p is VesperZoneArt:
		if p is NavDoor or p is TraversalMachine or p is PoweredLight or p is Barricade:
			return true
		p = p.get_parent()
	return false
