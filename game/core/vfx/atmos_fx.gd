# AtmosFx — factory for the map-dressing particle effects and fog volumes (Step 13, DEVELOPMENT_PLAN
# §13 scope 3): dust motes, steam, sparks, drips, embers, vesperite energy leaks, snow drifting
# through openings, breath-fog haze, and local FogVolumes. Every emitter is small (≤ 64 particles),
# distance-culled (`visibility_range_end`) and joins `density_scaled`, so the quality preset scales
# it (Graphics autoload). Textures are generated once and shared.
# Authority: local presentation.
class_name AtmosFx
extends RefCounted

enum Kind { DUST, STEAM, SPARKS, DRIPS, EMBERS, ENERGY, SNOW_DRIFT, HAZE }

const CULL_DISTANCE: float = 45.0

static var _dot: ImageTexture = null
static var _mats: Dictionary = {}


# Creates an emitter of `kind` filling `extents` (half-size box) at `pos`; `dir` = main direction.
static func emitter(
	kind: Kind, pos: Vector3, extents: Vector3 = Vector3.ONE, dir: Vector3 = Vector3.UP
) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Fx_%s" % Kind.keys()[kind]
	p.position = pos
	p.add_to_group(&"density_scaled")
	p.add_to_group(&"atmos_fx")
	p.visibility_range_end = CULL_DISTANCE
	p.local_coords = false
	p.fixed_fps = 30
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = dir.normalized()
	var size: float = 0.05
	var color: Color = Color(1, 1, 1, 0.5)
	var additive: bool = false
	match kind:
		Kind.DUST:
			p.amount = 40
			p.lifetime = 9.0
			p.preprocess = 9.0
			pm.gravity = Vector3(0, -0.01, 0)
			pm.spread = 180.0
			pm.initial_velocity_min = 0.02
			pm.initial_velocity_max = 0.08
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.4
			pm.turbulence_noise_scale = 2.0
			size = 0.025
			color = Color(1.0, 0.92, 0.75, 0.35)
		Kind.STEAM:
			p.amount = 28
			p.lifetime = 2.4
			pm.gravity = Vector3(0, 0.6, 0)
			pm.spread = 14.0
			pm.initial_velocity_min = 1.2
			pm.initial_velocity_max = 2.2
			pm.damping_min = 0.6
			pm.damping_max = 1.0
			pm.scale_min = 1.0
			pm.scale_max = 3.0
			size = 0.45
			color = Color(0.85, 0.88, 0.9, 0.18)
		Kind.SPARKS:
			p.amount = 24
			p.lifetime = 0.9
			p.explosiveness = 0.85
			pm.gravity = Vector3(0, -9.8, 0)
			pm.spread = 60.0
			pm.initial_velocity_min = 1.5
			pm.initial_velocity_max = 4.0
			size = 0.03
			color = Color(1.0, 0.75, 0.3, 1.0)
			additive = true
		Kind.DRIPS:
			p.amount = 6
			p.lifetime = 1.2
			pm.gravity = Vector3(0, -9.8, 0)
			pm.spread = 0.0
			pm.initial_velocity_min = 0.0
			pm.initial_velocity_max = 0.0
			size = 0.02
			color = Color(0.7, 0.8, 0.85, 0.6)
		Kind.EMBERS:
			p.amount = 30
			p.lifetime = 3.0
			pm.gravity = Vector3(0, 0.5, 0)
			pm.spread = 30.0
			pm.initial_velocity_min = 0.3
			pm.initial_velocity_max = 1.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.8
			size = 0.03
			color = Color(1.0, 0.45, 0.12, 1.0)
			additive = true
		Kind.ENERGY:
			p.amount = 32
			p.lifetime = 2.0
			pm.gravity = Vector3(0, 0.25, 0)
			pm.spread = 180.0
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.5
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 1.2
			size = 0.05
			color = Color(0.35, 1.0, 0.55, 0.9)
			additive = true
		Kind.SNOW_DRIFT:
			p.amount = 48
			p.lifetime = 3.0
			p.preprocess = 3.0
			pm.gravity = Vector3(0, -0.8, 0)
			pm.spread = 25.0
			pm.initial_velocity_min = 1.0
			pm.initial_velocity_max = 2.5
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			size = 0.035
			color = Color(0.92, 0.95, 1.0, 0.8)
		Kind.HAZE:
			p.amount = 12
			p.lifetime = 6.0
			p.preprocess = 6.0
			pm.gravity = Vector3.ZERO
			pm.spread = 180.0
			pm.initial_velocity_min = 0.05
			pm.initial_velocity_max = 0.15
			pm.scale_min = 2.0
			pm.scale_max = 4.0
			size = 0.8
			color = Color(0.7, 0.8, 0.9, 0.07)
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	grad.colors = PackedColorArray([Color(color, 0.0), color, color, Color(color, 0.0)])
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size) * 2.0
	quad.material = _material(additive)
	p.draw_pass_1 = quad
	var reach: float = maxf(extents.length() * 2.0, 4.0) + 6.0
	p.visibility_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	return p


static func clear_cache() -> void:
	_dot = null
	_mats.clear()


# A local fog volume (Forward+ volumetric fog; ignored where volumetric fog is off).
static func fog(
	pos: Vector3, size: Vector3, albedo: Color, density: float = 0.6, emission: Color = Color.BLACK
) -> FogVolume:
	var fv: FogVolume = FogVolume.new()
	fv.name = "FogVolume"
	fv.position = pos
	fv.size = size
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var fm: FogMaterial = FogMaterial.new()
	fm.albedo = albedo
	fm.density = density
	fm.emission = emission
	fm.edge_fade = 0.6
	fv.material = fm
	return fv


static func _material(additive: bool) -> StandardMaterial3D:
	if _mats.has(additive):
		return _mats[additive]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mats[additive] = m
	return m


static func dot_texture() -> ImageTexture:
	if _dot == null:
		var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y: int in 32:
			for x: int in 32:
				var d: float = Vector2(x - 15.5, y - 15.5).length() / 15.5
				var a: float = clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_dot = ImageTexture.create_from_image(img)
	return _dot
