# GibModifier — a SkeletonModifier3D that collapses gibbed bones (head, forearms, shins) to
# near-zero scale after animation, so the skinned mesh loses that part (children inherit).
# Pooled gib chunks (ZombieFx) fly from the stump. Authority: local presentation.
class_name GibModifier
extends SkeletonModifier3D

const COLLAPSED: Vector3 = Vector3(0.001, 0.001, 0.001)

var hidden_bones: PackedInt32Array = []


func hide_bone(bone: int) -> void:
	if bone >= 0 and not hidden_bones.has(bone):
		hidden_bones.append(bone)


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	for b: int in hidden_bones:
		sk.set_bone_pose_scale(b, COLLAPSED)
