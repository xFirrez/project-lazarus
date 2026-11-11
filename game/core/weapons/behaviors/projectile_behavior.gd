# ProjectileBehavior — STUB interface (Step 3). Launchers, the crossbow and the Ray Pistol spawn
# host-authoritative projectiles with a predicted local visual; the full version is Step 9
# (DEVELOPMENT_PLAN). Until then firing a projectile weapon produces no hits and logs once.
# Authority: host spawns projectiles; the shooter shows a predicted visual.
class_name ProjectileBehavior
extends WeaponBehavior

static var _warned: bool = false


func fire(ctx: ShotContext) -> Ballistics.ShotResult:
	if not _warned:
		_warned = true
		Log.warn(&"weapons", "ProjectileBehavior is a stub until Step 9 (%s)" % ctx.def.id)
	var result: Ballistics.ShotResult = Ballistics.ShotResult.new()
	result.origin = ctx.origin
	return result


# Step 9: initial velocity for a projectile fired along `dir`.
func launch_velocity(def: WeaponDefinition, dir: Vector3) -> Vector3:
	return dir.normalized() * def.throw_speed
