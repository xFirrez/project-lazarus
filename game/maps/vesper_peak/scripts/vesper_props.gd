# VesperProps — Vesper Peak's procedural prop library (Step 13): furniture, clutter, fixtures and
# vignette pieces composed from primitives with the kit materials, merged per prop type into one
# ArrayMesh (MeshBatch: one draw call per material) and shared between every instance. Props are
# visual only — the greybox colliders stay the gameplay truth, so dressing never changes pathing
# (D-076). Light fixtures carry emissive parts that match the lights placed with them.
# Authority: static presentation.
class_name VesperProps
extends RefCounted

const CULL: float = 55.0
const SMALL_CULL: float = 28.0
const SMALL: Array[StringName] = [&"watch", &"notebook", &"glasses", &"cap", &"jar", &"shovel", &"book_pile"]

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


static func make(kind: StringName) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Prop_%s" % kind
	mi.mesh = mesh(kind)
	mi.visibility_range_end = SMALL_CULL if SMALL.has(kind) else CULL
	mi.set_meta(&"prop", kind)
	return mi


static func clear_cache() -> void:
	_meshes.clear()
	_mats.clear()


static func has_kind(kind: StringName) -> bool:
	return VesperProps.new().has_method("_p_%s" % kind)


static func mesh(kind: StringName) -> ArrayMesh:
	if not _meshes.has(kind):
		var b: MeshBatch = MeshBatch.new()
		var builder: VesperProps = VesperProps.new()
		var fn: String = "_p_%s" % kind
		if builder.has_method(fn):
			builder.call(fn, b)
		else:
			b.box(Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), m(&"crate"))
		_meshes[kind] = b.commit()
	return _meshes[kind]


# Material palette: the kit styles plus a few prop-only materials.
static func m(key: StringName) -> Material:
	if _mats.has(key):
		return _mats[key]
	var path: String = ""
	match key:
		&"wood":
			path = "res://content/materials/wood_dark.tres"
		&"metal":
			path = "res://content/materials/metal_dark.tres"
		&"olive":
			path = "res://content/materials/metal_olive.tres"
		&"brass":
			path = "res://content/materials/brass.tres"
		&"canvas":
			path = "res://content/materials/canvas_olive.tres"
		&"leather":
			path = "res://content/materials/leather_boot.tres"
		&"rubber":
			path = "res://content/materials/rubber.tres"
		&"tweed":
			path = "res://content/materials/tweed_brown.tres"
		&"stone":
			path = "res://content/materials/stone_grey.tres"
		&"plaster":
			path = "res://content/materials/plaster_rose.tres"
		&"ice":
			path = "res://content/materials/ice.tres"
		&"vesperite":
			path = "res://content/materials/vesperite.tres"
		&"glass":
			path = "res://content/materials/glass_frosted.tres"
		&"warm_lit":
			path = "res://content/materials/emissive_warm.tres"
		&"red_lit":
			path = "res://content/materials/emissive_red.tres"
		&"sandbag":
			path = "res://content/materials/sandbag.tres"
		&"coat":
			path = "res://content/materials/coat_blue.tres"
	var mat: Material = load(path) as Material if path != "" else null
	if mat == null:
		mat = _custom(key)
	_mats[key] = mat
	return mat


static func _custom(key: StringName) -> StandardMaterial3D:
	var s: StandardMaterial3D = StandardMaterial3D.new()
	s.roughness = 0.85
	var defs: Dictionary = {
		&"crate": Color(0.36, 0.3, 0.2),
		&"paper": Color(0.82, 0.78, 0.66),
		&"cloth_white": Color(0.78, 0.78, 0.74),
		&"mattress": Color(0.62, 0.6, 0.52),
		&"red_paint": Color(0.5, 0.08, 0.06),
		&"black": Color(0.04, 0.04, 0.045),
		&"rust": Color(0.33, 0.17, 0.09),
		&"enamel": Color(0.78, 0.8, 0.76),
		&"tile_white": Color(0.85, 0.88, 0.86),
		&"coal": Color(0.05, 0.05, 0.05),
		&"bone": Color(0.78, 0.74, 0.6),
		&"flesh": Color(0.55, 0.36, 0.33),
		&"fur": Color(0.42, 0.36, 0.3),
		&"book_red": Color(0.42, 0.1, 0.08),
		&"book_green": Color(0.12, 0.26, 0.16),
		&"book_blue": Color(0.12, 0.16, 0.32),
		&"gold": Color(0.7, 0.55, 0.2),
		&"canvas_paint": Color(0.3, 0.24, 0.18),
		&"hazard": Color(0.85, 0.66, 0.1),
		&"officer": Color(0.18, 0.2, 0.17),
	}
	if defs.has(key):
		s.albedo_color = defs[key]
	match key:
		&"cold_lit", &"green_lit", &"amber_lit", &"lens":
			var c: Color = {
				&"cold_lit": Color(0.85, 0.93, 1.0),
				&"green_lit": Color(0.35, 1.0, 0.5),
				&"amber_lit": Color(1.0, 0.6, 0.2),
				&"lens": Color(1.0, 0.97, 0.88),
			}[key]
			s.albedo_color = c
			s.emission_enabled = true
			s.emission = c
			s.emission_energy_multiplier = 4.0 if key != &"lens" else 8.0
		&"jar_liquid":
			s.albedo_color = Color(0.45, 0.6, 0.25, 0.55)
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.roughness = 0.1
		&"glass_clear":
			s.albedo_color = Color(0.75, 0.85, 0.9, 0.22)
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.roughness = 0.05
			s.metallic_specular = 0.9
		&"rust", &"metal_worn":
			s.metallic = 0.4
	return s


