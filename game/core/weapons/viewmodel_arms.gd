# ViewmodelArms — placeholder first-person arms built from primitives on every viewmodel gun: a
# gripping right hand + forearm sleeve running back past the camera, and (two-handed classes) a
# support hand under the handguard. Sleeves and skin use the player's CharacterDefinition colours
# (AC-7.5 "first-person arms match the character"); authored arms replace this in Step 15.
# Authority: local presentation.
class_name ViewmodelArms
extends RefCounted

const NODE_NAME: String = "Arms"


static func attach(gun: Node3D, def: WeaponDefinition, character: CharacterDefinition, layer: int) -> Node3D:
	var old: Node = gun.get_node_or_null(NODE_NAME)
	if old != null:
		old.free()
	var root: Node3D = Node3D.new()
	root.name = NODE_NAME
	gun.add_child(root)
	var sleeve: StandardMaterial3D = StandardMaterial3D.new()
	sleeve.albedo_color = character.sleeve_color if character != null else Color(0.3, 0.3, 0.3)
	sleeve.roughness = 0.9
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = character.skin_color if character != null else Color(0.85, 0.68, 0.55)
	skin.roughness = 0.7
	var cuff: StandardMaterial3D = StandardMaterial3D.new()
	cuff.albedo_color = character.color.darkened(0.35) if character != null else Color(0.5, 0.5, 0.5)
	var grip: Vector3 = Vector3(0.0, -0.075, 0.03)
	_hand(root, "RightHand", grip, skin, layer)
	_forearm(root, "RightSleeve", grip + Vector3(0.012, -0.03, 0.05), Vector3(0.16, -0.24, 0.42), sleeve, cuff, layer)
	var support: Vector3 = _support_point(def)
	if support != Vector3.INF:
		_hand(root, "LeftHand", support, skin, layer)
		_forearm(
			root, "LeftSleeve", support + Vector3(-0.015, -0.03, 0.04), Vector3(-0.26, -0.26, 0.36), sleeve, cuff, layer
		)
	return root


# Where the left hand holds the weapon (INF = one-handed: knife / grenade).
static func _support_point(def: WeaponDefinition) -> Vector3:
	if def == null or def.is_melee() or def.weapon_class == WeaponDefinition.WeaponClass.LETHAL:
		return Vector3.INF
	match def.viewmodel_style:
		&"smg":
			return Vector3(0.0, -0.045, -0.22)
		&"shotgun":
			return Vector3(0.0, -0.04, -0.3)
		&"rifle_scoped":
			return Vector3(0.0, -0.045, -0.3)
	return Vector3(-0.012, -0.085, 0.045)  # pistol: cupping the grip


static func _hand(parent: Node3D, node_name: String, pos: Vector3, mat: Material, layer: int) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = node_name
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(0.05, 0.06, 0.085)
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.layers = layer
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)


# A tapered sleeve from `wrist` towards `wrist + toward` (back past the camera), with a cuff ring.
static func _forearm(
	parent: Node3D, node_name: String, wrist: Vector3, toward: Vector3, mat: Material, cuff_mat: Material, layer: int
) -> void:
	var length: float = toward.length()
	var dir: Vector3 = toward.normalized()
	var basis: Basis = Basis(Quaternion(Vector3.UP, dir))
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = node_name
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.048
	c.bottom_radius = 0.034
	c.height = length
	c.radial_segments = 10
	m.mesh = c
	m.material_override = mat
	m.transform = Transform3D(basis, wrist + dir * length * 0.5)
	m.layers = layer
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = node_name + "Cuff"
	var rc: CylinderMesh = CylinderMesh.new()
	rc.top_radius = 0.039
	rc.bottom_radius = 0.039
	rc.height = 0.025
	rc.radial_segments = 10
	ring.mesh = rc
	ring.material_override = cuff_mat
	ring.transform = Transform3D(basis, wrist + dir * 0.015)
	ring.layers = layer
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
