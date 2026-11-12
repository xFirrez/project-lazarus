# PlayerCharacter — the player avatar (ARCHITECTURE §6.1), composed of MotorComponent,
# CameraRig, HealthComponent, FootstepComponent and WeaponController (Step 3). The local player reads input once per
# physics tick into a PlayerInputFrame (or takes frames from `bot_driver`), simulates its own
# motion and renders a first-person camera + DamageHud. Remote players are puppets: positioned
# from the InterpolationBuffer, drawn as their character's third-person model (SurvivorModel; a
# coloured capsule when the character has no model) with a name tag that fades with distance.
# The character (CharacterDefinition, chosen in the lobby) sets the identification colour.
# Authority: owner simulates movement; health is host-authoritative (applied via PlayerSync).
class_name PlayerCharacter
extends CharacterBody3D

signal fall_damage_claimed(height: float)

const COLORS: Array[Color] = [
	Color(0.85, 0.32, 0.25), Color(0.25, 0.55, 0.85), Color(0.35, 0.75, 0.35), Color(0.9, 0.75, 0.25)
]
const DEFAULT_TUNING: String = "res://content/player/player_tuning.tres"
const KILL_Y: float = -30.0
const TAG_FULL_DISTANCE: float = 12.0  # name tags: opaque up to here ...
const TAG_HIDE_DISTANCE: float = 40.0  # ... faded out by here

@export var tuning: PlayerTuning = null

var peer_id: int = 0
var is_local: bool = false
var is_bot: bool = false  # host-simulated test player (no camera / HUD / input; Step 6 soak bots)
var spectating: bool = false  # bled out: hidden, waits for the next round (DownedSystem)
var reviving: bool = false  # local: holding revive on a teammate (can't shoot)
var notarget: bool = false  # host: zombies ignore this player (debug `notarget`)
var display_name: String = ""
var slot: int = 0
var character_id: StringName = &""
var character: CharacterDefinition = null
var perks: Array = []  # Vigor Tonic ids (Step 10); retained on reconnect (MatchSession)
var model: SurvivorModel = null  # third-person model (remote puppets and host bots)
var buffer: InterpolationBuffer = InterpolationBuffer.new()
# Optional scripted input for bots/tests: Callable(player: PlayerCharacter, delta: float) -> PlayerInputFrame
var bot_driver: Callable = Callable()
var input_source: PlayerInputSource = null
var last_frame: PlayerInputFrame = PlayerInputFrame.new()
var hud: DamageHud = null
var weapons: WeaponController = null
# Replicated presentation state (remote puppets).
var remote_flags: int = 0
var remote_pitch: float = 0.0

var _hud_layer: CanvasLayer = null
var _visual: Node3D = null
var _body_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _tag: Label3D = null
var _remote_grounded: bool = true

@onready var motor: MotorComponent = $Motor
@onready var camera_rig: CameraRig = $Head
@onready var health: HealthComponent = $Health
@onready var footsteps: FootstepComponent = $Footsteps
@onready var collision: CollisionShape3D = $Collision
@onready var camera: Camera3D = $Head/Camera


