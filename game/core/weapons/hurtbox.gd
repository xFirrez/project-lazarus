# Hurtbox — an Area3D on the hitbox physics layer (layer 3) that maps a bullet hit to a hitzone
# (head / neck / torso / limb) of its HitTarget. Zombies (Step 5) and dummies are built from these.
# Authority: passive collision data on every peer; damage itself is host-side (HitTarget).
class_name Hurtbox
extends Area3D

const LAYER: int = 1 << 2  # 3d_physics/layer_3 "zombie_hitbox"

var zone: int = WeaponDefinition.Hitzone.TORSO
var target: HitTarget = null


static func create(p_target: HitTarget, p_zone: int, shape: Shape3D, local_pos: Vector3) -> Hurtbox:
	var hb: Hurtbox = Hurtbox.new()
	hb.target = p_target
	hb.zone = p_zone
	hb.name = "Hurtbox_%s" % WeaponDefinition.Hitzone.keys()[p_zone]
	hb.position = local_pos
	hb.collision_layer = LAYER
	hb.collision_mask = 0
	hb.monitoring = false
	hb.monitorable = true
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	hb.add_child(cs)
	return hb
