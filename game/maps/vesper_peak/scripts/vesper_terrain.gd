# VesperTerrain — the mountain the complex is built into (map quality pass). Before it, the zones
# floated in fog: past the Courtyard's low walls, the Comms Array parapets or the station dock the
# player looked into empty space. This builds a visual-only heightfield massif around the map:
#   * a natural shape — a plateau under the complex, the summit the Comms Array crowns, the rock
#     mass rising west of the Courtyard, an eastern ridge, the valley falling away to the north and
#     outer slopes dropping into the cloud sea before the distant mountain ring — plus noise;
#   * constraints rasterised from the zones' own colliders: terrain stays under every surface
#     structure (Courtyard, plaza, road, buildings, bays, the gondola line) and rises over every
#     buried one (tunnels, halls) so nothing pokes through either way; climb pads get a rock base.
# A fine grid (2 m) covers the complex, a coarse one (10 m) the surroundings. One mesh each, the
# shared Lazarus surface shader (rock + snow on up-facing slopes), no collision, no shadows.
# Authority: static local presentation.
class_name VesperTerrain
extends RefCounted

const SHADER: String = "res://content/shaders/lazarus_surface.gdshader"
const NOISE_TEX: String = "res://content/materials/textures/noise_detail.tres"
const FINE_LO: Vector2 = Vector2(-90.0, -180.0)  # x, z (multiples of COARSE)
const FINE_HI: Vector2 = Vector2(150.0, 40.0)
const FINE: float = 2.0
const OUTER_LO: Vector2 = Vector2(-330.0, -430.0)
const OUTER_HI: Vector2 = Vector2(390.0, 300.0)
const COARSE: float = 10.0
const SURFACE_ZONES: Array[StringName] = [&"Z01", &"Z03", &"Z04", &"Z05", &"Z06", &"Z07"]
const REACH: float = 12.0  # how far (m) a structure's constraint reaches
const SLOPE: float = 1.25  # terrain may rise/fall this many metres per metre away from a structure
const CLEAR: float = 0.35  # gap under surface structures / over buried ones
const PLATEAU: float = -9.5  # surface structures never pull the rock below this
const MODE_MAX: int = 0
const MODE_MIN: int = 1
const MODE_BURY: int = 2

var noise: FastNoiseLite = null
var _nx: int = 0
var _nz: int = 0
var _hmax: PackedFloat32Array = PackedFloat32Array()
var _hmin: PackedFloat32Array = PackedFloat32Array()
var _bury_floor: PackedFloat32Array = PackedFloat32Array()  # bottom of a buried body over the vertex


func _init() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 1952
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4


# Builds both meshes under `parent` from the zones' colliders. Returns the fine mesh instance.
func build(parent: Node3D, zones: Array) -> MeshInstance3D:
	var t0: int = Time.get_ticks_usec()
	_nx = int((FINE_HI.x - FINE_LO.x) / FINE) + 1
	_nz = int((FINE_HI.y - FINE_LO.y) / FINE) + 1
	_hmax.resize(_nx * _nz)
	_hmin.resize(_nx * _nz)
	_bury_floor.resize(_nx * _nz)
	_hmax.fill(INF)
	_hmin.fill(-INF)
	_bury_floor.fill(INF)
	for z: Node in zones:
		var zid: StringName = StringName(z.get(&"zone_id"))
		var surface: bool = SURFACE_ZONES.has(zid)
		var geo: Node = z.get_node_or_null(^"Geometry")
		if geo == null:
			continue
		for b: Node in geo.find_children("*", "StaticBody3D", true, false):
			var body: StaticBody3D = b as StaticBody3D
			if body.collision_layer & 1 == 0:
				continue
			var bb: AABB = _body_aabb(body)
			if bb.size == Vector3.ZERO:
				continue
			var nm: String = String(body.name)
			if nm.ends_with("_Pad"):
				# climb pads: a rock base right under the pad top
				_raster(bb, 8.0, MODE_MIN, bb.end.y - 0.06, -2.0)
			elif not surface or bb.end.y < PLATEAU or nm.begins_with("Grotto_"):
				_raster(bb, 2.5, MODE_MIN, bb.end.y + CLEAR, -2.5)  # buried: stay over it
				_raster(bb, 0.0, MODE_BURY, bb.position.y, 0.0)
			else:
				var base: float = maxf(bb.position.y, PLATEAU) - CLEAR
				_raster(bb, REACH, MODE_MAX, base, SLOPE)
				var flat: bool = body.global_basis.is_equal_approx(Basis.IDENTITY)
				if flat and bb.size.y <= 1.05 and bb.size.x * bb.size.z >= 6.0:
					_raster(bb, 6.0, MODE_MIN, base, -2.0)  # floors stand on the rock
				if zid == &"Z06" and flat and bb.size.y >= 2.0 and minf(bb.size.x, bb.size.z) <= 0.6 and bb.end.y < -2.0:
					_raster(bb, 14.0, MODE_MIN, bb.end.y - 0.6, -0.12)  # snow berm behind the low walls
	_gondola_line()
	var mat: Material = _material()
	var fine: MeshInstance3D = _mesh_fine(mat)
	fine.name = "TerrainNear"
	parent.add_child(fine)
	var outer: MeshInstance3D = _mesh_outer(mat)
	outer.name = "TerrainFar"
	parent.add_child(outer)
	Log.info(&"map", "vesper terrain: %d + %d verts in %.0f ms" % [_nx * _nz, _outer_count(), (Time.get_ticks_usec() - t0) / 1000.0])
	return fine


