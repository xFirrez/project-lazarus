# GreyboxGun — builds a placeholder weapon model from primitives for a WeaponDefinition with no
# authored viewmodel scene (Step 4 / 9 supply real models). Every model has the nodes the
# viewmodel and animations rely on:
#   Mag, Action (slide / bolt / pump), Muzzle, Eject (markers) and Sight (the sight point: the
#   fibre-optic front-sight dot, or the scope reticle centre, coloured SIGHT_COLOR so the ADS
#   alignment screenshot test can find it).
# Styles: pistol | smg | shotgun | rifle | lmg | launcher | crossbow | rifle_scoped. Step 9 adds
# rifle / lmg / launcher / crossbow (the "greybox+" fallback of DEVELOPMENT_PLAN Step 9 risks).
# The weapon's local -Z is forward; Sight sits at (0, def.sight_height, z_front).
# Authority: local presentation.
class_name GreyboxGun
extends RefCounted

const SIGHT_COLOR: Color = Color(1.0, 0.0, 1.0)
const VIEWMODEL_LAYER: int = 1 << 1


static func build(def: WeaponDefinition, layer: int = VIEWMODEL_LAYER) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Gun_%s" % def.id
	var body: StandardMaterial3D = _mat(def.viewmodel_color)
	var dark: StandardMaterial3D = _mat(def.viewmodel_color.darkened(0.45))
	var wood: StandardMaterial3D = _mat(Color(0.42, 0.27, 0.14))
	var sight_mat: StandardMaterial3D = _mat(SIGHT_COLOR)
	sight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var front: float = -0.2
	var h: float = def.sight_height
	match def.viewmodel_style:
		&"smg":
			front = -0.38
			_box(root, "Receiver", Vector3(0.05, 0.06, 0.32), Vector3(0, 0, -0.1), body)
			_box(root, "Barrel", Vector3(0.025, 0.025, 0.2), Vector3(0, 0.01, -0.34), dark)
			_box(root, "Grip", Vector3(0.035, 0.1, 0.045), Vector3(0, -0.07, 0.02), dark, deg_to_rad(15))
			_box(root, "Stock", Vector3(0.02, 0.03, 0.22), Vector3(0, -0.01, 0.16), dark)
			var mag: Node3D = _node(root, "Mag", Vector3(0, -0.04, -0.12))
			_box(mag, "MagBox", Vector3(0.03, 0.2, 0.035), Vector3(0, -0.09, 0), dark)
			var act: Node3D = _node(root, "Action", Vector3(0.03, 0.015, -0.05))
			_box(act, "Bolt", Vector3(0.012, 0.012, 0.03), Vector3.ZERO, dark)
			_post(root, "RearSight", Vector2(0.03, 0.01), 0.03, h - 0.006, 0.02, dark)
			_post(root, "FrontPost", Vector2(0.004, 0.004), 0.03, h - 0.002, front, dark)
		&"shotgun":
			front = -0.55
			_box(root, "Receiver", Vector3(0.055, 0.07, 0.24), Vector3(0, 0, -0.02), body)
			_cyl(root, "Barrel", 0.016, 0.5, Vector3(0, 0.02, -0.33), dark)
			_cyl(root, "Tube", 0.013, 0.36, Vector3(0, -0.012, -0.28), dark)
			_box(root, "Stock", Vector3(0.04, 0.07, 0.28), Vector3(0, -0.04, 0.22), wood, deg_to_rad(-8))
			var pump: Node3D = _node(root, "Action", Vector3(0, -0.012, -0.3))
			_box(pump, "Pump", Vector3(0.045, 0.04, 0.14), Vector3.ZERO, wood)
			var mag: Node3D = _node(root, "Mag", Vector3(0, -0.04, 0.0))
			_box(mag, "ShellHand", Vector3(0.018, 0.018, 0.05), Vector3(0, -0.02, 0), _mat(Color(0.7, 0.1, 0.1)))
			_box(
				root, "Rib", Vector3(0.012, h - 0.036, 0.46), Vector3(0, 0.036 + (h - 0.036) * 0.5 - 0.006, -0.3), dark
			)
			_post(root, "FrontPost", Vector2(0.004, 0.004), h - 0.008, h - 0.002, front, dark)
		&"rifle":  # assault rifles: iron sights, curved/box magazine, wood or polymer furniture
			front = -0.42
			_box(root, "Receiver", Vector3(0.05, 0.065, 0.34), Vector3(0, 0, -0.08), body)
			_cyl(root, "Barrel", 0.012, 0.32, Vector3(0, 0.012, -0.4), dark)
			_box(root, "Handguard", Vector3(0.05, 0.05, 0.2), Vector3(0, 0.0, -0.3), wood)
			_box(root, "Grip", Vector3(0.035, 0.1, 0.045), Vector3(0, -0.075, 0.04), dark, deg_to_rad(15))
			_box(root, "Stock", Vector3(0.04, 0.07, 0.26), Vector3(0, -0.02, 0.2), wood)
			var mag: Node3D = _node(root, "Mag", Vector3(0, -0.04, -0.12))
			_box(mag, "MagBox", Vector3(0.03, 0.16, 0.05), Vector3(0, -0.07, 0), dark, deg_to_rad(-12))
			var act: Node3D = _node(root, "Action", Vector3(0.03, 0.02, -0.03))
			_box(act, "Charger", Vector3(0.02, 0.012, 0.04), Vector3.ZERO, dark)
			_post(root, "RearSight", Vector2(0.03, 0.01), 0.033, h - 0.006, 0.04, dark)
			_post(root, "FrontPost", Vector2(0.004, 0.004), 0.03, h - 0.002, front, dark)
		&"lmg":  # belt-fed machine guns: big box receiver, bipod, ammo box
			front = -0.5
			_box(root, "Receiver", Vector3(0.07, 0.08, 0.4), Vector3(0, 0, -0.08), body)
			_cyl(root, "Barrel", 0.016, 0.42, Vector3(0, 0.01, -0.48), dark)
			_box(root, "Shroud", Vector3(0.045, 0.045, 0.24), Vector3(0, 0.01, -0.36), dark)
			_box(root, "Grip", Vector3(0.035, 0.1, 0.045), Vector3(0, -0.08, 0.04), dark, deg_to_rad(15))
			_box(root, "Stock", Vector3(0.045, 0.08, 0.26), Vector3(0, -0.02, 0.24), wood)
			_box(root, "Bipod", Vector3(0.08, 0.01, 0.01), Vector3(0, -0.03, -0.55), dark)
			var mag: Node3D = _node(root, "Mag", Vector3(-0.02, -0.06, -0.08))
			_box(mag, "AmmoBox", Vector3(0.09, 0.1, 0.12), Vector3(-0.03, -0.04, 0), _mat(Color(0.25, 0.3, 0.2)))
			var act: Node3D = _node(root, "Action", Vector3(0, 0.05, -0.05))
			_box(act, "FeedCover", Vector3(0.068, 0.012, 0.18), Vector3.ZERO, body)
			_post(root, "RearSight", Vector2(0.03, 0.01), 0.056, h - 0.006, 0.02, dark)
			_post(root, "FrontPost", Vector2(0.004, 0.004), 0.03, h - 0.002, front, dark)
		&"launcher":  # tubes / grenade launchers: big bore, pop-up leaf sight
			front = -0.45
			_cyl(root, "Tube", 0.042, 0.8, Vector3(0, 0.0, -0.15), body)
			_box(root, "Grip", Vector3(0.035, 0.1, 0.045), Vector3(0, -0.08, 0.02), dark, deg_to_rad(10))
			var mag: Node3D = _node(root, "Mag", Vector3(0, -0.05, 0.2))
			_box(mag, "Round", Vector3(0.05, 0.05, 0.08), Vector3(0, -0.02, 0), _mat(Color(0.35, 0.38, 0.25)))
			var act: Node3D = _node(root, "Action", Vector3(0, -0.04, -0.3))
			_box(act, "Pump", Vector3(0.05, 0.035, 0.12), Vector3.ZERO, dark)
			_post(root, "RearSight", Vector2(0.03, 0.01), 0.04, h - 0.006, 0.05, dark)
			_post(root, "FrontPost", Vector2(0.004, 0.004), 0.04, h - 0.002, front, dark)
		&"crossbow":
			front = -0.4
			_box(root, "Stock", Vector3(0.045, 0.06, 0.6), Vector3(0, -0.01, -0.05), wood)
			_box(root, "Limbs", Vector3(0.5, 0.025, 0.04), Vector3(0, 0.0, -0.36), dark)
			_box(root, "Grip", Vector3(0.035, 0.1, 0.045), Vector3(0, -0.08, 0.06), dark, deg_to_rad(15))
			var mag: Node3D = _node(root, "Mag", Vector3(0, 0.03, -0.2))
			_box(mag, "Bolt", Vector3(0.012, 0.012, 0.38), Vector3.ZERO, _mat(Color(0.75, 0.2, 0.12)))
			var act: Node3D = _node(root, "Action", Vector3(0, 0.035, 0.05))
			_box(act, "String", Vector3(0.46, 0.004, 0.004), Vector3.ZERO, _mat(Color(0.8, 0.8, 0.75)))
			_post(root, "RearSight", Vector2(0.03, 0.01), 0.03, h - 0.006, 0.12, dark)
			_post(root, "FrontPost", Vector2(0.004, 0.004), 0.03, h - 0.002, front, dark)
		&"rifle_scoped":
			front = -0.32
			_box(root, "Receiver", Vector3(0.045, 0.055, 0.3), Vector3(0, 0, -0.05), body)
			_cyl(root, "Barrel", 0.012, 0.55, Vector3(0, 0.005, -0.45), dark)
			_box(root, "Stock", Vector3(0.045, 0.08, 0.62), Vector3(0, -0.035, -0.05), wood)
			var mag: Node3D = _node(root, "Mag", Vector3(0, -0.05, -0.05))
			_box(mag, "Clip", Vector3(0.02, 0.03, 0.05), Vector3(0, 0.08, 0), dark)
			var bolt: Node3D = _node(root, "Action", Vector3(0.035, 0.02, 0.06))
			_box(bolt, "BoltHandle", Vector3(0.05, 0.012, 0.012), Vector3(0.02, 0, 0), dark)
			_scope(root, h, dark, sight_mat)
		_:  # pistol
			front = -0.14
			_box(root, "Frame", Vector3(0.035, 0.035, 0.18), Vector3(0, 0, -0.06), body)
			_box(root, "Grip", Vector3(0.032, 0.11, 0.05), Vector3(0, -0.07, 0.01), dark, deg_to_rad(12))
			var mag: Node3D = _node(root, "Mag", Vector3(0, -0.07, 0.01))
			_box(mag, "MagBase", Vector3(0.03, 0.02, 0.045), Vector3(0, -0.055, 0), dark)
			var slide: Node3D = _node(root, "Action", Vector3(0, 0.03, -0.06))
			_box(slide, "Slide", Vector3(0.033, 0.03, 0.19), Vector3.ZERO, body)
			_post(root, "RearSight", Vector2(0.025, 0.008), 0.045, h - 0.006, 0.025, dark)
			_post(root, "FrontPost", Vector2(0.004, 0.004), 0.045, h - 0.002, front, dark)
	if def.viewmodel_style != &"rifle_scoped":
		var dot: MeshInstance3D = _box(
			root, "SightDot", Vector3(0.0035, 0.0035, 0.0035), Vector3(0, h, front), sight_mat
		)
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker(root, "Sight", Vector3(0, h, front if def.viewmodel_style != &"rifle_scoped" else -0.2))
	_marker(root, "Muzzle", Vector3(0, 0.01, _muzzle_z(def)))
	_marker(root, "Eject", Vector3(0.03, 0.03, -0.05))
	set_layers(root, layer)
	return root


