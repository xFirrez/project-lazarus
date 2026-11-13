# HitboxProfile — the bone -> hitzone mapping of a humanoid model (ARCHITECTURE §7.1): every
# entry becomes a BoneAttachment3D + Hurtbox on the model's skeleton, so hitboxes follow the
# animated pose on every peer. Bone names are SkeletonProfileHumanoid names (retargeted models).
# Authority: shared data.
class_name HitboxProfile
extends Resource

@export var entries: Array[HitboxDef] = []


func shape_for(e: HitboxDef) -> Shape3D:
	if e.height <= e.radius * 2.0:
		var sph: SphereShape3D = SphereShape3D.new()
		sph.radius = e.radius
		return sph
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = e.radius
	cap.height = e.height
	return cap
