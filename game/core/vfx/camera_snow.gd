# CameraSnow — storm snow that is always local to the viewer (ARCHITECTURE §11.1): a GPU particle
# box that follows the current Camera3D, with wind drift and turbulence gusts. `intensity` scales
# the amount per zone (0 deep underground); the quality preset's particle density scales it again
# (group `density_scaled`, Graphics autoload).
# Authority: local presentation.
class_name CameraSnow
extends GPUParticles3D

@export var intensity: float = 1.0:
	set(v):
		intensity = v
		_apply_intensity()
@export var wind: Vector3 = Vector3(2.2, 0.0, 0.8)
@export var box_extents: Vector3 = Vector3(14, 8, 14)
@export var max_flakes: int = 3500


func _init() -> void:
	add_to_group(&"density_scaled")


func _ready() -> void:
	name = "CameraSnow"
	top_level = true
	amount = max_flakes
	lifetime = 4.0
	preprocess = 4.0
	fixed_fps = 30
	local_coords = false
	visibility_aabb = AABB(-box_extents * 1.5, box_extents * 3.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box_extents
	pm.direction = (wind + Vector3(0, -1.5, 0)).normalized()
	pm.spread = 12.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(wind.x * 0.4, -1.6, wind.z * 0.4)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 3.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.8)
	mat.albedo_texture = _flake_texture()
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	draw_pass_1 = quad
	_apply_intensity()


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		# Emit slightly ahead of the view so the camera always looks into falling snow.
		global_position = cam.global_position - cam.global_basis.z * box_extents.z * 0.4
	emitting = intensity > 0.0


func _apply_intensity() -> void:
	if not is_inside_tree():
		return
	var density: float = Graphics.preset.particle_density if Graphics.preset != null else 1.0
	amount_ratio = clampf(intensity, 0.0, 1.0) * density


static func _flake_texture() -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 16:
			var d: float = Vector2(x - 7.5, y - 7.5).length() / 7.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
