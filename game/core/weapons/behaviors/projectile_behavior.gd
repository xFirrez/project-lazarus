# ProjectileBehavior — launchers, the crossbow (and later the Ray Pistol): a trigger pull produces
# no instant hits; it launches a Projectile (core/weapons/projectile.gd). The shooter spawns a
# predicted local copy through WeaponSync.submit_shot; the host spawns the authoritative one when
# it accepts the shot claim and relays `_wproj` so observers fly the same projectile.
# Authority: host spawns authoritative projectiles; the shooter / observers show cosmetic copies.
class_name ProjectileBehavior
extends WeaponBehavior

const MUZZLE_OFFSET: float = 0.5


func fire(ctx: ShotContext) -> Ballistics.ShotResult:
	var result: Ballistics.ShotResult = Ballistics.ShotResult.new()
	result.origin = ctx.origin
	return result


# Launch point and velocity for a projectile fired from `origin` along `dir` (deterministic: the
# host and every peer derive the same flight from the same claim).
static func launch_origin(origin: Vector3, dir: Vector3) -> Vector3:
	return origin + dir.normalized() * MUZZLE_OFFSET


static func launch_velocity(def: WeaponDefinition, dir: Vector3) -> Vector3:
	var v: Vector3 = dir.normalized() * def.projectile_speed
	if def.projectile_kind == &"grenade":
		v += Vector3.UP * 1.5  # launcher lob
	return v