# --- furniture & clutter (origin = floor centre, +Z = front) -------------------------------------


func _p_suitcase(b: MeshBatch) -> void:
	b.box(Vector3(0.7, 0.45, 0.22), Vector3(0, 0.225, 0), m(&"leather"))
	b.box(Vector3(0.72, 0.03, 0.23), Vector3(0, 0.3, 0), m(&"brass"))
	b.box(Vector3(0.16, 0.05, 0.04), Vector3(0, 0.475, 0), m(&"black"))


func _p_trunk(b: MeshBatch) -> void:
	b.box(Vector3(0.95, 0.5, 0.55), Vector3(0, 0.25, 0), m(&"wood"))
	for x: float in [-0.3, 0.3]:
		b.box(Vector3(0.05, 0.52, 0.57), Vector3(x, 0.26, 0), m(&"brass"))
	b.box(Vector3(0.97, 0.06, 0.57), Vector3(0, 0.5, 0), m(&"metal"))


func _p_sled(b: MeshBatch) -> void:
	for x: float in [-0.18, 0.18]:
		b.box(Vector3(0.04, 0.05, 0.9), Vector3(x, 0.03, 0), m(&"metal"))
		b.box(Vector3(0.04, 0.05, 0.16), Vector3(x, 0.09, 0.5), m(&"metal"), Vector3(-0.8, 0, 0))
		for z: float in [-0.3, 0.0, 0.3]:
			b.box(Vector3(0.03, 0.14, 0.03), Vector3(x, 0.11, z), m(&"metal"))
	for z: float in [-0.32, -0.16, 0.0, 0.16, 0.32]:
		b.box(Vector3(0.48, 0.025, 0.12), Vector3(0, 0.19, z), m(&"red_paint"))


func _p_watch(b: MeshBatch) -> void:
	b.cyl(0.022, 0.008, Vector3(0, 0.004, 0), m(&"brass"))
	b.cyl(0.018, 0.002, Vector3(0, 0.009, 0), m(&"paper"))
	b.box(Vector3(0.016, 0.004, 0.13), Vector3(0, 0.002, 0), m(&"leather"))


func _p_bench(b: MeshBatch) -> void:
	b.box(Vector3(2.2, 0.06, 0.45), Vector3(0, 0.45, 0), m(&"wood"))
	b.box(Vector3(2.2, 0.4, 0.05), Vector3(0, 0.75, -0.22), m(&"wood"), Vector3(-0.15, 0, 0))
	for x: float in [-0.95, 0.0, 0.95]:
		b.box(Vector3(0.06, 0.45, 0.45), Vector3(x, 0.225, 0), m(&"metal"))


func _p_desk(b: MeshBatch) -> void:
	b.box(Vector3(1.5, 0.06, 0.75), Vector3(0, 0.76, 0), m(&"wood"))
	for x: float in [-0.55, 0.55]:
		b.box(Vector3(0.38, 0.72, 0.7), Vector3(x, 0.36, 0), m(&"wood"))
	b.box(Vector3(0.36, 0.1, 0.02), Vector3(-0.55, 0.62, 0.36), m(&"brass"))


func _p_chair(b: MeshBatch) -> void:
	b.box(Vector3(0.45, 0.05, 0.45), Vector3(0, 0.46, 0), m(&"wood"))
	b.box(Vector3(0.45, 0.5, 0.04), Vector3(0, 0.74, -0.21), m(&"wood"))
	for x: float in [-0.19, 0.19]:
		for z: float in [-0.19, 0.19]:
			b.box(Vector3(0.04, 0.46, 0.04), Vector3(x, 0.23, z), m(&"wood"))


func _p_armchair(b: MeshBatch) -> void:
	b.box(Vector3(0.85, 0.42, 0.8), Vector3(0, 0.21, 0), m(&"tweed"))
	b.box(Vector3(0.85, 0.6, 0.18), Vector3(0, 0.7, -0.32), m(&"tweed"))
	for x: float in [-0.36, 0.36]:
		b.box(Vector3(0.14, 0.28, 0.75), Vector3(x, 0.55, 0.02), m(&"tweed"))


func _p_bed(b: MeshBatch) -> void:
	b.box(Vector3(0.95, 0.16, 1.95), Vector3(0, 0.55, 0), m(&"mattress"))
	b.box(Vector3(0.6, 0.1, 0.35), Vector3(0, 0.68, -0.75), m(&"cloth_white"))
	for z: float in [-1.0, 1.0]:
		b.box(Vector3(1.0, 0.04, 0.04), Vector3(0, 0.45, z), m(&"enamel"))
		b.box(Vector3(1.0, 0.04, 0.04), Vector3(0, 1.0 if z < 0 else 0.8, z), m(&"enamel"))
		for x: float in [-0.48, 0.48]:
			b.box(
				Vector3(0.04, 1.0 if z < 0 else 0.8, 0.04), Vector3(x, (1.0 if z < 0 else 0.8) * 0.5, z), m(&"enamel")
			)
	for x: float in [-0.48, 0.48]:
		b.box(Vector3(0.03, 0.03, 2.0), Vector3(x, 0.45, 0), m(&"enamel"))
		# restraint straps
		b.box(Vector3(0.05, 0.2, 0.08), Vector3(x, 0.55, 0.2), m(&"leather"))


