# WonderFx — pooled effects of the wonder weapons and special enemies (DEVELOPMENT_PLAN Step 12):
# procedural lightning arcs (jagged crossed ribbons, glowing, ~0.18 s), coloured bursts (Ray Pistol
# splash, Galvanic death burst, Conduit kill burst), expanding shock rings (Conduit pulse, Warden
# slam, special-round energy pulse), crackling energy rifts (Galvanic spawn telegraph) and plate
# sparks (Warden armor breaking). Every pool is an FxRing with a fixed cap and lights are capped
# (`MAX_LIGHTS`), so a chain through 10 zombies with 32 alive never grows node or light counts
# without bound (AC-12.6 automated part).
#   host -> all : `_wfx` [kind, radius, variant, x, y, z, (x, y, z)...]   (arcs carry every point)
# `WonderFx.play(node, ...)` presents locally and, on the host, relays to every peer.
# Authority: local presentation on every peer (the host decides what happened).
class_name WonderFx
extends Node3D

enum Kind { ARC, BURST, RING, RIFT, SPARKS }
enum Variant { GREEN, NOVA, ELECTRIC, REQUIEM, METAL }

const ARC_CAP: int = 24
const BURST_CAP: int = 8
const RING_CAP: int = 6
const RIFT_CAP: int = 12
const SPARK_CAP: int = 6
const MAX_LIGHTS: int = 8
const ARC_TIME: float = 0.18
const BURST_TIME: float = 0.9
const RING_TIME: float = 0.7
const RIFT_TIME: float = 1.6
const COLORS: Array[Color] = [
	Color(0.35, 1.0, 0.45),  # GREEN: Ray Pistol plasma
	Color(1.0, 0.42, 0.15),  # NOVA: Nova Mk.II
	Color(0.55, 0.85, 1.0),  # ELECTRIC: Conduit / Galvanics
	Color(0.85, 0.6, 1.0),  # REQUIEM: Lazarus Requiem
	Color(1.0, 0.8, 0.45),  # METAL: Warden plate sparks
]

var arcs: FxRing = null
var bursts: FxRing = null
var rings: FxRing = null
var rifts: FxRing = null
var sparks: FxRing = null
var shown: Dictionary = {}  # Kind -> count (tests / net tests)
var peak_lights: int = 0
var peak_arcs: int = 0

var _timed: Dictionary = {}  # Node -> [seconds left, total, kind]
var _materials: Array[StandardMaterial3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func of(node: Node) -> WonderFx:
	if Match.current != null and Match.current.wonder_fx != null:
		return Match.current.wonder_fx
	if node == null or not node.is_inside_tree():
		return null
	var tree: SceneTree = node.get_tree()
	var existing: Node = tree.get_first_node_in_group(&"wonder_fx")
	if existing != null:
		return existing as WonderFx
	var fx: WonderFx = WonderFx.new()
	tree.root.add_child(fx)
	return fx


# Presents an effect here and, on the host of a session, on every peer.
static func play(node: Node, kind: Kind, points: PackedVector3Array, radius: float = 1.0, variant: int = 0) -> void:
	var fx: WonderFx = of(node)
	if fx != null:
		fx.present(kind, points, radius, variant)
	if Net.is_active() and Net.is_host():
		var payload: Array = [int(kind), radius, variant]
		for p: Vector3 in points:
			payload.append_array([snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)])
		Net.send_reliable(0, &"_wfx", payload)


func _ready() -> void:
	name = "WonderFx"
	add_to_group(&"wonder_fx")
	top_level = true
	_rng.randomize()
	for c: Color in COLORS:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = c
		m.vertex_color_use_as_albedo = false
		_materials.append(m)
	arcs = FxRing.new(self, ARC_CAP, _new_arc)
	bursts = FxRing.new(self, BURST_CAP, _new_burst)
	rings = FxRing.new(self, RING_CAP, _new_ring)
	rifts = FxRing.new(self, RIFT_CAP, _new_rift)
	sparks = FxRing.new(self, SPARK_CAP, _new_sparks)
	Net.register_message(&"_wfx", _on_msg_fx)


