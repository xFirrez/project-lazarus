# Viewmodel — first-person weapon rendering (Step 3 scope 4). A separate Camera3D inside a
# transparent SubViewport renders only the "viewmodel" render layer (2) with its own FOV and is
# composited over the world view, so the weapon never clips into walls; the main camera culls
# layer 2. Hierarchy (inside the viewport camera):
#   Sway (procedural layers) ── Anim (AnimationPlayer target) ── Gun_<id> (GreyboxGun)
#        ├─ Knife, Events (method-track sink), AnimationPlayer
# Procedural layers: spring recoil (position + rotation), mouse-lag sway, movement bob synced to
# the footstep phase, ADS alignment from the gun's sight point, landing kick, sprint pose and the
# breathing scope sway for snipers (applied to the aim through CameraRig.aim_offset).
# Authority: local presentation (local player only).
class_name Viewmodel
extends Node

const LAYER: int = 1 << 1  # 3d_render/layer_2 "viewmodel"
const SPRING_K: float = 320.0
const SPRING_DAMP: float = 0.55  # damping ratio (bouncy kick)
const SWAY_GAIN: float = 0.9
const SWAY_MAX: float = 0.08

var player: PlayerCharacter = null
var container: SubViewportContainer = null
var viewport: SubViewport = null
var camera: Camera3D = null
var sway_root: Node3D = null
var anim_root: Node3D = null
var anim: AnimationPlayer = null
var events: ViewmodelEvents = null
var knife: Node3D = null
var gun: Node3D = null
var def: WeaponDefinition = null
var runtime: WeaponRuntime = null
var breath_enabled: bool = true
var melee_time: float = 0.45

var _guns: Dictionary = {}  # weapon id -> Node3D
var _libs: Dictionary = {}  # weapon id -> library name
var _rk_pos: Vector3 = Vector3.ZERO
var _rk_pos_v: Vector3 = Vector3.ZERO
var _rk_rot: Vector3 = Vector3.ZERO
var _rk_rot_v: Vector3 = Vector3.ZERO
var _sway: Vector2 = Vector2.ZERO
var _last_view: Vector2 = Vector2.INF
var _sprint_w: float = 0.0
var _bob_w: float = 0.0
var _breath_t: float = 0.0
var _last_shell_mag: int = -1
var _shell_phase: int = -1


func setup(p_player: PlayerCharacter, canvas: CanvasLayer) -> void:
	player = p_player
	container = SubViewportContainer.new()
	container.name = "ViewmodelContainer"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(container)
	viewport = SubViewport.new()
	viewport.name = "ViewmodelViewport"
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_3d = false
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	camera = Camera3D.new()
	camera.name = "ViewmodelCamera"
	camera.cull_mask = LAYER
	camera.near = 0.01
	camera.far = 10.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 1.0
	# Metals need something to reflect (I-004): a neutral studio sky used only for reflections;
	# the background stays transparent so the world shows through.
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.6, 0.7)
	sky_mat.sky_horizon_color = Color(0.75, 0.75, 0.75)
	sky_mat.ground_horizon_color = Color(0.35, 0.33, 0.3)
	sky_mat.ground_bottom_color = Color(0.12, 0.11, 0.1)
	env.sky = Sky.new()
	env.sky.sky_material = sky_mat
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	camera.environment = env
	viewport.add_child(camera)
	camera.current = true
	player.camera.cull_mask &= ~LAYER
	sway_root = Node3D.new()
	sway_root.name = "Sway"
	camera.add_child(sway_root)
	anim_root = Node3D.new()
	anim_root.name = "Anim"
	sway_root.add_child(anim_root)
	knife = _build_knife()
	sway_root.add_child(knife)
	events = ViewmodelEvents.new()
	events.name = "Events"
	sway_root.add_child(events)
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	sway_root.add_child(anim)
	player.motor.landed.connect(_on_landed)


func set_weapon(p_def: WeaponDefinition, p_runtime: WeaponRuntime) -> void:
	def = p_def
	runtime = p_runtime
	if gun != null:
		gun.visible = false
	if not _guns.has(def.id):
		var g: Node3D = null
		if def.viewmodel_scene != null:
			# Authored models import on render layer 1; the viewmodel camera only sees layer 2.
			g = def.viewmodel_scene.instantiate() as Node3D
			GreyboxGun.set_layers(g, LAYER)
		else:
			g = GreyboxGun.build(def)
		anim_root.add_child(g)
		ViewmodelArms.attach(g, def, player.character, LAYER)
		if def.dual_wield:
			_add_left_gun(g, def)
		WeaponCamo.apply(g, def)
		_guns[def.id] = g
		var lib_name: StringName = StringName(String(def.id))
		anim.add_animation_library(lib_name, ViewmodelAnimations.build(def, g, melee_time))
		_libs[def.id] = lib_name
	gun = _guns[def.id]
	play(&"idle")  # every clip keys the full pose: reset whatever the previous weapon left
	gun.visible = true
	events.weapon = def
	camera.fov = def.viewmodel_fov
	_rk_pos = Vector3.ZERO
	_rk_rot = Vector3.ZERO
	_rk_pos_v = Vector3.ZERO
	_rk_rot_v = Vector3.ZERO
	_shell_phase = -1