func _p_wheelchair(b: MeshBatch) -> void:
	b.box(Vector3(0.48, 0.05, 0.45), Vector3(0, 0.5, 0), m(&"canvas"))
	b.box(Vector3(0.48, 0.45, 0.04), Vector3(0, 0.78, -0.22), m(&"canvas"), Vector3(-0.12, 0, 0))
	for x: float in [-0.29, 0.29]:
		b.cyl(0.3, 0.03, Vector3(x, 0.3, -0.05), m(&"metal"), Vector3(0, 0, PI / 2.0))
		b.cyl(0.08, 0.03, Vector3(x * 0.8, 0.08, 0.3), m(&"rubber"), Vector3(0, 0, PI / 2.0))
		b.box(Vector3(0.025, 0.6, 0.025), Vector3(x * 0.85, 0.75, -0.25), m(&"metal"))


func _p_cabinet(b: MeshBatch) -> void:
	b.box(Vector3(0.9, 1.9, 0.45), Vector3(0, 0.95, 0), m(&"enamel"))
	b.box(Vector3(0.02, 1.7, 0.02), Vector3(0, 0.95, 0.23), m(&"metal"))
	for x: float in [-0.08, 0.08]:
		b.box(Vector3(0.03, 0.12, 0.03), Vector3(x, 1.0, 0.24), m(&"metal"))


func _p_filing_cabinet(b: MeshBatch) -> void:
	b.box(Vector3(0.5, 1.3, 0.62), Vector3(0, 0.65, 0), m(&"olive"))
	for i: int in 4:
		b.box(Vector3(0.42, 0.26, 0.02), Vector3(0, 0.18 + i * 0.31, 0.31), m(&"olive"))
		b.box(Vector3(0.12, 0.03, 0.03), Vector3(0, 0.25 + i * 0.31, 0.33), m(&"metal"))


func _p_shelf(b: MeshBatch) -> void:
	for x: float in [-0.78, 0.78]:
		b.box(Vector3(0.04, 2.0, 0.45), Vector3(x, 1.0, 0), m(&"metal"))
	for i: int in 4:
		b.box(Vector3(1.6, 0.03, 0.45), Vector3(0, 0.15 + i * 0.6, 0), m(&"metal"))


func _p_jar(b: MeshBatch) -> void:
	b.cyl(0.11, 0.3, Vector3(0, 0.15, 0), m(&"glass_clear"))
	b.cyl(0.1, 0.24, Vector3(0, 0.13, 0), m(&"jar_liquid"))
	b.sphere(0.06, Vector3(0, 0.13, 0), m(&"flesh"), Vector3(1.0, 0.7, 1.0))
	b.cyl(0.115, 0.03, Vector3(0, 0.31, 0), m(&"metal"))


func _p_jar_shelf(b: MeshBatch) -> void:
	_p_shelf(b)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12
	for i: int in 4:
		for j: int in 5:
			if rng.randf() < 0.2:
				continue
			var p: Vector3 = Vector3(
				-0.6 + j * 0.3 + rng.randf_range(-0.04, 0.04), 0.17 + i * 0.6, rng.randf_range(-0.08, 0.08)
			)
			var h: float = rng.randf_range(0.18, 0.38)
			b.cyl(0.09, h, p + Vector3(0, h * 0.5, 0), m(&"glass_clear"))
			b.cyl(0.08, h * 0.8, p + Vector3(0, h * 0.42, 0), m(&"jar_liquid"))
			if rng.randf() < 0.6:
				b.sphere(0.05, p + Vector3(0, h * 0.4, 0), m(&"flesh" if rng.randf() < 0.7 else &"bone"))


# The two-headed goat (Z12): a large specimen jar.
func _p_goat_jar(b: MeshBatch) -> void:
	b.cyl(0.4, 1.3, Vector3(0, 0.75, 0), m(&"glass_clear"))
	b.cyl(0.38, 1.1, Vector3(0, 0.68, 0), m(&"jar_liquid"))
	b.cyl(0.42, 0.12, Vector3(0, 0.06, 0), m(&"brass"))
	b.cyl(0.42, 0.1, Vector3(0, 1.43, 0), m(&"brass"))
	b.sphere(0.25, Vector3(0, 0.55, 0), m(&"fur"), Vector3(1.0, 0.8, 1.4))
	for x: float in [-0.1, 0.1]:
		b.sphere(0.11, Vector3(x, 0.85, 0.22), m(&"fur"))
		b.add(
			MeshBatch.Shape.CONE,
			Vector3(0.04, 0.12, 0.04),
			Transform3D(Basis.from_euler(Vector3(0, 0, x * 4.0)), Vector3(x * 1.4, 0.98, 0.2)),
			m(&"bone")
		)


