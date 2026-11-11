# HitboxDef — one bone-attached hitbox: a capsule (or sphere when height <= 2 * radius) on
# `bone`, placed `along` (0..1) the bone's length plus `offset`, mapped to a weapon hitzone.
# Authority: shared data.
class_name HitboxDef
extends Resource

@export var bone: StringName = &""
@export var zone: WeaponDefinition.Hitzone = WeaponDefinition.Hitzone.TORSO
@export var radius: float = 0.1
@export var height: float = 0.3
@export var offset: Vector3 = Vector3(0, 0.15, 0)  # in bone space (+Y runs along the bone)
