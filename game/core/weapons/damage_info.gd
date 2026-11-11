# DamageInfo — one application of damage to a HitTarget (bullet, pellet, melee, explosive).
# Built by the host after a claim passed HitValidator (and locally by the shooter for prediction).
# Authority: plain data.
class_name DamageInfo
extends RefCounted

enum Kind { BULLET, MELEE, EXPLOSIVE, DEBUG }

var amount: float = 0.0
var zone: int = WeaponDefinition.Hitzone.TORSO
var kind: Kind = Kind.BULLET
var weapon_id: StringName = &""
var source_peer: int = 0
var position: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.FORWARD
var distance: float = 0.0
var target_index: int = 0


static func make(p_amount: float, p_zone: int, p_kind: Kind, p_weapon: StringName, p_peer: int) -> DamageInfo:
	var d: DamageInfo = DamageInfo.new()
	d.amount = p_amount
	d.zone = p_zone
	d.kind = p_kind
	d.weapon_id = p_weapon
	d.source_peer = p_peer
	return d
