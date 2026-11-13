# Stage 2c "The Marked One": during a special round one Galvanic is marked (bright white-cored
# glow, unique whine; "ee.marked" = its net id). If it is not killed within FLEE_TIME it flees into a
# rift (despawns) and the next special round marks another. Killing it drops the shard where it
# died (navmesh-snapped; "ee.shard.c.pos").
# Authority: HOST.
extends RequiemObjective

const FLEE_TIME: float = 40.0

var escapes: int = 0
var _marked_at: float = 0.0


func _marked() -> int:
	return int(get_flag("ee.marked", 0))


func on_event(event: StringName, data: Dictionary) -> void:
	match event:
		&"zombie_spawned":
			var a: ZombieActor = data.get("actor", null)
			if a != null and _marked() == 0 and int(get_flag("ee.shard.c", 0)) == 0 and _is_galvanic(a):
				if m().rounds != null and m().rounds.is_special_round():
					mark(a)
		&"zombie_killed":
			var a: ZombieActor = data.get("actor", null)
			if a != null and a.net_id == _marked() and _marked() != 0:
				_drop(a.global_position)
		&"interact":
			if data.get("id", &"") == &"shard_c" and int(get_flag("ee.shard.c", 0)) == 1:
				collect_shard("c")
				complete()


static func _is_galvanic(a: ZombieActor) -> bool:
	return a.archetype != null and a.archetype.id == &"galvanic"


func mark(a: ZombieActor) -> void:
	_marked_at = now()
	a.set_meta(&"quest_marked", true)
	set_flag("ee.marked", a.net_id)
	vo(&"vo_marked")
	log_info("Galvanic %d marked" % a.net_id)


func on_tick(_delta: float) -> void:
	var id: int = _marked()
	if id == 0:
		return
	var a: ZombieActor = m().zombies.actors.get(id, null)
	if a == null:
		_escaped(null)  # despawned / re-queued without dying: treat as escaped
	elif now() - _marked_at >= FLEE_TIME:
		_escaped(a)


func _escaped(a: ZombieActor) -> void:
	escapes += 1
	set_flag("ee.marked", 0)
	if a != null:
		WonderFx.play(a, WonderFx.Kind.RIFT, PackedVector3Array([a.global_position]), 1.5, WonderFx.Variant.GREEN)
		m().zombies.host_despawn(a)
	vo(&"vo_marked_escaped")
	log_info("The marked Galvanic escaped (%d)" % escapes)


func _drop(at: Vector3) -> void:
	var p: Vector3 = at
	if m().specials != null and m().powerups != null:
		p = m().specials.guaranteed_drop_position(at)
	set_flag("ee.marked", 0)
	set_flag("ee.shard.c.pos", p)
	set_flag("ee.shard.c", 1)
	log_info("Marked Galvanic down: shard at %s" % p)


func on_debug_complete() -> void:
	set_flag("ee.marked", 0)
	set_flag("ee.shard.c", 1)
	collect_shard("c")
	complete()
