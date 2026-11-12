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

static var _mats: Dictionary = {}
static var _decal_tex: Dictionary = {}

@export var zone_id: StringName = &""
@export var display_name: String = ""
@export var cascade: int = 0  # power-on order (lights wake after cascade × CASCADE_STEP s)
## Automatic trim pass: "sanatorium" (wainscot + baseboard + crown), "military" (baseboard +
## cable tray), "industrial" (pipes + soot band), "lab" (tile band + baseboard), "exterior" (snow
## drifts at wall feet), "cavern" (rock rubble at wall feet), "" = none.
@export var trim: String = ""

var geometry: Node3D = null
var gameplay: Node3D = null
var lighting: Node3D = null
var audio: Node3D = null
var art: Node3D = null
var vignettes: Array[Node3D] = []
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