# The player's character changed (lobby / late roster update): re-tint the arms of every gun.
func refresh_arms() -> void:
	for wid: Variant in _guns:
		ViewmodelArms.attach(_guns[wid] as Node3D, WeaponCatalog.get_def(StringName(wid)), player.character, LAYER)


func play(clip: StringName, speed: float = 1.0) -> void:
	if def == null:
		return
	var full: StringName = StringName("%s/%s" % [_libs[def.id], clip])
	if anim.has_animation(full):
		anim.stop()
		anim.play(full, -1.0, speed)


func current_clip() -> String:
	return String(anim.current_animation).get_slice("/", 1)


# Spring impulse for one shot.
func kick(ads: float) -> void:
	if def == null:
		return
	var s: float = lerpf(1.0, 0.45, ads)
	_rk_pos_v += Vector3(randf_range(-0.1, 0.1), 0.15, 1.0) * def.vm_kick_back * 25.0 * s
	_rk_rot_v += (
		Vector3(deg_to_rad(def.vm_kick_rot), randf_range(-0.3, 0.3) * deg_to_rad(def.vm_kick_rot), 0.0) * 25.0 * s
	)


func muzzle_transform(left: bool = false) -> Transform3D:
	var m: Node3D = null
	if gun != null:
		if left:
			m = gun.get_node_or_null(^"LeftGun/Muzzle") as Node3D
		if m == null:
			m = gun.get_node_or_null(^"Muzzle") as Node3D
	return m.global_transform if m != null else camera.global_transform


# Dual wield (Gemini, Black Scorpions): a mirrored copy of the gun in the left hand. It rides the
# right gun's animation (child node) so recoil and reloads stay in sync; shots alternate muzzles.
func _add_left_gun(g: Node3D, p_def: WeaponDefinition) -> void:
	var left: Node3D = null
	if p_def.viewmodel_scene != null:
		left = p_def.viewmodel_scene.instantiate() as Node3D
		GreyboxGun.set_layers(left, LAYER)
	else:
		left = GreyboxGun.build(p_def)
	left.name = "LeftGun"
	var dot: Node = left.find_child("SightDot", true, false)
	if dot != null:
		dot.free()  # the ADS sight stays the right gun's
	left.position = Vector3(-2.0 * p_def.viewmodel_offset.x, -0.01, 0.02)
	left.scale = Vector3(-1.0, 1.0, 1.0)
	g.add_child(left)


func eject_position() -> Vector3:
	var m: Node3D = gun.get_node_or_null(^"Eject") as Node3D if gun != null else null
	return m.global_position if m != null else camera.global_position


# Hip position of the weapon pivot in camera space, and the fully aimed one (sight on the axis).
func hip_position() -> Vector3:
	return def.viewmodel_offset


func ads_position() -> Vector3:
	var s: Vector3 = GreyboxGun.sight_point(gun)
	return Vector3(-s.x, -s.y, def.viewmodel_offset.z * 0.85)


# Screen position (viewport pixels) of the gun's sight point — used by the ADS alignment tests.
func sight_screen_position() -> Vector2:
	var m: Node3D = gun.get_node_or_null(^"Sight") as Node3D
	return camera.unproject_position(m.global_position)


# Breathing scope sway as an aim offset in radians (snipers in ADS).
func breath_offset() -> Vector2:
	if def == null or def.scope_sway <= 0.0 or runtime == null or not breath_enabled:
		return Vector2.ZERO
	var amp: float = deg_to_rad(def.scope_sway) * runtime.ads
	return Vector2(sin(_breath_t * 0.9), sin(_breath_t * 1.7) * 0.6) * amp


