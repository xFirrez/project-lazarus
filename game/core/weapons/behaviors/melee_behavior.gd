# MeleeBehavior — knife (and later Ice Axe): finds the closest living HitTarget inside a cone in
# front of the player within reach + lunge distance and with a clear line of sight. Damage is flat
# (headshots don't multiply, GAME_DESIGN §3.4). The result's first hit's `distance` tells the
# controller how far to lunge.
# Authority: shooter (claims) — the host re-checks range in HitValidator.
class_name MeleeBehavior
extends WeaponBehavior


func fire(ctx: ShotContext) -> Ballistics.ShotResult:
	var result: Ballistics.ShotResult = Ballistics.ShotResult.new()
	result.origin = ctx.origin
	var def: WeaponDefinition = ctx.def
	var reach: float = def.melee_reach + def.melee_lunge
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = reach
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, ctx.origin)
	q.collision_mask = Hurtbox.LAYER
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var best: Hurtbox = null
	var best_dist: float = INF
	var cos_cone: float = cos(deg_to_rad(def.melee_cone_deg))
	for hit: Dictionary in ctx.space.intersect_shape(q, 32):
		var hb: Hurtbox = hit["collider"] as Hurtbox
		if hb == null or hb.target == null or not hb.target.alive:
			continue
		var to: Vector3 = hb.global_position - ctx.origin
		var d: float = to.length()
		if d > reach or d < 0.001 or to.normalized().dot(ctx.forward.normalized()) < cos_cone:
			continue
		var los: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			ctx.origin, hb.global_position, Ballistics.WORLD_MASK
		)
		los.exclude = ctx.exclude
		if not ctx.space.intersect_ray(los).is_empty():
			continue
		# Prefer torso over limbs at similar distance: score = distance, torso bonus.
		var score: float = d - (0.15 if hb.zone == WeaponDefinition.Hitzone.TORSO else 0.0)
		if score < best_dist:
			best_dist = score
			best = hb
	if best != null:
		var rec: Ballistics.HitRecord = Ballistics.HitRecord.new()
		rec.target = best.target
		rec.zone = best.zone
		rec.distance = ctx.origin.distance_to(best.global_position)
		rec.position = best.global_position
		rec.normal = -ctx.forward
		result.hits.append(rec)
		var imp: Ballistics.Impact = Ballistics.Impact.new()
		imp.position = best.global_position
		imp.normal = -ctx.forward
		imp.surface = &"flesh"
		imp.flesh = true
		result.impacts.append(imp)
	return result