func _p_coffin(b: MeshBatch) -> void:
	b.box(Vector3(0.62, 0.42, 1.95), Vector3(0, 0.21, 0), m(&"wood"))
	b.box(Vector3(0.66, 0.06, 2.0), Vector3(0, 0.45, 0), m(&"wood"))


# Broken open from inside: the lid split upward, the planks splintered outward.
func _p_coffin_open(b: MeshBatch) -> void:
	b.box(Vector3(0.62, 0.42, 1.95), Vector3(0, 0.21, 0), m(&"wood"))
	b.box(Vector3(0.5, 0.05, 1.8), Vector3(0, 0.38, 0), m(&"black"))
	b.box(Vector3(0.66, 0.05, 0.9), Vector3(0.12, 0.62, -0.5), m(&"wood"), Vector3(0.5, 0.2, 0.4))
	b.box(Vector3(0.3, 0.05, 0.8), Vector3(-0.42, 0.5, 0.5), m(&"wood"), Vector3(0.2, 0.0, -0.9))


func _p_tarp_stack(b: MeshBatch) -> void:
	for i: int in 3:
		for j: int in 2:
			b.box(Vector3(0.64, 0.44, 1.97), Vector3(-0.35 + j * 0.7, 0.22 + i * 0.45, 0), m(&"wood"))
	b.box(Vector3(1.6, 0.05, 2.2), Vector3(0, 1.37, 0), m(&"canvas"))
	b.box(Vector3(0.05, 1.0, 2.2), Vector3(0.8, 0.9, 0), m(&"canvas"), Vector3(0, 0, 0.12))


func _p_radio_console(b: MeshBatch) -> void:
	b.box(Vector3(1.6, 0.8, 0.7), Vector3(0, 0.4, 0), m(&"olive"))
	b.box(Vector3(1.6, 0.7, 0.35), Vector3(0, 1.15, -0.17), m(&"olive"))
	for i: int in 5:
		b.cyl(0.05, 0.04, Vector3(-0.6 + i * 0.3, 1.1, 0.02), m(&"black"), Vector3(PI / 2.0, 0, 0))
	b.box(Vector3(0.5, 0.15, 0.02), Vector3(0, 1.35, 0.01), m(&"amber_lit"))


func _p_frozen_operator(b: MeshBatch) -> void:
	_p_chair(b)
	var ice: Material = m(&"coat")
	b.box(Vector3(0.42, 0.6, 0.26), Vector3(0, 0.82, -0.06), ice, Vector3(0.12, 0, 0))
	b.sphere(0.12, Vector3(0, 1.25, 0.0), m(&"flesh"))
	b.box(Vector3(0.36, 0.04, 0.06), Vector3(0, 1.38, 0.0), m(&"black"))
	for x: float in [-0.14, 0.14]:
		b.cyl(0.05, 0.04, Vector3(x, 1.26, 0.0), m(&"black"), Vector3(0, 0, PI / 2.0))
		b.add(
			MeshBatch.Shape.CAPSULE,
			Vector3(0.36, 0.5, 0.36),
			Transform3D(Basis.from_euler(Vector3(-1.2, 0, 0)), Vector3(x * 1.4, 0.95, 0.18)),
			ice
		)
		b.add(
			MeshBatch.Shape.CAPSULE,
			Vector3(0.44, 0.5, 0.44),
			Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0, 0)), Vector3(x * 0.8, 0.5, 0.2)),
			ice
		)
	# frost crust
	b.sphere(0.2, Vector3(0, 1.08, -0.02), m(&"ice"), Vector3(1.4, 0.5, 1.1))


func _p_notebook(b: MeshBatch) -> void:
	b.box(Vector3(0.16, 0.02, 0.22), Vector3(0, 0.01, 0), m(&"leather"))
	b.box(Vector3(0.15, 0.005, 0.21), Vector3(0.02, 0.023, 0), m(&"paper"), Vector3(0, 0.2, 0))


func _p_glasses(b: MeshBatch) -> void:
	for x: float in [-0.035, 0.035]:
		b.cyl(0.025, 0.004, Vector3(x, 0.01, 0), m(&"glass"), Vector3(PI / 2.0 - 0.3, 0, 0))
	b.box(Vector3(0.12, 0.004, 0.004), Vector3(0, 0.02, -0.005), m(&"metal"))


func _p_cap(b: MeshBatch) -> void:
	b.cyl(0.11, 0.07, Vector3(0, 0.035, 0), m(&"officer"))
	b.cyl(0.13, 0.03, Vector3(0, 0.085, 0.01), m(&"officer"), Vector3(0.15, 0, 0))
	b.box(Vector3(0.18, 0.01, 0.07), Vector3(0, 0.015, 0.12), m(&"black"))
	b.box(Vector3(0.05, 0.03, 0.01), Vector3(0, 0.07, 0.11), m(&"gold"))


func _p_chain(b: MeshBatch) -> void:
	for i: int in 9:
		var rot: Vector3 = Vector3(0, PI / 2.0 if i % 2 == 0 else 0.0, 0)
		b.box(Vector3(0.05, 0.02, 0.09), Vector3(0, 0.0, -0.36 + i * 0.09), m(&"metal"), rot)
	b.box(Vector3(0.12, 0.14, 0.06), Vector3(0, -0.06, 0.4), m(&"brass"))


