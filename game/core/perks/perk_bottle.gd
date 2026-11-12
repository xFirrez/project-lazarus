# PerkBottle — a Vigor Tonic bottle built from primitives in the perk's colours (glass body, label
# band, crown cap with the perk letter): used by the machines' bottle window / vending tray and the
# first-person drink (render layer 2 there, Viewmodel.LAYER).
# Authority: local presentation.
class_name PerkBottle
extends RefCounted


static func build(def: PerkDefinition, layer: int = 1) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PerkBottle"
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(def.color.r * 0.55, def.color.g * 0.55, def.color.b * 0.55, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	glass.emission_enabled = true
	glass.emission = def.color * 0.25
	var label: StandardMaterial3D = StandardMaterial3D.new()
	label.albedo_color = def.accent.lightened(0.35)
	label.roughness = 0.8
	var cap: StandardMaterial3D = StandardMaterial3D.new()
	cap.albedo_color = def.color
	cap.metallic = 0.8
	cap.roughness = 0.3
	_cyl(root, Vector3(0, 0.07, 0), 0.032, 0.032, 0.14, glass, layer)  # body
	_cyl(root, Vector3(0, 0.07, 0), 0.0335, 0.0335, 0.055, label, layer)  # label band
	_cyl(root, Vector3(0, 0.165, 0), 0.012, 0.03, 0.05, glass, layer)  # shoulder + neck
	_cyl(root, Vector3(0, 0.197, 0), 0.015, 0.015, 0.014, cap, layer)  # crown cap
	return root


static func _cyl(
	root: Node3D, pos: Vector3, top: float, bottom: float, height: float, mat: Material, layer: int
) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	mi.layers = layer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
