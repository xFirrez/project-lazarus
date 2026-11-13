# RequiemObjective — shared helpers for the "Requiem for Lazarus" stage objectives (VESPER_PEAK §7):
# the quest world (VesperQuestWorld), VO, quest zombies (spawned outside the round's count: drawer
# corpses, radio bursts, finale waves), the shard HUD indicator and the escort / finale spawn hooks.
# Authority: HOST only.
class_name RequiemObjective
extends QuestObjective

const CONDUIT_PREFIX: String = "lazarus_conduit"
const RAY_PREFIX: String = "ray_pistol"


func world() -> VesperQuestWorld:
	return VesperQuestWorld.of(m())


func vo(entry: StringName, at: Vector3 = Vector3.INF) -> void:
	quest.vo.host_play(entry, at)


# n zombies (run tier, round health) around `at` on the navmesh; not part of the round's count.
func spawn_zombies(at: Vector3, n: int, archetype: StringName = &"zombie") -> Array[ZombieActor]:
	var out: Array[ZombieActor] = []
	var zs: ZombieSync = m().zombies
	if zs == null or zs.crowd == null:
		return out
	var arch: ZombieArchetype = zs.archetype(archetype)
	var hp: float = m().rounds.zombie_health() if m().rounds != null else arch.health_for_round(1)
	for i: int in n:
		var a: float = TAU * float(i) / maxf(float(n), 1.0)
		var p: Vector3 = zs.crowd.snap(at + Vector3(cos(a), 0.0, sin(a)) * 1.2, at)
		if not p.is_finite():
			p = at
		var z: ZombieActor = zs.host_spawn(arch, ZombieArchetype.Tier.RUN, p, a, ZombieSpawner.Kind.RISER, -1, hp)
		if z != null:
			out.append(z)
	return out


static func shard_count(q: QuestSystem) -> int:
	var n: int = 0
	for l: String in VesperQuestWorld.SHARDS:
		n += int(int(q.flag("ee.shard.%s" % l, 0)) == 2)
	return n


# "qhud.shards": the three-shard indicator (VESPER_PEAK §7 stage 2), until they go into the pod.
static func update_shard_hud(q: QuestSystem) -> void:
	var n: int = shard_count(q)
	var text: String = ""
	if not bool(q.flag("ee.pod_shards", false)) and q.is_done(&"stage1"):
		text = "Heart shards  %s%s  %d / 3" % ["◆".repeat(n), "◇".repeat(3 - n), n]
	if String(q.flag("qhud.shards", "")) != text:
		q.host_set("qhud.shards", text)


func collect_shard(letter: String) -> void:
	set_flag("ee.shard.%s" % letter, 2)
	update_shard_hud(quest)
	vo(&"vo_shard")


static func is_upgraded(weapon: StringName) -> bool:
	var d: WeaponDefinition = WeaponCatalog.get_def(weapon)
	return d != null and d.is_upgraded()


func bridge(open: bool) -> void:
	for d: Node in m().map_root.find_children("*", "NavDoor", true, false):
		var nd: NavDoor = d as NavDoor
		if nd.solid_when_open and nd.is_open != open:
			nd.host_set_open(open)


func marker_pos(id: StringName) -> Vector3:
	var w: VesperQuestWorld = world()
	var mk: MapMarker = w.markers.get(id, null) if w != null else null
	return mk.global_position if mk != null else Vector3.ZERO