func _p_boiler(b: MeshBatch) -> void:
	b.cyl(1.3, 5.0, Vector3(0, 1.6, 0), m(&"rust"), Vector3(PI / 2.0, 0, 0))
	for z: float in [-2.0, -0.7, 0.7, 2.0]:
		b.cyl(1.36, 0.12, Vector3(0, 1.6, z), m(&"metal"), Vector3(PI / 2.0, 0, 0))
	b.cyl(0.35, 3.5, Vector3(0, 4.2, -1.6), m(&"metal"))
	b.box(Vector3(0.8, 0.7, 0.1), Vector3(0, 1.2, 2.55), m(&"metal"))
	b.box(Vector3(0.6, 0.35, 0.05), Vector3(0, 1.2, 2.61), m(&"amber_lit"))
	for x: float in [-1.0, 1.0]:
		b.box(Vector3(0.4, 0.4, 4.4), Vector3(x * 0.9, 0.2, 0), m(&"stone"))


func _p_generator(b: MeshBatch) -> void:
	b.box(Vector3(2.6, 0.5, 6.0), Vector3(0, 0.25, 0), m(&"metal"))
	b.cyl(1.2, 3.2, Vector3(0, 1.7, -0.8), m(&"olive"), Vector3(PI / 2.0, 0, 0))
	b.box(Vector3(2.0, 1.6, 2.0), Vector3(0, 1.3, 1.9), m(&"olive"))
	for z: float in [-2.0, -1.2, -0.4, 0.4]:
		b.cyl(1.25, 0.08, Vector3(0, 1.7, z), m(&"metal"), Vector3(PI / 2.0, 0, 0))
	b.cyl(0.2, 2.5, Vector3(0.8, 3.0, 1.9), m(&"metal"))
	b.box(Vector3(0.5, 0.3, 0.02), Vector3(0, 1.6, 2.91), m(&"amber_lit"))


func _p_autopsy_table(b: MeshBatch) -> void:
	b.cyl(0.15, 0.85, Vector3(0, 0.42, 0), m(&"metal"))
	b.box(Vector3(0.8, 0.06, 2.0), Vector3(0, 0.88, 0), m(&"enamel"))
	b.box(Vector3(0.84, 0.08, 0.04), Vector3(0, 0.92, 1.0), m(&"enamel"))
	b.box(Vector3(0.6, 0.02, 1.2), Vector3(0, 0.915, -0.2), m(&"cloth_white"))


func _p_gurney(b: MeshBatch) -> void:
	b.box(Vector3(0.65, 0.05, 1.9), Vector3(0, 0.8, 0), m(&"metal"))
	b.box(Vector3(0.6, 0.12, 1.85), Vector3(0, 0.88, 0), m(&"cloth_white"))
	for x: float in [-0.28, 0.28]:
		for z: float in [-0.85, 0.85]:
			b.box(Vector3(0.03, 0.75, 0.03), Vector3(x, 0.42, z), m(&"metal"))
			b.cyl(0.05, 0.03, Vector3(x, 0.05, z), m(&"rubber"), Vector3(0, 0, PI / 2.0))


func _p_drawer_wall(b: MeshBatch) -> void:
	# 6 x 4 body drawers (the Morgue's 24), front at +Z.
	b.box(Vector3(4.8, 3.0, 0.5), Vector3(0, 1.5, -0.25), m(&"metal"))
	for i: int in 6:
		for j: int in 4:
			var c: Vector3 = Vector3(-2.0 + i * 0.8, 0.45 + j * 0.72, 0.02)
			b.box(Vector3(0.72, 0.62, 0.04), c, m(&"enamel"))
			b.box(Vector3(0.18, 0.04, 0.05), c + Vector3(0, 0.15, 0.03), m(&"metal"))


func _p_gas_tank(b: MeshBatch) -> void:
	b.cyl(0.12, 1.3, Vector3(0, 0.65, 0), m(&"olive"))
	b.sphere(0.12, Vector3(0, 1.3, 0), m(&"olive"))
	b.cyl(0.03, 0.15, Vector3(0, 1.45, 0), m(&"brass"))


func _p_lab_bench(b: MeshBatch) -> void:
	b.box(Vector3(2.4, 0.9, 0.8), Vector3(0, 0.45, 0), m(&"enamel"))
	b.box(Vector3(2.5, 0.05, 0.85), Vector3(0, 0.92, 0), m(&"black"))
	for i: int in 4:
		b.cyl(0.05, 0.18, Vector3(-0.8 + i * 0.45, 1.03, 0.1), m(&"glass_clear"))
	b.box(Vector3(0.5, 0.4, 0.4), Vector3(0.8, 1.15, -0.1), m(&"olive"))
	b.box(Vector3(0.36, 0.22, 0.02), Vector3(0.8, 1.18, 0.11), m(&"green_lit"))


