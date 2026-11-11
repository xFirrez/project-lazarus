# SurfaceTags — resolves a collider to a surface tag (concrete, metal, wood, snow, gravel, tile).
# A collider's `surface` metadata wins; otherwise its PhysicsMaterial's resource_name is the tag
# ("physics-material tags"). Used by footsteps now and by bullet impacts in Step 3.
# Authority: local, pure lookup.
class_name SurfaceTags
extends RefCounted

const DEFAULT: StringName = &"concrete"
const KNOWN: Array[StringName] = [&"concrete", &"metal", &"wood", &"snow", &"gravel", &"tile"]


static func of(collider: Object) -> StringName:
	if collider == null:
		return DEFAULT
	if collider is Node and (collider as Node).has_meta(&"surface"):
		return StringName((collider as Node).get_meta(&"surface"))
	var body: StaticBody3D = collider as StaticBody3D
	if body != null and body.physics_material_override != null:
		var tag: String = body.physics_material_override.resource_name
		if tag != "":
			return StringName(tag)
	var anim: AnimatableBody3D = collider as AnimatableBody3D
	if anim != null and anim.physics_material_override != null and anim.physics_material_override.resource_name != "":
		return StringName(anim.physics_material_override.resource_name)
	return DEFAULT


static func make_material(tag: StringName, friction: float = 1.0) -> PhysicsMaterial:
	var m: PhysicsMaterial = PhysicsMaterial.new()
	m.resource_name = String(tag)
	m.friction = friction
	return m
