# ZombieModel — the visual body of a zombie: an imported, retargeted humanoid model scene plus a
# shared AnimationLibrary (in-place clips), a skin material variant and bone-attached hitboxes
# from a HitboxProfile. Step 5's ZombieVisual drives it (locomotion blend, reacts, ragdoll).
# Authority: local presentation on every peer; hurtboxes report to `target` (host applies damage).
class_name ZombieModel
extends Node3D

const LIBRARY: StringName = &"zombie"

@export var model_scene: PackedScene = null
@export var animations: AnimationLibrary = null
@export var hitboxes: HitboxProfile = null
@export var skin_material: Material = null  # replaces every "zombie_skin*" surface
@export var autoplay: StringName = &"idle"

var model: Node3D = null
var skeleton: Skeleton3D = null
var anim: AnimationPlayer = null
var hurtboxes: Array[Hurtbox] = []
var target: HitTarget = null


func _ready() -> void:
	if model_scene == null:
		Log.error(&"enemies", "ZombieModel %s has no model scene" % name)
		return
	model = model_scene.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	skeleton = model.get_node_or_null(^"%GeneralSkeleton") as Skeleton3D
	if skeleton == null:
		skeleton = _find_skeleton(model)
	_apply_skin()
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	anim.root_node = anim.get_path_to(model)
	if animations != null:
		anim.add_animation_library(LIBRARY, animations)
	var p: Node = get_parent()
	while p != null and target == null:
		target = p as HitTarget
		p = p.get_parent()
	_build_hitboxes()
	if autoplay != &"" and has_clip(autoplay):
		play(autoplay)


func has_clip(clip: StringName) -> bool:
	return anim != null and anim.has_animation(_full(clip))


func clips() -> PackedStringArray:
	var out: PackedStringArray = []
	if animations != null:
		for n: StringName in animations.get_animation_list():
			out.append(String(n))
	return out


func play(clip: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	if has_clip(clip):
		anim.play(_full(clip), blend, speed)


func hurtbox_for_bone(bone: StringName) -> Hurtbox:
	for hb: Hurtbox in hurtboxes:
		if (hb.get_parent() as BoneAttachment3D).bone_name == bone:
			return hb
	return null


func triangle_count() -> int:
	var tris: int = 0
	for mi: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s: int in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func _full(clip: StringName) -> StringName:
	return StringName("%s/%s" % [LIBRARY, clip])


func _apply_skin() -> void:
	if skin_material == null:
		return
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m != null and m.resource_name.begins_with("zombie_skin"):
				mi.set_surface_override_material(s, skin_material)


func _build_hitboxes() -> void:
	if hitboxes == null or skeleton == null:
		return
	for e: HitboxDef in hitboxes.entries:
		if skeleton.find_bone(e.bone) < 0:
			Log.warn(&"enemies", "Hitbox bone %s missing on %s" % [e.bone, name])
			continue
		var att: BoneAttachment3D = BoneAttachment3D.new()
		att.name = "Hit_%s" % e.bone
		att.bone_name = e.bone
		skeleton.add_child(att)
		var hb: Hurtbox = Hurtbox.create(target, e.zone, hitboxes.shape_for(e), e.offset)
		att.add_child(hb)
		hurtboxes.append(hb)
		if target != null:
			target.hurtboxes.append(hb)


static func _find_skeleton(root: Node) -> Skeleton3D:
	for n: Node in root.find_children("*", "Skeleton3D", true, false):
		return n as Skeleton3D
	return null