# --- natural shape ---------------------------------------------------------------------------------


func natural(x: float, z: float) -> float:
	# Plateau the complex stands on (Courtyard level), the summit under the Comms Array plaza.
	var h: float = -9.2
	var summit: float = 15.2 - 0.9 * maxf(0.0, Vector2(x, z).distance_to(Vector2(0, -119)) - 21.0)
	h = maxf(h, summit)
	# West massif (behind the Courtyard's west wall and the Boiler House), east ridge past the wing.
	h += 0.6 * maxf(0.0, -14.0 - x) - 0.004 * maxf(0.0, -14.0 - x) * maxf(0.0, -14.0 - x)
	h += 0.45 * maxf(0.0, x - 96.0)
	# The south ridge behind the summit; the valley falls away north of the station.
	h += 0.35 * maxf(0.0, -150.0 - z)
	h -= 0.55 * maxf(0.0, z - 16.0)
	var r: float = Vector2(x, z).distance_to(Vector2(28, -50))
	var amp: float = 0.8 + 0.07 * maxf(0.0, r - 60.0)
	h += noise.get_noise_2d(x, z) * amp + noise.get_noise_2d(x * 3.1, z * 3.1) * 0.6
	# Outer slopes drop into the valley cloud sea before the distant mountain ring (230 m+).
	h -= 0.9 * maxf(0.0, r - 170.0)
	return maxf(h, -150.0)


func height(x: float, z: float) -> float:
	var n: float = natural(x, z)
	var i: int = _index(x, z)
	if i < 0:
		return n
	var lo: float = _hmin[i]
	var hi: float = _hmax[i]
	if lo > hi:
		# A buried passage reaches up under a surface structure's skirt: cut below the passage
		# (a trench nobody sees) rather than through its interior.
		return minf(hi, _bury_floor[i] - CLEAR)
	return clampf(n, lo, hi)


func _index(x: float, z: float) -> int:
	var ix: int = roundi((x - FINE_LO.x) / FINE)
	var iz: int = roundi((z - FINE_LO.y) / FINE)
	if ix < 0 or iz < 0 or ix >= _nx or iz >= _nz:
		return -1
	return iz * _nx + ix


# --- constraints ------------------------------------------------------------------------------------


static func _body_aabb(body: StaticBody3D) -> AABB:
	for c: Node in body.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
			var s: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
			return body.global_transform * (c as CollisionShape3D).transform * AABB(-s * 0.5, s)
	return AABB()


# Applies a constraint to every fine vertex within `reach` of `bb` (d = xz distance outside it):
# MODE_MAX h <= v + d * k, MODE_MIN h >= v + d * k, MODE_BURY records a buried body's bottom.
func _raster(bb: AABB, reach: float, mode: int, v: float, k: float) -> void:
	var x0: int = maxi(int(floor((bb.position.x - reach - FINE_LO.x) / FINE)), 0)
	var x1: int = mini(int(ceil((bb.end.x + reach - FINE_LO.x) / FINE)), _nx - 1)
	var z0: int = maxi(int(floor((bb.position.z - reach - FINE_LO.y) / FINE)), 0)
	var z1: int = mini(int(ceil((bb.end.z + reach - FINE_LO.y) / FINE)), _nz - 1)
	for iz: int in range(z0, z1 + 1):
		var vz: float = FINE_LO.y + iz * FINE
		var dz: float = maxf(maxf(bb.position.z - vz, vz - bb.end.z), 0.0)
		for ix: int in range(x0, x1 + 1):
			var vx: float = FINE_LO.x + ix * FINE
			var dx: float = maxf(maxf(bb.position.x - vx, vx - bb.end.x), 0.0)
			var d: float = sqrt(dx * dx + dz * dz)
			if d > reach:
				continue
			var i: int = iz * _nx + ix
			match mode:
				MODE_MAX:
					_hmax[i] = minf(_hmax[i], v + d * k)
				MODE_MIN:
					_hmin[i] = maxf(_hmin[i], v + d * k)
				_:
					_bury_floor[i] = minf(_bury_floor[i], v)


