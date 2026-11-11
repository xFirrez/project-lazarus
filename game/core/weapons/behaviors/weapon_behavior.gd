# WeaponBehavior — strategy interface for how a weapon turns a trigger pull into hits
# (ARCHITECTURE §6.2). New behaviors (wonder weapons, future maps) subclass this and are named by
# WeaponDefinition.behavior or supplied as WeaponDefinition.behavior_script.
# `fire` must be deterministic for a given ShotContext.seed so other peers can replay visuals.
# Authority: runs on the shooting peer (hit claims) and on observers (cosmetic replay).
class_name WeaponBehavior
extends RefCounted


class ShotContext:
	extends RefCounted
	var space: PhysicsDirectSpaceState3D = null
	var def: WeaponDefinition = null
	var origin: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD
	var spread_deg: float = 0.0
	var seed: int = 0
	var exclude: Array[RID] = []


static func for_definition(def: WeaponDefinition) -> WeaponBehavior:
	if def.behavior_script != null:
		return def.behavior_script.new() as WeaponBehavior
	match def.behavior:
		&"pellet":
			return PelletBehavior.new()
		&"melee":
			return MeleeBehavior.new()
		&"projectile":
			return ProjectileBehavior.new()
	return HitscanBehavior.new()


func fire(_ctx: ShotContext) -> Ballistics.ShotResult:
	return Ballistics.ShotResult.new()
