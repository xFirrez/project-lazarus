# BuildablePart — one spawn option of a buildable part (DEVELOPMENT_PLAN Step 12A scope 3): an
# interactable shown only when the host chose this option and the part is not collected yet.
# Greybox+ models per part (coil = glass vesperite coil, lens = brass focusing lens, stock = crank
# stock) with a slow bob and a faint glow so it reads from across a room.
# Authority: HOST executes the pickup (BuildableSystem.host_pickup); every peer shows the flags.
class_name BuildablePart
extends Interactable

var system: BuildableSystem = null
var def: BuildableDef = null
var part: StringName = &""
var option: int = 0
var _model: Node3D = null
var _t: float = 0.0


func _ready() -> void:
	super()
	prompt = "pick up the %s" % def.part_name(part).to_lower()
	hold_time = 0.4
	use_radius = 1.8
	ping_label = "%s part" % def.display_name
	_build_model()
	refresh()


func is_here() -> bool:
	return system != null and system.location(def.id, part) == option and not system.has_part(def.id, part)


func is_available(_player: PlayerCharacter) -> bool:
	return is_here()


func host_check(_peer_id: int, _player: PlayerCharacter) -> String:
	return "" if is_here() else "Already taken"


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	return system.host_pickup(peer_id, def, part)


func refresh() -> void:
	if _model != null:
		_model.visible = is_here()


func _process(delta: float) -> void:
	if _model == null or not _model.visible:
		return
	_t += delta
	_model.position.y = 0.9 + sin(_t * 2.0) * 0.05
	_model.rotation.y += delta * 0.8


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "PartModel"
	add_child(_model)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(0.55, 0.9, 1.0, 0.7)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.4, 0.85, 1.0)
	var brass: StandardMaterial3D = StandardMaterial3D.new()
	brass.albedo_color = Color(0.7, 0.55, 0.25)
	brass.metallic = 0.8
	brass.roughness = 0.35
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.27, 0.14)
	match part:
		&"coil":
			_mesh(_cyl(0.07, 0.22), glow, Vector3.ZERO, Vector3(0, 0, PI * 0.5))
			_mesh(_cyl(0.08, 0.03), brass, Vector3(0.12, 0, 0), Vector3(0, 0, PI * 0.5))
			_mesh(_cyl(0.08, 0.03), brass, Vector3(-0.12, 0, 0), Vector3(0, 0, PI * 0.5))
		&"lens":
			_mesh(_cyl(0.11, 0.025), glow, Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
			_mesh(_cyl(0.13, 0.04), brass, Vector3(0, 0, -0.03), Vector3(PI * 0.5, 0, 0))
		_:
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.08, 0.12, 0.38)
			_mesh(bm, wood, Vector3.ZERO, Vector3.ZERO)
			_mesh(_cyl(0.015, 0.14), brass, Vector3(0.07, -0.05, 0.1), Vector3.ZERO)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.45, 0.85, 1.0)
	light.light_energy = 0.6
	light.omni_range = 2.5
	_model.add_child(light)


func _cyl(r: float, h: float) -> CylinderMesh:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	return cm


func _mesh(m: Mesh, mat: Material, pos: Vector3, rot: Vector3) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	_model.add_child(mi)