# The gondola cabin (2.4 m) rides Z01 dock -> Z07 station: keep the cable line clear.
func _gondola_line() -> void:
	var pts: Array[Vector3] = [
		Vector3(-4.5, 0.0, -14.6), Vector3(-4.5, 1.5, -20.0), Vector3(-4.5, 19.5, -86.0), Vector3(-4.5, 17.0, -93.6)
	]
	for k: int in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var n: int = int(a.distance_to(b) / FINE) + 1
		for s: int in n + 1:
			var p: Vector3 = a.lerp(b, float(s) / n)
			_raster(AABB(p + Vector3(-2.0, -3.5, -1.0), Vector3(4.0, 6.0, 2.0)), REACH, MODE_MAX, p.y - 3.5 - CLEAR, SLOPE)


# --- meshes -----------------------------------------------------------------------------------------


func _material() -> Material:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	m.set_shader_parameter(&"detail_noise", load(NOISE_TEX))
	m.set_shader_parameter(&"albedo", Color(0.2, 0.21, 0.24))
	m.set_shader_parameter(&"roughness", 0.95)
	m.set_shader_parameter(&"detail_scale", 0.06)
	m.set_shader_parameter(&"detail_strength", 0.55)
	m.set_shader_parameter(&"grime_color", Color(0.08, 0.075, 0.07))
	m.set_shader_parameter(&"grime_strength", 0.7)
	m.set_shader_parameter(&"snow_amount", 1.0)
	m.set_shader_parameter(&"snow_threshold", 0.62)
	m.set_shader_parameter(&"snow_color", Color(0.78, 0.83, 0.92))
	return m


func _grid_mesh(lo: Vector2, hi: Vector2, step: float, skip: Rect2, mat: Material) -> MeshInstance3D:
	var nx: int = int((hi.x - lo.x) / step) + 1
	var nz: int = int((hi.y - lo.y) / step) + 1
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: PackedVector3Array = PackedVector3Array()
	verts.resize(nx * nz)
	for iz: int in nz:
		for ix: int in nx:
			var x: float = lo.x + ix * step
			var z: float = lo.y + iz * step
			var y: float = height(x, z)
			if skip.has_area() and skip.grow(-0.01).has_point(Vector2(x, z)):
				y -= 40.0  # under the fine mesh (its quads are skipped anyway)
			verts[iz * nx + ix] = Vector3(x, y, z)
	for iz: int in nz - 1:
		for ix: int in nx - 1:
			var a: Vector3 = verts[iz * nx + ix]
			var b: Vector3 = verts[iz * nx + ix + 1]
			var c: Vector3 = verts[(iz + 1) * nx + ix]
			var d: Vector3 = verts[(iz + 1) * nx + ix + 1]
			if skip.has_area():
				var centre: Vector2 = Vector2((a.x + d.x) * 0.5, (a.z + d.z) * 0.5)
				if skip.has_point(centre):
					continue
			for v: Vector3 in [a, b, c, b, d, c]:
				# COLOR.r drives the shader's grime: dark bands of exposed rock.
				var g: float = clampf(0.5 + noise.get_noise_2d(v.x * 4.0, v.z * 4.0) * 0.9, 0.0, 1.0)
				st.set_color(Color(g, 0, 0))
				st.add_vertex(v)
	st.index()
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(&"no_batch", true)
	return mi


func _mesh_fine(mat: Material) -> MeshInstance3D:
	return _grid_mesh(FINE_LO, FINE_HI, FINE, Rect2(), mat)


func _mesh_outer(mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = _grid_mesh(OUTER_LO, OUTER_HI, COARSE, Rect2(FINE_LO, FINE_HI - FINE_LO), mat)
	mi.extra_cull_margin = 20.0
	return mi


func _outer_count() -> int:
	return (int((OUTER_HI.x - OUTER_LO.x) / COARSE) + 1) * (int((OUTER_HI.y - OUTER_LO.y) / COARSE) + 1)
