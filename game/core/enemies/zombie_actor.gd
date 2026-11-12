# ZombieActor — one zombie (ARCHITECTURE §7.1): a HitTarget whose hurtboxes come from its
# ZombieVisual's model, a kinematic body capsule that blocks players (layer 4 "zombie_body"), and
# the replicated presentation state (speed, tier, action + start time, flags, health bucket).
# On the host a ZombieSim (brain, ticked by the CrowdDirector) drives it; on clients the state
# comes from ZombieSync snapshots and the position from an InterpolationBuffer.
# Authority: host simulates and applies damage; clients present.
class_name ZombieActor
extends HitTarget

enum Action { NONE, ATTACK, TEAR, CLIMB, DROP, VENT, STAGGER, RISE, WAIT }
# ELECTROCUTED: Lazarus Conduit stun (spasm + sparks). TELEGRAPH: a special attack is winding up
# (Galvanic leap crackle, Warden slam / charge / summon) — every peer shows the warning.
enum Flag {
	CRAWLER = 1, BURNING = 2, STUNNED = 4, TRAVERSING = 8, FROZEN = 16, AGGRO = 32, ELECTROCUTED = 64, TELEGRAPH = 128
}

const BODY_LAYER: int = 1 << 3  # 3d_physics/layer_4 "zombie_body"

var net_id: int = 0
var archetype: ZombieArchetype = null
var variant: int = 0
var tier: int = ZombieArchetype.Tier.SHAMBLE
var spawn_kind: int = ZombieSpawner.Kind.RISER
var sim: ZombieSim = null  # host only
var behavior: ZombieBehavior = null  # host only: the archetype's special brain (sim.behavior)
var visual: ZombieVisual = null
var body: AnimatableBody3D = null
var buffer: InterpolationBuffer = null  # clients only

# Replicated presentation state.
var speed: float = 0.0  # current ground speed (m/s), drives the locomotion blend
var action: int = Action.NONE
var action_time: float = 0.0  # host-clock time the action started
var flags: int = 0
var look_target: Vector3 = Vector3.INF
var last_hit: DamageInfo = null  # host: the damage being applied (for brain reactions)

var _last_pos: Vector3 = Vector3.ZERO


func setup(p_archetype: ZombieArchetype, p_variant: int, p_tier: int, health_value: float) -> void:
	archetype = p_archetype
	variant = p_variant
	tier = p_tier
	max_health = health_value
	respawn_time = 0.0


func _ready() -> void:
	super()
	add_to_group(&"zombie")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	body = AnimatableBody3D.new()
	body.name = "Body"
	body.sync_to_physics = false
	body.collision_layer = BODY_LAYER
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = archetype.capsule_radius * 0.8
	cap.height = archetype.capsule_height
	cs.shape = cap
	cs.position = Vector3(0, archetype.capsule_height * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	visual = ZombieVisual.new()
	visual.name = "Visual"
	add_child(visual)
	_last_pos = global_position


func is_crawler() -> bool:
	return flags & Flag.CRAWLER != 0


func set_flag(flag: int, on: bool) -> void:
	flags = (flags | flag) if on else (flags & ~flag)


func start_action(a: int) -> void:
	action = a
	action_time = Net.host_time()


func health_bucket() -> int:
	if max_health <= 0.0:
		return 255
	return clampi(int(ceil(health / max_health * 255.0)), 0, 255)


# HOST: remember the DamageInfo so the brain can react (stagger, crawler) after HitTarget applies it.
func host_apply(info: DamageInfo) -> float:
	if behavior != null and alive:
		info.amount = behavior.filter_damage(info)  # Warden armor plates / core
	last_hit = info
	var applied: float = super(info)
	last_hit = null
	return applied


func _on_damaged(amount: float, zone: int, kind: int, source_peer: int) -> void:
	super(amount, zone, kind, source_peer)
	if sim != null and last_hit != null:
		sim.on_damaged(last_hit, alive and health > 0.0)
	if visual != null:
		visual.on_hit(amount, zone, kind, health <= 0.0)


# Clients: sample the interpolation buffer at the physics tick (hurtboxes follow this pose).
func client_tick(local_now: float, delta: float) -> void:
	if buffer == null or buffer.is_empty() or not alive:
		return
	var t: float = buffer.playback_time(local_now)
	var p: Vector3 = buffer.sample_position(t)
	global_position = p
	rotation.y = buffer.sample_yaw(t)
	var moved: Vector3 = p - _last_pos
	moved.y = 0.0
	speed = lerpf(speed, moved.length() / maxf(delta, 0.001), clampf(delta * 10.0, 0.0, 1.0))
	_last_pos = p


# Disables collision when dead (corpses don't block players or bullets).
func set_collision_enabled(on: bool) -> void:
	body.collision_layer = BODY_LAYER if on else 0
	for hb: Hurtbox in hurtboxes:
		hb.collision_layer = Hurtbox.LAYER if on else 0


func _set_alive(on: bool, source_peer: int) -> void:
	super(on, source_peer)
	if not on:
		set_collision_enabled(false)
