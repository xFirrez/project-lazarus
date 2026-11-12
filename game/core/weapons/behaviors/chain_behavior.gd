# ChainBehavior — the Lazarus Conduit (behavior &"chain") and its pulse (behavior &"pulse"): like a
# projectile weapon, a trigger pull makes no local hit claims. The shot claim reaches the host,
# which selects and damages the chain with ChainLightning (or stuns everything within the pulse
# radius) and broadcasts the arcs through WonderFx (`_wfx`) to every peer, the shooter included.
# Authority: host decides; the shooter only presents the muzzle / sound.
class_name ChainBehavior
extends WeaponBehavior


func fire(ctx: ShotContext) -> Ballistics.ShotResult:
	var result: Ballistics.ShotResult = Ballistics.ShotResult.new()
	result.origin = ctx.origin
	return result
