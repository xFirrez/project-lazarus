# HitscanBehavior — one instant bullet per shot inside the current spread cone, penetrating up to
# `def.penetration` targets (−25% each) and thin wood/metal props (GAME_DESIGN §4.2).
# Authority: shooter (claims) / observers (cosmetic replay with the same seed).
class_name HitscanBehavior
extends WeaponBehavior


func fire(ctx: ShotContext) -> Ballistics.ShotResult:
	var result: Ballistics.ShotResult = Ballistics.ShotResult.new()
	result.origin = ctx.origin
	var rng: RandomNumberGenerator = Ballistics.make_rng(ctx.seed)
	var dir: Vector3 = Ballistics.spread_direction(ctx.forward, ctx.spread_deg, rng)
	Ballistics.trace_bullet(ctx.space, ctx.def, ctx.origin, dir, ctx.exclude, result)
	return result
