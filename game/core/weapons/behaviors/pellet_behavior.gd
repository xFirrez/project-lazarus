# PelletBehavior — shotguns: `def.pellets` hitscan pellets spread by `pellet_spread_deg` around an
# aim direction that itself uses the weapon's hip/ADS cone. Each pellet penetrates
# `def.penetration` targets (1 for shotguns) and carries its own damage.
# Authority: shooter (claims) / observers (cosmetic replay with the same seed).
class_name PelletBehavior
extends WeaponBehavior


func fire(ctx: ShotContext) -> Ballistics.ShotResult:
	var result: Ballistics.ShotResult = Ballistics.ShotResult.new()
	result.origin = ctx.origin
	var rng: RandomNumberGenerator = Ballistics.make_rng(ctx.seed)
	var aim: Vector3 = Ballistics.spread_direction(ctx.forward, ctx.spread_deg, rng)
	for i: int in maxi(ctx.def.pellets, 1):
		var dir: Vector3 = Ballistics.spread_direction(aim, ctx.def.pellet_spread_deg, rng)
		Ballistics.trace_bullet(ctx.space, ctx.def, ctx.origin, dir, ctx.exclude, result, i)
	return result