func _p_console(b: MeshBatch) -> void:
	b.box(Vector3(1.8, 1.0, 0.7), Vector3(0, 0.5, 0), m(&"olive"))
	b.box(Vector3(1.8, 0.05, 0.6), Vector3(0, 1.05, 0.05), m(&"metal"), Vector3(0.35, 0, 0))
	for i: int in 6:
		b.box(
			Vector3(0.12, 0.06, 0.04),
			Vector3(-0.7 + i * 0.28, 1.1, 0.12),
			m(&"red_lit" if i % 3 == 0 else &"amber_lit")
		)
	b.box(Vector3(0.6, 0.35, 0.02), Vector3(0, 1.4, -0.25), m(&"green_lit"))


func _p_cable_bundle(b: MeshBatch) -> void:
	for i: int in 5:
		var o: Vector3 = Vector3(cos(i * 1.3) * 0.25, 0, sin(i * 1.3) * 0.25)
		b.cyl(0.12, 6.0, o + Vector3(0, 3.0, 0), m(&"rubber"))
	for y: float in [0.5, 3.0, 5.5]:
		b.cyl(0.42, 0.12, Vector3(0, y, 0), m(&"brass"))


func _p_icicles(b: MeshBatch) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	for i: int in 9:
		var h: float = rng.randf_range(0.3, 1.1)
		b.add(
			MeshBatch.Shape.CONE,
			Vector3(0.12, h, 0.12),
			Transform3D(
				Basis.from_euler(Vector3(PI, 0, 0)), Vector3(-0.9 + i * 0.22, -h * 0.5, rng.randf_range(-0.05, 0.05))
			),
			m(&"ice")
		)


func _p_coal_pile(b: MeshBatch) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	b.sphere(1.2, Vector3(0, 0.0, 0), m(&"coal"), Vector3(1.4, 0.6, 1.2))
	for i: int in 10:
		b.sphere(0.12, Vector3(rng.randf_range(-1.4, 1.4), 0.08, rng.randf_range(-1.2, 1.2)), m(&"coal"))


func _p_shovel(b: MeshBatch) -> void:
	b.cyl(0.02, 1.2, Vector3(0, 0.6, 0), m(&"wood"))
	b.box(Vector3(0.26, 0.32, 0.03), Vector3(0, 0.08, 0.02), m(&"rust"), Vector3(0.2, 0, 0))


func _p_book_pile(b: MeshBatch) -> void:
	var cols: Array[StringName] = [&"book_red", &"book_green", &"book_blue", &"leather"]
	for i: int in 5:
		b.box(
			Vector3(0.24, 0.05, 0.32), Vector3(0.01 * i, 0.025 + i * 0.05, 0), m(cols[i % 4]), Vector3(0, 0.25 * i, 0)
		)


func _p_bookcase(b: MeshBatch) -> void:
	b.box(Vector3(1.8, 2.6, 0.4), Vector3(0, 1.3, -0.02), m(&"wood"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21
	var cols: Array[StringName] = [&"book_red", &"book_green", &"book_blue", &"leather"]
	for row: int in 5:
		var x: float = -0.82
		while x < 0.78:
			var w: float = rng.randf_range(0.04, 0.09)
			var h: float = rng.randf_range(0.26, 0.38)
			b.box(Vector3(w, h, 0.26), Vector3(x + w * 0.5, 0.2 + row * 0.5 + h * 0.5, 0.06), m(cols[rng.randi() % 4]))
			x += w + 0.005
		b.box(Vector3(1.72, 0.03, 0.34), Vector3(0, 0.18 + row * 0.5, 0.04), m(&"wood"))


func _p_clock(b: MeshBatch) -> void:
	# Grandfather clock, stopped at 23:51.
	b.box(Vector3(0.55, 2.1, 0.35), Vector3(0, 1.05, 0), m(&"wood"))
	b.box(Vector3(0.6, 0.6, 0.38), Vector3(0, 2.2, 0), m(&"wood"))
	b.cyl(0.22, 0.02, Vector3(0, 2.2, 0.19), m(&"paper"), Vector3(PI / 2.0, 0, 0))
	b.box(Vector3(0.015, 0.17, 0.01), Vector3(-0.01, 2.27, 0.205), m(&"black"), Vector3(0, 0, 0.05))
	b.box(Vector3(0.012, 0.2, 0.01), Vector3(-0.05, 2.25, 0.21), m(&"black"), Vector3(0, 0, 0.53))
	b.cyl(0.08, 0.02, Vector3(0, 1.1, 0.16), m(&"brass"), Vector3(PI / 2.0, 0, 0))


func _p_mirror(b: MeshBatch) -> void:
	b.box(Vector3(0.8, 1.3, 0.05), Vector3(0, 1.4, 0), m(&"gold"))
	b.box(Vector3(0.68, 1.18, 0.02), Vector3(0, 1.4, 0.03), m(&"glass_clear"))


func _p_portrait(b: MeshBatch) -> void:
	b.box(Vector3(1.0, 1.3, 0.06), Vector3(0, 0, 0), m(&"gold"))
	b.box(Vector3(0.86, 1.16, 0.02), Vector3(0, 0, 0.03), m(&"canvas_paint"))
	b.sphere(0.16, Vector3(0, 0.25, 0.04), m(&"flesh"), Vector3(0.8, 1.0, 0.1))
	b.box(Vector3(0.5, 0.5, 0.01), Vector3(0, -0.2, 0.04), m(&"black"))


# The founder's portrait, slashed: canvas torn in three flaps.
func _p_portrait_slashed(b: MeshBatch) -> void:
	b.box(Vector3(1.0, 1.3, 0.06), Vector3(0, 0, 0), m(&"gold"))
	b.box(Vector3(0.86, 1.16, 0.01), Vector3(0, 0, 0.0), m(&"black"))
	b.box(Vector3(0.3, 1.1, 0.01), Vector3(-0.28, 0.02, 0.05), m(&"canvas_paint"), Vector3(0, 0.3, 0.06))
	b.box(Vector3(0.28, 0.9, 0.01), Vector3(0.05, -0.1, 0.07), m(&"canvas_paint"), Vector3(0.4, -0.2, -0.1))
	b.box(Vector3(0.28, 1.1, 0.01), Vector3(0.3, 0.0, 0.04), m(&"canvas_paint"), Vector3(0, -0.35, 0.05))
	b.sphere(0.12, Vector3(0.3, 0.3, 0.06), m(&"flesh"), Vector3(0.8, 1.0, 0.1))


func _p_crest(b: MeshBatch) -> void:
	b.box(Vector3(1.4, 1.6, 0.1), Vector3(0, 0, 0), m(&"brass"))
	b.box(Vector3(1.1, 1.3, 0.06), Vector3(0, 0.0, 0.05), m(&"book_green"))
	b.add(
		MeshBatch.Shape.CONE, Vector3(0.5, 0.6, 0.06), Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0.09)), m(&"gold")
	)