func _ready() -> void:
	if tuning == null:
		tuning = load(DEFAULT_TUNING) as PlayerTuning
	tuning = tuning.duplicate() as PlayerTuning  # per-player copy so `tune` can edit live
	name = "Player_%d" % peer_id
	collision.shape = (collision.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	motor.setup(self, collision, tuning)
	camera_rig.setup(self, motor, tuning, camera)
	camera_rig.yaw = rotation.y
	health.setup(tuning)
	footsteps.setup(self, not is_local)
	if character == null:
		character = CharacterDefinition.get_def(character_id) if character_id != &"" else null
		if character == null:
			character = CharacterDefinition.for_slot(slot)
		character_id = character.id if character != null else &""
	_build_visual()
	if is_local or is_bot:
		collision_layer = 1 << 1  # player
		collision_mask = 1 << 0 | MotorComponent.PLAYER_CLIP_LAYER  # world + player clip
	if is_local:
		input_source = PlayerInputSource.new(tuning)
		camera.current = true
		_visual.visible = false
		motor.landed.connect(_on_landed)
		motor.jumped.connect(func() -> void: Audio.play_event(&"player_jump"))
		motor.slide_started.connect(func() -> void: Audio.play_event(&"player_slide"))
		motor.mantle_started.connect(func(_h: float) -> void: Audio.play_event(&"player_mantle"))
		health.damaged.connect(_on_damaged)
		_hud_layer = CanvasLayer.new()
		_hud_layer.layer = 5
		add_child(_hud_layer)
		hud = DamageHud.new()
		hud.player = self
		_hud_layer.add_child(hud)
	if is_bot:
		camera.current = false
	elif not is_local:
		# Remote puppets are positioned from snapshots, never by local physics.
		collision_layer = 0
		collision_mask = 0
		camera.current = false
	weapons = WeaponController.new()
	add_child(weapons)
	weapons.setup(self)


# Identification colour (HUD points list, name tag, pings, markers).
func player_color() -> Color:
	if character != null:
		return character.color
	return COLORS[slot % COLORS.size()]


# Lobby / roster update: switch the character (colour, name tag, model, first-person sleeves).
func set_character(def: CharacterDefinition) -> void:
	if def == null or def == character:
		return
	character = def
	character_id = def.id
	if _visual != null:
		_visual.queue_free()
		_visual = null
		_build_visual()
	if weapons != null and weapons.viewmodel != null:
		weapons.viewmodel.refresh_arms()


func get_yaw() -> float:
	return camera_rig.yaw


func get_pitch() -> float:
	return camera_rig.pitch if is_local else remote_pitch


func set_view(p_yaw: float, p_pitch: float) -> void:
	camera_rig.yaw = p_yaw
	camera_rig.pitch = p_pitch
	rotation.y = p_yaw


# Bit-packed movement state for replication: stance (2 bits), grounded, sprinting, downed, spectating.
func state_flags() -> int:
	return (
		int(motor.stance)
		| (4 if motor.grounded else 0)
		| (8 if motor.sprinting else 0)
		| (16 if health.is_downed else 0)
		| (32 if spectating else 0)
	)


func remote_stance() -> int:
	return remote_flags & 3


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	input_source.handle_event(event)
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not is_local:
		weapons.render_update(delta)
		_update_tag()
		if model != null:
			model.update_from(self, delta)
		return
	if not bot_driver.is_valid():
		camera_rig.add_look(input_source.consume_look(delta))
	camera_rig.update_view(delta)
	weapons.render_update(delta)


func _physics_process(delta: float) -> void:
	health.tick(delta)
	if is_local or is_bot:
		_simulate(delta)
	else:
		_puppet(delta)


func _simulate(delta: float) -> void:
	var f: PlayerInputFrame = null
	if bot_driver.is_valid():
		f = bot_driver.call(self, delta)
	if f == null:
		f = input_source.gather() if input_source != null else PlayerInputFrame.new()
	_filter_for_state(f)
	last_frame = f
	camera_rig.add_look(f.look_delta)
	rotation.y = camera_rig.yaw
	motor.downed = health.is_downed
	motor.physics_step(f, delta)
	if is_local:
		weapons.physics_step(f, delta)
	footsteps.update(motor.grounded, motor.sprinting, motor.is_crouched())


# Downed: crawl with the last-stand pistol only; spectators don't act; revivers can't shoot.
func _filter_for_state(f: PlayerInputFrame) -> void:
	if spectating:
		for prop: String in ["fire", "aim", "jump_pressed", "jump_held", "sprint", "crouch_pressed"]:
			f.set(prop, false)
		f.move = Vector2.ZERO
		f.melee_pressed = false
		f.lethal_held = false
		f.reload_pressed = false
		f.interact = false
		f.switch_slot = -1
		f.switch_delta = 0
		return
	if health.is_downed:
		f.sprint = false
		f.jump_pressed = false
		f.jump_held = false
		f.crouch = true
		f.crouch_pressed = false
		f.melee_pressed = false
		f.lethal_held = false
		f.switch_slot = -1
		f.switch_delta = 0
		f.interact = false
	if reviving:
		f.fire = false
		f.aim = false
		f.sprint = false


func _puppet(_delta: float) -> void:
	if not buffer.is_empty():
		var t: float = buffer.playback_time(Net.now())
		global_position = buffer.sample_position(t)
		rotation.y = buffer.sample_yaw(t)
	var stance: int = remote_stance()
	var crouched: bool = stance == MotorComponent.Stance.CROUCH or stance == MotorComponent.Stance.SLIDE
	var grounded: bool = (remote_flags & 4) != 0
	var target_scale: float = tuning.crouch_height / tuning.stand_height if crouched else 1.0
	if remote_flags & 16:
		target_scale = 0.35  # downed: lying on the ground
	_visual.visible = (remote_flags & 32) == 0
	if model == null:
		_visual.scale.y = move_toward(_visual.scale.y, target_scale, _delta * 4.0)
	if grounded and not _remote_grounded:
		footsteps.play(&"land")
	_remote_grounded = grounded
	footsteps.update(grounded, (remote_flags & 8) != 0, crouched)


func _on_landed(impact_speed: float, fall_height: float) -> void:
	if impact_speed > 3.0:
		footsteps.play(&"land")
	if fall_height > tuning.fall_damage_min_height:
		fall_damage_claimed.emit(fall_height)


func _on_damaged(amount: float, _source: Vector3, _type: int) -> void:
	camera_rig.add_trauma(clampf(amount / 100.0, 0.1, 0.6))


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if is_local:
		_visual.visible = false
	var col: Color = player_color()
	model = null
	# The local player never sees its own body (first person): skip the animated model there.
	if (
		not is_local
		and character != null
		and character.model_scene != ""
		and ResourceLoader.exists(character.model_scene)
	):
		var packed: PackedScene = load(character.model_scene) as PackedScene
		model = packed.instantiate() as SurvivorModel
	if model != null:
		model.character = character
		_visual.add_child(model)
	else:
		_build_capsule(col)
	_tag = Label3D.new()
	_tag.name = "NameTag"
	_tag.text = display_name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true  # readable through walls; alpha fades with distance
	_tag.fixed_size = false
	_tag.position.y = tuning.stand_height + 0.3
	_tag.font_size = 48
	_tag.outline_size = 10
	_tag.modulate = col
	_tag.outline_modulate = Color(0, 0, 0, 0.8)
	_tag.render_priority = 2
	_visual.add_child(_tag)


func _build_capsule(col: Color) -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = col
	_body_mesh = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = tuning.capsule_radius
	cm.height = tuning.stand_height - 0.25
	_body_mesh.mesh = cm
	_body_mesh.position.y = (tuning.stand_height - 0.25) * 0.5
	_body_mesh.material_override = _body_mat
	_visual.add_child(_body_mesh)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	head.mesh = sm
	head.position = Vector3(0.0, tuning.stand_height - 0.2, 0.0)
	head.material_override = _body_mat
	_visual.add_child(head)
	var visor: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.22, 0.08, 0.1)
	visor.mesh = bm
	visor.position = Vector3(0.0, tuning.stand_height - 0.18, -0.14)
	_visual.add_child(visor)


# Name tag alpha from the distance to the viewing camera (GAME_DESIGN §13 "fade with distance").
static func tag_alpha(distance: float) -> float:
	if distance <= TAG_FULL_DISTANCE:
		return 1.0
	return clampf(1.0 - (distance - TAG_FULL_DISTANCE) / (TAG_HIDE_DISTANCE - TAG_FULL_DISTANCE), 0.0, 1.0)


func _update_tag() -> void:
	if _tag == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not bool(Config.get_value(&"gameplay", &"name_tags", true)):
		_tag.visible = false
		return
	var a: float = tag_alpha(cam.global_position.distance_to(global_position))
	_tag.visible = a > 0.01
	var c: Color = player_color()
	c.a = a
	_tag.modulate = c
	_tag.outline_modulate = Color(0, 0, 0, 0.8 * a)