func _exit_tree() -> void:
	Net.unregister_message(&"_wfx")


func counts() -> Dictionary:
	return {
		"arcs": arcs.size(),
		"bursts": bursts.size(),
		"rings": rings.size(),
		"rifts": rifts.size(),
		"sparks": sparks.size(),
		"active": _timed.size(),
		"lights": visible_lights(),
	}


func visible_lights() -> int:
	var n: int = 0
	for node: Variant in _timed.keys():
		if not is_instance_valid(node):
			continue
		for c: Node in (node as Node).get_children():
			if c is OmniLight3D and (c as OmniLight3D).visible:
				n += 1
	return n


func present(kind: Kind, points: PackedVector3Array, radius: float, variant: int) -> void:
	if points.is_empty():
		return
	shown[kind] = int(shown.get(kind, 0)) + 1
	var v: int = clampi(variant, 0, COLORS.size() - 1)
	match kind:
		Kind.ARC:
			_arc(points, v)
		Kind.BURST:
			_burst(points[0], radius, v)
		Kind.RING:
			_ring(points[0], radius, v)
		Kind.RIFT:
			_rift(points[0], v)
		Kind.SPARKS:
			_sparks(points[0], v)
	peak_lights = maxi(peak_lights, visible_lights())


# --- effects ------------------------------------------------------------------------------------


func _arc(points: PackedVector3Array, v: int) -> void:
	if points.size() < 2:
		return
	var mi: MeshInstance3D = arcs.next() as MeshInstance3D
	var im: ImmediateMesh = mi.mesh as ImmediateMesh
	im.clear_surfaces()
	var width: float = 0.07 if v != Variant.REQUIEM else 0.1
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _materials[v])
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var prev: Vector3 = a
		var segs: int = clampi(int(a.distance_to(b) / 0.6), 2, 14)
		for s: int in range(1, segs + 1):
			var t: float = float(s) / float(segs)
			var p: Vector3 = a.lerp(b, t)
			if s < segs:
				p += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.22
			_ribbon(im, prev, p, width)
			prev = p
	im.surface_end()
	mi.visible = true
	_timed[mi] = [ARC_TIME, ARC_TIME, Kind.ARC]
	var live: int = 0
	for n: Node in arcs.nodes:
		if (n as Node3D).visible:
			live += 1
	peak_arcs = maxi(peak_arcs, live)


static func _ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, w: float) -> void:
	var d: Vector3 = (b - a).normalized()
	var side: Vector3 = d.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = d.cross(Vector3.RIGHT)
	side = side.normalized() * w
	var up: Vector3 = d.cross(side).normalized() * w
	for o: Vector3 in [side, up]:
		im.surface_add_vertex(a - o)
		im.surface_add_vertex(a + o)
		im.surface_add_vertex(b + o)
		im.surface_add_vertex(a - o)
		im.surface_add_vertex(b + o)
		im.surface_add_vertex(b - o)


func _burst(pos: Vector3, radius: float, v: int) -> void:
	var p: CPUParticles3D = bursts.next() as CPUParticles3D
	p.global_position = pos
	p.color = COLORS[v]
	p.initial_velocity_min = radius
	p.initial_velocity_max = radius * 2.4
	p.visible = true
	p.restart()
	p.emitting = true
	var light: OmniLight3D = p.get_child(0) as OmniLight3D
	light.light_color = COLORS[v]
	light.omni_range = radius * 3.0
	light.visible = visible_lights() < MAX_LIGHTS
	_timed[p] = [BURST_TIME, BURST_TIME, Kind.BURST]


func _ring(pos: Vector3, radius: float, v: int) -> void:
	var mi: MeshInstance3D = rings.next() as MeshInstance3D
	mi.global_position = pos + Vector3.UP * 0.15
	mi.material_override = _materials[v]
	mi.scale = Vector3.ONE * 0.1
	mi.set_meta(&"radius", radius)
	mi.visible = true
	_timed[mi] = [RING_TIME, RING_TIME, Kind.RING]