func _p_reception_switchboard(b: MeshBatch) -> void:
	b.box(Vector3(1.4, 1.6, 0.5), Vector3(0, 0.8, 0), m(&"wood"))
	for i: int in 6:
		for j: int in 4:
			b.cyl(0.02, 0.03, Vector3(-0.5 + i * 0.2, 0.9 + j * 0.15, 0.26), m(&"brass"), Vector3(PI / 2.0, 0, 0))
	b.box(Vector3(1.2, 0.3, 0.1), Vector3(0, 1.75, 0.15), m(&"black"))


func _p_chandelier_fallen(b: MeshBatch) -> void:
	b.cyl(1.0, 0.12, Vector3(0, 0.25, 0), m(&"brass"), Vector3(0.3, 0, 0.15))
	for i: int in 10:
		var a: float = TAU * i / 10.0
		b.box(
			Vector3(0.05, 0.4, 0.05),
			Vector3(cos(a) * 0.95, 0.4 + sin(a) * 0.25, sin(a) * 0.95),
			m(&"glass_clear"),
			Vector3(0.3, a, 0.15)
		)
	b.cyl(0.08, 1.6, Vector3(0.2, 0.9, 0.1), m(&"brass"), Vector3(0.0, 0, 0.9))


func _p_banner(b: MeshBatch) -> void:
	# Group Vesper banner (hung over the crest): olive cloth, white band and roundel.
	b.box(Vector3(2.2, 0.08, 0.08), Vector3(0, 0, 0), m(&"metal"))
	b.box(Vector3(2.0, 3.0, 0.02), Vector3(0, -1.55, 0.02), m(&"canvas"))
	b.box(Vector3(2.0, 0.25, 0.025), Vector3(0, -0.6, 0.03), m(&"cloth_white"))
	b.cyl(0.45, 0.03, Vector3(0, -1.7, 0.04), m(&"cloth_white"), Vector3(PI / 2.0, 0, 0))
	b.cyl(0.32, 0.035, Vector3(0, -1.7, 0.045), m(&"canvas"), Vector3(PI / 2.0, 0, 0))


func _p_crate_stack(b: MeshBatch) -> void:
	b.box(Vector3(1.0, 1.0, 1.0), Vector3(0, 0.5, 0), m(&"crate"))
	b.box(Vector3(1.0, 1.0, 1.0), Vector3(1.05, 0.5, 0.1), m(&"crate"), Vector3(0, 0.2, 0))
	b.box(Vector3(0.9, 0.8, 0.9), Vector3(0.4, 1.4, 0.0), m(&"crate"), Vector3(0, -0.3, 0))
	for c: Vector3 in [Vector3(0, 0.5, 0.51), Vector3(1.05, 0.5, 0.61)]:
		b.box(Vector3(0.6, 0.12, 0.01), c, m(&"cloth_white"))


func _p_toolrack(b: MeshBatch) -> void:
	b.box(Vector3(1.6, 1.0, 0.04), Vector3(0, 1.5, 0), m(&"wood"))
	for i: int in 5:
		b.box(Vector3(0.04, 0.6 + 0.1 * (i % 2), 0.04), Vector3(-0.6 + i * 0.3, 1.45, 0.05), m(&"rust"))


func _p_valve(b: MeshBatch) -> void:
	b.cyl(0.08, 0.4, Vector3(0, 0, 0.2), m(&"metal"), Vector3(PI / 2.0, 0, 0))
	b.cyl(0.28, 0.04, Vector3(0, 0, 0.42), m(&"red_paint"), Vector3(PI / 2.0, 0, 0))


