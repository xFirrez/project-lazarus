# WeaponCamo — applies a weapon's camo (WeaponDefinition.camo) to a built gun model: the Forge's
# animated vesperite pattern (content/shaders/vesperite_camo.gdshader) as a material overlay on
# every mesh (MeshInstance3D only: not labels / particles), so greybox and authored models both take
# it without UVs (GAME_DESIGN §9.2).
# Sight dots keep their colour (the ADS alignment test looks for them).
# Authority: local presentation.
class_name WeaponCamo
extends RefCounted

const VESPERITE_SHADER: String = "res://content/shaders/vesperite_camo.gdshader"

static var _material: ShaderMaterial = null


static func material(camo: StringName) -> Material:
	if camo != &"vesperite":
		return null
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(VESPERITE_SHADER) as Shader
	return _material


static func apply(root: Node, def: WeaponDefinition) -> void:
	var m: Material = material(def.camo) if def != null else null
	if root == null or m == null:
		return
	var geoms: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		geoms.append(root)
	for n: Node in geoms:
		if String(n.name).begins_with("SightDot") or String(n.name).begins_with("Reticle"):
			continue
		var g: MeshInstance3D = n as MeshInstance3D
		g.material_overlay = m
		# Drop the overlay before the mesh is freed: at shutdown imported (GLB) surface materials can
		# go first, and the renderer would re-read them for the overlay's instance parameters.
		if not g.tree_exiting.is_connected(_clear.bind(g)):
			g.tree_exiting.connect(_clear.bind(g))


static func _clear(g: MeshInstance3D) -> void:
	if is_instance_valid(g):
		g.material_overlay = null
