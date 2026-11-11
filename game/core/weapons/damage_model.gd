# DamageModel — pure damage formulas (GAME_DESIGN §4.2): distance falloff, hitzone multipliers
# and penetration loss. Used by the shooter (prediction, hit markers) and by the host
# (HitValidator recomputes every claim from the definition, never trusting client numbers).
# Authority: pure functions, identical on every peer.
class_name DamageModel
extends RefCounted


# Multiplier from range: 1.0 up to range_min, linear down to min_damage_fraction at range_max.
static func falloff(def: WeaponDefinition, distance: float) -> float:
	if distance <= def.range_min:
		return 1.0
	if distance >= def.range_max or def.range_max <= def.range_min:
		return def.min_damage_fraction
	var t: float = (distance - def.range_min) / (def.range_max - def.range_min)
	return lerpf(1.0, def.min_damage_fraction, t)


# Damage multiplier for the n-th target a bullet reaches (0 = first): loses `penetration_loss`
# per target passed through (25% default, multiplicative).
static func penetration_factor(def: WeaponDefinition, target_index: int) -> float:
	return pow(1.0 - def.penetration_loss, target_index)


# Damage one bullet/pellet deals to a target.
static func bullet_damage(def: WeaponDefinition, distance: float, zone: int, target_index: int) -> float:
	if target_index >= maxi(def.penetration, 1):
		return 0.0
	return def.damage * falloff(def, distance) * def.zone_multiplier(zone) * penetration_factor(def, target_index)


# Melee: flat damage, headshots don't multiply (GAME_DESIGN §3.4).
static func melee_damage(def: WeaponDefinition) -> float:
	return def.damage


# Explosive splash: `centre` damage at the centre falling linearly to `edge` at radius r.
static func splash_damage(centre: float, edge: float, radius: float, distance: float) -> float:
	if distance > radius:
		return 0.0
	return lerpf(centre, edge, clampf(distance / maxf(radius, 0.001), 0.0, 1.0))