func _p_containment_tank(b: MeshBatch) -> void:
	b.cyl(1.0, 0.3, Vector3(0, 0.15, 0), m(&"metal"))
	b.cyl(1.0, 0.3, Vector3(0, 3.0, 0), m(&"metal"))
	b.cyl(0.92, 2.6, Vector3(0, 1.6, 0), m(&"glass_clear"))
	for i: int in 4:
		var a: float = TAU * i / 4.0 + 0.4
		b.box(Vector3(0.08, 2.6, 0.08), Vector3(cos(a) * 0.95, 1.6, sin(a) * 0.95), m(&"metal"))


func _p_drum_rack(b: MeshBatch) -> void:
	for i: int in 3:
		b.cyl(0.3, 0.9, Vector3(-0.65 + i * 0.65, 0.45, 0), m(&"red_paint" if i == 1 else &"olive"))
		b.cyl(0.31, 0.04, Vector3(-0.65 + i * 0.65, 0.7, 0), m(&"metal"))


func _p_sandbags(b: MeshBatch) -> void:
	for row: int in 3:
		for i: int in 4:
			b.sphere(
				0.3,
				Vector3(-0.9 + i * 0.6 + (0.3 if row % 2 == 1 else 0.0), 0.14 + row * 0.24, 0),
				m(&"sandbag"),
				Vector3(1.0, 0.45, 0.7)
			)


func _p_jeep_overturned(b: MeshBatch) -> void:
	b.box(Vector3(1.6, 0.9, 3.4), Vector3(0, 0.75, 0), m(&"olive"), Vector3(0, 0, PI * 0.92))
	for x: float in [-0.8, 0.8]:
		for z: float in [-1.2, 1.2]:
			b.cyl(0.38, 0.25, Vector3(x, 1.45, z), m(&"rubber"), Vector3(0, 0, PI / 2.0))
	b.box(Vector3(1.4, 0.05, 0.6), Vector3(0, 0.2, 1.35), m(&"glass"), Vector3(0.6, 0, PI * 0.92))


# --- fixtures (pair them with a light at the bulb) --------------------------------------------------


func _p_sconce(b: MeshBatch) -> void:
	b.box(Vector3(0.12, 0.2, 0.04), Vector3(0, 0, 0.02), m(&"brass"))
	b.box(Vector3(0.03, 0.03, 0.18), Vector3(0, 0.02, 0.1), m(&"brass"))
	b.sphere(0.07, Vector3(0, 0.08, 0.2), m(&"warm_lit"))
	b.add(
		MeshBatch.Shape.CONE,
		Vector3(0.2, 0.14, 0.2),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.14, 0.2)),
		m(&"cloth_white")
	)


func _p_caged_bulb(b: MeshBatch) -> void:
	b.cyl(0.06, 0.06, Vector3(0, -0.03, 0), m(&"olive"))
	b.sphere(0.06, Vector3(0, -0.12, 0), m(&"amber_lit"))
	for i: int in 4:
		var a: float = TAU * i / 4.0
		b.box(Vector3(0.01, 0.16, 0.01), Vector3(cos(a) * 0.08, -0.12, sin(a) * 0.08), m(&"metal"))


func _p_fluoro(b: MeshBatch) -> void:
	b.box(Vector3(0.25, 0.06, 1.3), Vector3(0, 0, 0), m(&"enamel"))
	for x: float in [-0.06, 0.06]:
		b.cyl(0.02, 1.2, Vector3(x, -0.04, 0), m(&"cold_lit"), Vector3(PI / 2.0, 0, 0))
	for z: float in [-0.5, 0.5]:
		b.box(Vector3(0.01, 0.5, 0.01), Vector3(0, 0.27, z), m(&"metal"))


func _p_pendant(b: MeshBatch) -> void:
	b.cyl(0.008, 1.2, Vector3(0, 0.6, 0), m(&"black"))
	b.add(
		MeshBatch.Shape.CONE, Vector3(0.45, 0.25, 0.45), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), m(&"enamel")
	)
	b.sphere(0.06, Vector3(0, -0.05, 0), m(&"warm_lit"))


func _p_surgical_lamp(b: MeshBatch) -> void:
	b.cyl(0.05, 2.0, Vector3(0, 1.0, 0), m(&"metal"))
	b.cyl(0.9, 0.25, Vector3(0, -0.1, 0), m(&"enamel"))
	for i: int in 7:
		var a: float = TAU * i / 7.0
		b.cyl(0.14, 0.03, Vector3(cos(a) * 0.5 if i > 0 else 0.0, -0.24, sin(a) * 0.5 if i > 0 else 0.0), m(&"lens"))


func _p_searchlight(b: MeshBatch) -> void:
	b.cyl(0.35, 0.7, Vector3(0, 0, 0), m(&"olive"), Vector3(PI / 2.0, 0, 0))
	b.cyl(0.3, 0.03, Vector3(0, 0, -0.36), m(&"lens"), Vector3(PI / 2.0, 0, 0))
	b.box(Vector3(0.08, 0.5, 0.08), Vector3(0, -0.45, 0), m(&"metal"))


func _p_beacon(b: MeshBatch) -> void:
	b.cyl(0.07, 0.06, Vector3(0, 0.03, 0), m(&"metal"))
	b.sphere(0.08, Vector3(0, 0.1, 0), m(&"red_lit"))