func _rift(pos: Vector3, v: int) -> void:
	var root: Node3D = rifts.next() as Node3D
	root.global_position = pos
	var mi: MeshInstance3D = root.get_child(0) as MeshInstance3D
	mi.material_override = _materials[v]
	root.scale = Vector3(0.2, 0.2, 0.2)
	root.visible = true
	var cp: CPUParticles3D = root.get_child(1) as CPUParticles3D
	cp.color = COLORS[v]
	cp.restart()
	cp.emitting = true
	_timed[root] = [RIFT_TIME, RIFT_TIME, Kind.RIFT]
	Audio.play_event_3d(&"rift_crackle", pos)


func _sparks(pos: Vector3, v: int) -> void:
	var p: CPUParticles3D = sparks.next() as CPUParticles3D
	p.global_position = pos
	p.color = COLORS[v]
	p.visible = true
	p.restart()
	p.emitting = true
	_timed[p] = [0.6, 0.6, Kind.SPARKS]


func _process(delta: float) -> void:
	if _timed.is_empty():
		return
	for node: Variant in _timed.keys():
		if not is_instance_valid(node):
			_timed.erase(node)
			continue
		var e: Array = _timed[node]
		e[0] = float(e[0]) - delta
		var n3: Node3D = node as Node3D
		var u: float = 1.0 - clampf(float(e[0]) / float(e[1]), 0.0, 1.0)
		match int(e[2]):
			Kind.RING:
				var r: float = float(n3.get_meta(&"radius", 4.0))
				n3.scale = Vector3(r, 1.0, r) * maxf(u, 0.05)
			Kind.RIFT:
				var s: float = sin(u * PI)
				n3.scale = Vector3(0.6 + s * 0.6, 0.5 + s * 1.6, 0.6 + s * 0.6)
				n3.rotation.y += delta * 6.0
		if float(e[0]) <= 0.0:
			n3.visible = false
			for c: Node in n3.get_children():
				if c is OmniLight3D:
					(c as OmniLight3D).visible = false
			_timed.erase(node)


# --- pool factories -----------------------------------------------------------------------------


func _new_arc() -> Node:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func _particles(amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = lifetime
	p.emitting = false
	p.spread = 180.0
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3.ONE
	var m: StandardMaterial3D = WeaponFx._unshaded(Color.WHITE, true)
	m.vertex_color_use_as_albedo = true
	bm.material = m
	p.mesh = bm
	p.visible = false
	return p


func _new_burst() -> Node:
	var p: CPUParticles3D = _particles(40, 0.7, 0.18)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_energy = 6.0
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.visible = false
	p.add_child(light)
	return p


func _new_ring() -> Node:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func _new_rift() -> Node:
	var root: Node3D = Node3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.6
	cm.height = 2.2
	cm.radial_segments = 6
	mi.mesh = cm
	mi.position = Vector3(0, 1.1, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var cp: CPUParticles3D = _particles(24, 0.5, 0.08)
	cp.one_shot = false
	cp.explosiveness = 0.0
	cp.position = Vector3(0, 1.0, 0)
	cp.visible = true
	root.add_child(cp)
	root.visible = false
	return root


func _new_sparks() -> Node:
	var p: CPUParticles3D = _particles(30, 0.5, 0.06)
	p.gravity = Vector3(0, -9.8, 0)
	return p


func _on_msg_fx(sender: int, p: Array) -> void:
	if sender != 1 or Net.is_host() or p.size() < 6:
		return
	var pts: PackedVector3Array = PackedVector3Array()
	var i: int = 3
	while i + 2 < p.size():
		pts.append(Vector3(float(p[i]), float(p[i + 1]), float(p[i + 2])))
		i += 3
	present(int(p[0]) as Kind, pts, float(p[1]), int(p[2]))
