# Ballistics — shared shot geometry: seeded spread directions (so other peers can replay a shot's
# tracers and impacts from just a seed) and the shot / hit records behaviors return.
# Authority: pure, deterministic for a given seed.
class_name Ballistics
extends RefCounted

const WORLD_MASK: int = 1  # layer 1 "world"
const THIN_SURFACES: Array[StringName] = [&"wood", &"metal"]
const PROP_PENETRATION_FACTOR: float = 0.75
const MAX_PROPS: int = 2


class HitRecord:
	extends RefCounted
	var target: HitTarget = null
	var zone: int = WeaponDefinition.Hitzone.TORSO
	var distance: float = 0.0
	var target_index: int = 0
	var props_passed: int = 0
	var position: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.UP
	var pellet: int = 0


class Impact:
	extends RefCounted
	var position: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.UP
	var surface: StringName = &"concrete"
	var flesh: bool = false


class ShotResult:
	extends RefCounted
	var origin: Vector3 = Vector3.ZERO
	var hits: Array[HitRecord] = []
	var impacts: Array[Impact] = []
	var tracer_ends: PackedVector3Array = []  # one end point per bullet / pellet


static func make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func shot_seed(peer_id: int, shot_seq: int) -> int:
	return hash([peer_id, shot_seq]) & 0x7FFFFFFF


# Uniform direction inside a cone of half-angle `cone_deg` around `forward`.
static func spread_direction(forward: Vector3, cone_deg: float, rng: RandomNumberGenerator) -> Vector3:
	var u: float = rng.randf()
	var v: float = rng.randf()
	if cone_deg <= 0.0001:
		return forward.normalized()
	var r: float = sqrt(u) * tan(deg_to_rad(cone_deg))
	var theta: float = TAU * v
	var basis: Basis = Basis.looking_at(forward.normalized(), Vector3.UP if absf(forward.y) < 0.99 else Vector3.BACK)
	var local: Vector3 = Vector3(cos(theta) * r, sin(theta) * r, -1.0)
	return (basis * local).normalized()


static func is_thin_prop(collider: Object) -> bool:
	if not (collider is Node) or not (collider as Node).has_meta(&"thin_prop"):
		return false
	return THIN_SURFACES.has(SurfaceTags.of(collider))


# One bullet: walks the ray through hurtboxes (penetrating up to def.penetration targets) and thin
# props, recording hits and world impacts. `exclude` holds the shooter's own RIDs.
static func trace_bullet(
	space: PhysicsDirectSpaceState3D,
	def: WeaponDefinition,
	origin: Vector3,
	dir: Vector3,
	exclude: Array[RID],
	result: ShotResult,
	pellet: int = 0
) -> void:
	var end: Vector3 = origin + dir * def.max_range
	var excl: Array[RID] = exclude.duplicate()
	var hit_targets: Array[HitTarget] = []
	var props: int = 0
	var from: Vector3 = origin
	var tracer_end: Vector3 = end
	for _guard: int in 24:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, end, WORLD_MASK | Hurtbox.LAYER)
		q.collide_with_areas = true
		q.collide_with_bodies = true
		q.exclude = excl
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			break
		var collider: Object = hit["collider"]
		var pos: Vector3 = hit["position"]
		var hb: Hurtbox = collider as Hurtbox
		if hb != null:
			if hb.target == null or hit_targets.has(hb.target) or not hb.target.alive:
				excl.append(hit["rid"])
				continue
			var rec: HitRecord = HitRecord.new()
			rec.target = hb.target
			rec.zone = hb.zone
			rec.distance = origin.distance_to(pos)
			rec.target_index = hit_targets.size()
			rec.props_passed = props
			rec.position = pos
			rec.normal = hit["normal"]
			rec.pellet = pellet
			result.hits.append(rec)
			hit_targets.append(hb.target)
			excl.append_array(hb.target.hurtbox_rids())
			var flesh: Impact = Impact.new()
			flesh.position = pos
			flesh.normal = hit["normal"]
			flesh.surface = &"flesh"
			flesh.flesh = true
			result.impacts.append(flesh)
			if hit_targets.size() >= maxi(def.penetration, 1):
				tracer_end = pos
				break
			continue
		var imp: Impact = Impact.new()
		imp.position = pos
		imp.normal = hit["normal"]
		imp.surface = SurfaceTags.of(collider)
		result.impacts.append(imp)
		if is_thin_prop(collider) and props < MAX_PROPS:
			props += 1
			excl.append(hit["rid"])
			from = pos
			continue
		tracer_end = pos
		break
	result.tracer_ends.append(tracer_end)


static func damage_for(def: WeaponDefinition, rec: HitRecord) -> float:
	return (
		DamageModel.bullet_damage(def, rec.distance, rec.zone, rec.target_index)
		* pow(PROP_PENETRATION_FACTOR, rec.props_passed)
	)
