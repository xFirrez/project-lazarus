# ZombieBehavior — an archetype's special brain on top of ZombieSim (ARCHITECTURE §7.1; Step 12):
# named by ZombieArchetype.behavior_script, created per zombie on the host. Hooks run inside the
# sim's schedule: `think` (LOD rate) and `move` (every physics frame) return true when they
# handled the tick (the default PURSUE / ATTACK logic is skipped), `filter_damage` rewrites
# incoming damage before it is applied (Warden armor), `on_damaged` / `on_death` react.
# Authority: HOST only (presentation reads the replicated actor flags / messages).
class_name ZombieBehavior
extends RefCounted

var sim: ZombieSim = null


func setup() -> void:
	pass


func think(_dt: float) -> bool:
	return false


func move(_dt: float) -> bool:
	return false


func filter_damage(info: DamageInfo) -> float:
	return info.amount


func on_damaged(_info: DamageInfo, _survives: bool) -> void:
	pass


# Big hits stagger plain zombies; bosses shrug them off.
func can_stagger() -> bool:
	return true


# Stun requests (Conduit, puddles) -> seconds actually stunned (0 = immune).
func stun_time(seconds: float) -> float:
	return seconds


func on_stunned() -> void:
	pass


func on_frozen(_seconds: float) -> void:
	pass


# --- helpers ------------------------------------------------------------------------------------


func actor() -> ZombieActor:
	return sim.actor


func arch() -> ZombieArchetype:
	return sim.archetype


func flat_distance_to(p: Vector3) -> float:
	return Vector2(p.x - sim.pos.x, p.z - sim.pos.z).length()


# Players (PlayerCharacter) within `radius` of `at` (standing, not downed).
func players_near(at: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for t: Node3D in sim.director.live_targets():
		if sim.director.is_attractor(t) or sim.director.is_downed(t):
			continue
		if t.global_position.distance_to(at) <= radius:
			out.append(t)
	return out
