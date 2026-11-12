# MeshBatch — merges many primitive parts (box / cylinder / cone / sphere / capsule / prism) into
# one ArrayMesh with one surface per material, so procedurally dressed props and trims cost one
# draw call per material instead of one per part (Step 13 performance budget). Parts are given in
# the batch's local space. Build once and share the mesh between instances where possible.
# Authority: static presentation data.
class_name MeshBatch
extends RefCounted

enum Shape { BOX, CYLINDER, CONE, SPHERE, CAPSULE, PRISM }

static var _prims: Dictionary = {}

var parts: int = 0

var _tools: Dictionary = {}  # Material -> SurfaceTool
var _order: Array[Material] = []


# Drops the shared unit primitives (call when the last user leaves; avoids exit-time leak reports).
static func clear_cache() -> void:
	_prims.clear()


func add(shape: Shape, size: Vector3, xf: Transform3D, material: Material) -> void:
	var st: SurfaceTool = _tools.get(material, null)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = st
		_order.append(material)
	var unit: Mesh = _unit(shape)
	# Unit primitives are 1 m; the size is folded into the transform (axis-aligned scaling keeps
	# box / cylinder normals pointing the right way).
	st.append_from(unit, 0, xf * Transform3D(Basis.from_scale(size), Vector3.ZERO))
	parts += 1


# Appends every surface of an existing mesh (e.g. a cached prop mesh) under transform `xf`;
# `override` replaces the surface materials when set.
func add_mesh(mesh: Mesh, xf: Transform3D, override: Material = null) -> void:
	for i: int in mesh.get_surface_count():
		var mat: Material = override if override != null else mesh.surface_get_material(i)
		if mat == null:
			mat = _default_material()
		var st: SurfaceTool = _tools.get(mat, null)
		if st == null:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_tools[mat] = st
			_order.append(mat)
		st.append_from(mesh, i, xf)
	parts += 1


static func _default_material() -> Material:
	if not _prims.has(&"default_mat"):
		_prims[&"default_mat"] = StandardMaterial3D.new()
	return _prims[&"default_mat"]


func box(size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> void:
	add(Shape.BOX, size, Transform3D(Basis.from_euler(rot), pos), material)


func cyl(radius: float, height: float, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> void:
	add(Shape.CYLINDER, Vector3(radius * 2.0, height, radius * 2.0), Transform3D(Basis.from_euler(rot), pos), material)


func sphere(radius: float, pos: Vector3, material: Material, squash: Vector3 = Vector3.ONE) -> void:
	add(Shape.SPHERE, squash * radius * 2.0, Transform3D(Basis.IDENTITY, pos), material)


func is_empty() -> bool:
	return parts == 0


func commit() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for m: Material in _order:
		var st: SurfaceTool = _tools[m]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return mesh


func instance(node_name: String = "Batch", cull: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = commit()
	if cull > 0.0:
		mi.visibility_range_end = cull
	return mi


static func _unit(shape: Shape) -> Mesh:
	if _prims.has(shape):
		return _prims[shape]
	var m: PrimitiveMesh = null
	match shape:
		Shape.BOX:
			m = BoxMesh.new()
		Shape.CYLINDER:
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 12
			c.rings = 1
			m = c
		Shape.CONE:
			var k: CylinderMesh = CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = 0.5
			k.height = 1.0
			k.radial_segments = 10
			k.rings = 1
			m = k
		Shape.SPHERE:
			var s: SphereMesh = SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 12
			s.rings = 6
			m = s
		Shape.CAPSULE:
			var cp: CapsuleMesh = CapsuleMesh.new()
			cp.radius = 0.25
			cp.height = 1.0
			cp.radial_segments = 10
			cp.rings = 3
			m = cp
		Shape.PRISM:
			m = PrismMesh.new()
	# SurfaceTool.append_from needs an ArrayMesh-like surface: bake the primitive once.
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.get_mesh_arrays())
	_prims[shape] = am
	return am
