# TempCapsule — Step 1 placeholder avatar: a capsule driven by temporary WASD (local peer)
# or by snapshot interpolation (remote peers). Replaced by the real PlayerController in Step 2.
# Authority: the owning peer simulates its own capsule (owner-authoritative movement).
class_name TempCapsule
extends CharacterBody3D

const SPEED: float = 4.6
const GRAVITY: float = 20.0
const COLORS: Array[Color] = [
	Color(0.85, 0.32, 0.25), Color(0.25, 0.55, 0.85), Color(0.35, 0.75, 0.35), Color(0.9, 0.75, 0.25)
]

var peer_id: int = 0
var is_local: bool = false
var display_name: String = ""
var slot: int = 0
var buffer: InterpolationBuffer = InterpolationBuffer.new()
# Optional scripted input for bots/tests: returns a world-space wish direction (y ignored).
var bot_driver: Callable = Callable()
var yaw: float = 0.0

var _camera: Camera3D = null


func _ready() -> void:
	name = "Player_%d" % peer_id
	collision_layer = 1 << 1  # player
	collision_mask = 1 << 0  # world
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.8
	mesh.mesh = cm
	mesh.position.y = 0.9
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COLORS[slot % COLORS.size()]
	mesh.material_override = mat
	add_child(mesh)
	var nose: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.2, 0.15, 0.3)
	nose.mesh = bm
	nose.position = Vector3(0, 1.5, -0.35)
	add_child(nose)
	var label: Label3D = Label3D.new()
	label.text = display_name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.15
	label.font_size = 48
	add_child(label)
	if is_local:
		_camera = Camera3D.new()
		_camera.position = Vector3(0, 3.2, 5.0)
		_camera.rotation_degrees.x = -22.0
		_camera.fov = float(Config.get_value(&"video", &"fov", 90.0))
		add_child(_camera)
		_camera.current = true
	else:
		# Remote capsules are positioned from snapshots, never by local physics.
		collision_layer = 0


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = float(Config.get_value(&"input", &"mouse_sensitivity", 1.0))
		yaw -= (event as InputEventMouseMotion).relative.x * 0.003 * sens
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if is_local:
		_simulate(delta)
	elif not buffer.is_empty():
		var t: float = buffer.playback_time(Net.now())
		global_position = buffer.sample_position(t)
		yaw = buffer.sample_yaw(t)
	rotation.y = yaw


func _simulate(delta: float) -> void:
	var wish: Vector3 = Vector3.ZERO
	if bot_driver.is_valid():
		wish = bot_driver.call()
	else:
		var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		wish = Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	velocity.x = wish.x * SPEED
	velocity.z = wish.z * SPEED
	if is_on_floor():
		velocity.y = 0.0
		if not bot_driver.is_valid() and Input.is_action_just_pressed(&"jump"):
			velocity.y = 6.3
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -20.0:
		global_position = Vector3(0, 2, 0)
		velocity = Vector3.ZERO
