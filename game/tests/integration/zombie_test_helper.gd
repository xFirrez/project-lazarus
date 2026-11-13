# Shared setup for zombie integration tests: the nav torture map with a standalone TargetRegistry
# + ZombieSync (+ CrowdDirector), authority without a session. Targets are plain Node3D markers
# (or bot players); zombie attacks are recorded instead of damaging anyone.
extends RefCounted

const Helper: GDScript = preload("res://tests/integration/player_test_helper.gd")
const MAP_SCENE: PackedScene = preload("res://maps/_test/nav_torture.tscn")
const BENIGN: PackedStringArray = ["Jolt Physics job system exceeded the maximum number of jobs"]


class Rig:
	extends RefCounted
	var root: Node3D = null
	var zombies: ZombieSync = null
	var targets: TargetRegistry = null
	var crowd: CrowdDirector = null
	var hits: Array = []  # [target, amount, from]

	func marker(node_name: String) -> Node3D:
		return root.find_child(node_name, true, false) as Node3D

	func add_target(node_name: String, pos: Vector3) -> Node3D:
		var t: Node3D = Node3D.new()
		t.name = node_name
		root.add_child(t)
		t.global_position = pos
		crowd.extra_targets.append(t)
		return t

	func spawn(tier: int, pos: Vector3, kind: int = ZombieSpawner.Kind.WINDOW, hp: float = -1.0) -> ZombieActor:
		return zombies.host_spawn(zombies.archetype(&"zombie"), tier, pos, 0.0, kind, -1, hp)

	func spawn_at(tier: int, spawner_name: String) -> ZombieActor:
		var sp: ZombieSpawner = marker(spawner_name) as ZombieSpawner
		return zombies.host_spawn_at_spawner(zombies.archetype(&"zombie"), tier, sp)


static func build(test: GutTest) -> Rig:
	var rig: Rig = Rig.new()
	rig.root = MAP_SCENE.instantiate() as Node3D
	test.add_child_autofree(rig.root)
	rig.targets = TargetRegistry.new()
	rig.root.add_child(rig.targets)
	rig.targets.scan(rig.root)
	rig.zombies = ZombieSync.new()
	rig.zombies.targets = rig.targets
	rig.root.add_child(rig.zombies)
	rig.zombies.scan_spawners(rig.root)
	rig.zombies.auto_respawn = false
	rig.crowd = rig.zombies.crowd
	var hits: Array = rig.hits
	rig.crowd.damage_hook = func(t: Node3D, amount: float, from: Vector3) -> void: hits.append([t, amount, from])
	for i: int in 240:
		await test.get_tree().physics_frame
		if rig.crowd.is_ready():
			break
	return rig


static func step(test: GutTest, frames: int) -> void:
	var tree: SceneTree = test.get_tree()
	for i: int in frames:
		await tree.physics_frame
	for err: Variant in test.gut.error_tracker.get_current_test_errors():
		var text: String = "%s %s" % [err.code, err.rationale]
		for benign: String in BENIGN:
			if text.contains(benign):
				err.handled = true


static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