static func sight_point(gun: Node3D) -> Vector3:
	var m: Node3D = gun.get_node_or_null(^"Sight") as Node3D
	return m.position if m != null else Vector3.ZERO


static func _muzzle_z(def: WeaponDefinition) -> float:
	match def.viewmodel_style:
		&"smg":
			return -0.45
		&"shotgun":
			return -0.59
		&"rifle_scoped":
			return -0.73
		&"rifle":
			return -0.56
		&"lmg":
			return -0.69
		&"launcher":
			return -0.55
		&"crossbow":
			return -0.42
	return -0.16


static func _scope(root: Node3D, h: float, dark: StandardMaterial3D, sight_mat: StandardMaterial3D) -> void:
	# Tube along the sight line with the reticle (crosshair + centre dot) at its front end.
	var mounts: Array[float] = [0.0, -0.18]
	for z: float in mounts:
		_box(root, "Mount", Vector3(0.012, h - 0.04, 0.015), Vector3(0, 0.03 + (h - 0.04) * 0.5, z), dark)
	var tube: MeshInstance3D = MeshInstance3D.new()
	tube.name = "ScopeTube"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 0.22
	cm.cap_top = false
	cm.cap_bottom = false
	tube.mesh = cm
	var tube_mat: StandardMaterial3D = dark.duplicate() as StandardMaterial3D
	tube_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tube.material_override = tube_mat
	tube.position = Vector3(0, h, -0.1)
	tube.rotation.x = PI * 0.5
	root.add_child(tube)
	var reticle_mat: StandardMaterial3D = _mat(Color(0.02, 0.02, 0.02))
	reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(root, "ReticleH", Vector3(0.036, 0.0008, 0.0005), Vector3(0, h, -0.2), reticle_mat)
	_box(root, "ReticleV", Vector3(0.0008, 0.036, 0.0005), Vector3(0, h, -0.2), reticle_mat)
	var dot: MeshInstance3D = _box(root, "SightDot", Vector3(0.0016, 0.0016, 0.0005), Vector3(0, h, -0.199), sight_mat)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Vertical sight post from `base` to `top` (sights stay below the sight line so they never cover
# the sight dot in ADS).
static func _post(
	parent: Node3D, n: String, footprint: Vector2, base: float, top: float, z: float, mat: Material
) -> void:
	_box(parent, n, Vector3(footprint.x, top - base, footprint.y), Vector3(0, (base + top) * 0.5, z), mat)


static func _node(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = n
	node.position = pos
	parent.add_child(node)
	return node


static func _marker(parent: Node3D, n: String, pos: Vector3) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = n
	m.position = pos
	parent.add_child(m)
	return m


static func _box(
	parent: Node3D, n: String, size: Vector3, pos: Vector3, mat: Material, rot_x: float = 0.0
) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = rot_x
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, n: String, radius: float, length: float, pos: Vector3, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = PI * 0.5
	parent.add_child(mi)


static func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	m.metallic = 0.0  # the viewmodel viewport has no sky to reflect: metallic greybox renders black
	return m


static func set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for c: Node in node.get_children():
		set_layers(c, layer)