# Called every render frame by WeaponController after the camera rig has moved.
func update(delta: float) -> void:
	if def == null or runtime == null or camera == null:
		return
	camera.global_transform = player.camera.global_transform
	_breath_t += delta
	var dt: float = minf(delta, 0.05)
	var ads: float = smoothstep(0.0, 1.0, runtime.ads)
	# Spring recoil.
	var c: float = 2.0 * sqrt(SPRING_K) * SPRING_DAMP
	_rk_pos_v += (-SPRING_K * _rk_pos - c * _rk_pos_v) * dt
	_rk_pos += _rk_pos_v * dt
	_rk_rot_v += (-SPRING_K * _rk_rot - c * _rk_rot_v) * dt
	_rk_rot += _rk_rot_v * dt
	# Mouse-lag sway from the view change this frame.
	var view: Vector2 = Vector2(player.camera_rig.yaw, player.camera_rig.pitch)
	if _last_view == Vector2.INF:
		_last_view = view
	var dv: Vector2 = Vector2(wrapf(view.x - _last_view.x, -PI, PI), view.y - _last_view.y)
	_last_view = view
	var target_sway: Vector2 = (dv * SWAY_GAIN).limit_length(SWAY_MAX) * lerpf(1.0, 0.15, ads)
	_sway = _sway.lerp(target_sway, clampf(dt * 10.0, 0.0, 1.0))
	# Bob synced to the footstep stride.
	var m: MotorComponent = player.motor
	var moving: bool = m.grounded and m.horizontal_speed() > 0.5 and m.stance != MotorComponent.Stance.SLIDE
	_bob_w = move_toward(
		_bob_w, clampf(m.horizontal_speed() / player.tuning.sprint_speed, 0.0, 1.0) if moving else 0.0, dt * 4.0
	)
	var phase: float = player.footsteps.stride_phase(m.sprinting, m.is_crouched())
	var side: float = 1.0 if player.footsteps.steps_played % 2 == 0 else -1.0
	var bob_scale: float = float(Config.get_value(&"video", &"camera_bob_scale", 1.0))
	var bob: Vector3 = Vector3(sin(phase * PI) * side * 0.012, -absf(sin(phase * PI)) * 0.018, 0.0)
	bob *= _bob_w * bob_scale * lerpf(1.0, 0.12, ads)
	# Sprint pose.
	var sprinting: bool = runtime.state == WeaponRuntime.State.SPRINT
	_sprint_w = move_toward(_sprint_w, 1.0 if sprinting else 0.0, dt / maxf(def.sprint_out_time, 0.08))
	var sprint_pos: Vector3 = Vector3(0.04, -0.06, 0.04) * _sprint_w
	var sprint_rot: Vector3 = Vector3(-0.35, 0.55, 0.25) * _sprint_w
	var pos: Vector3 = hip_position().lerp(ads_position(), ads) + bob + sprint_pos + _rk_pos * lerpf(1.0, 0.5, ads)
	var rot: Vector3 = Vector3(-_sway.y, -_sway.x, -_sway.x * 0.5) + _rk_rot * lerpf(1.0, 0.4, ads) + sprint_rot
	sway_root.transform = Transform3D(Basis.from_euler(rot), pos)
	camera.fov = lerpf(def.viewmodel_fov, def.viewmodel_fov * 0.92, ads)
	_update_clips()


func _update_clips() -> void:
	match runtime.state:
		WeaponRuntime.State.SPRINT:
			if current_clip() != "sprint":
				play(&"sprint")
		WeaponRuntime.State.RELOADING:
			if def.reload_per_shell:
				var ph: int = runtime.shell_phase
				if ph == WeaponRuntime.ShellPhase.INSERT and (_shell_phase != ph or runtime.mag != _last_shell_mag):
					if not anim.is_playing() or current_clip() != "reload_shell" or runtime.mag != _last_shell_mag:
						play(&"reload_shell", runtime.speed_multiplier)
				elif ph == WeaponRuntime.ShellPhase.END and _shell_phase != ph:
					play(&"reload_end", runtime.speed_multiplier)
				_shell_phase = ph
				_last_shell_mag = runtime.mag
		_:
			_shell_phase = -1
			if current_clip() == "sprint":
				play(&"idle")


func _on_landed(impact_speed: float, _h: float) -> void:
	_rk_pos_v += Vector3(0.0, -minf(impact_speed, 12.0) * 0.06, 0.0)
	_rk_rot_v += Vector3(-minf(impact_speed, 12.0) * 0.12, 0.0, 0.0)


func _build_knife() -> Node3D:
	var k: Node3D = Node3D.new()
	k.name = "Knife"
	k.visible = false
	var blade: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.008, 0.025, 0.16)
	blade.mesh = bm
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.75, 0.77, 0.8)
	steel.roughness = 0.3
	blade.material_override = steel
	blade.position = Vector3(0, 0, -0.08)
	blade.layers = LAYER
	k.add_child(blade)
	var handle: MeshInstance3D = MeshInstance3D.new()
	var hm: BoxMesh = BoxMesh.new()
	hm.size = Vector3(0.025, 0.03, 0.09)
	handle.mesh = hm
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.1, 0.08)
	handle.material_override = dark
	handle.position = Vector3(0, 0, 0.04)
	handle.layers = LAYER
	k.add_child(handle)
	return k
