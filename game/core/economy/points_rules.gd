# PointsRules — earning and penalty numbers of GAME_DESIGN §6.1 / §3.3 as pure functions, shared
# by the PointsLedger (host) and unit tests.
# Authority: read-only rules.
class_name PointsRules
extends RefCounted

const HIT: int = 10
const KILL_BODY: int = 60
const KILL_NECK: int = 70
const KILL_HEAD: int = 100
const KILL_MELEE: int = 130
const KILL_EXPLOSIVE: int = 50
const REPAIR_PLANK: int = 10
const REPAIR_CAP_PER_ROUND: int = 500
const DOWN_PENALTY: float = 0.05
const BLEEDOUT_PENALTY: float = 0.10


# Points for a damaging event on a zombie (kind = DamageInfo.Kind, zone = WeaponDefinition.Hitzone).
static func for_damage(kind: int, zone: int, killed: bool) -> int:
	if kind == DamageInfo.Kind.DEBUG:
		return 0
	if not killed:
		return HIT if kind == DamageInfo.Kind.BULLET or kind == DamageInfo.Kind.MELEE else 0
	match kind:
		DamageInfo.Kind.MELEE:
			return KILL_MELEE
		DamageInfo.Kind.EXPLOSIVE:
			return KILL_EXPLOSIVE
	match zone:
		WeaponDefinition.Hitzone.HEAD:
			return KILL_HEAD
		WeaponDefinition.Hitzone.NECK:
			return KILL_NECK
	return KILL_BODY


# Points lost when downed / bled out: a fraction, rounded down to a multiple of 10.
static func penalty(points: int, fraction: float) -> int:
	return int(floor(points * fraction / 10.0)) * 10


# Repair points still allowed this round given what was already earned from repairs.
static func repair_points(earned_this_round: int) -> int:
	return clampi(REPAIR_CAP_PER_ROUND - earned_this_round, 0, REPAIR_PLANK)
