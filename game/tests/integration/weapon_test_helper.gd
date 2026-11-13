# Shared setup for weapon integration tests: the gun range with a standalone TargetRegistry +
# WeaponSync (authority without a session), a local player driven by a scriptable input state.
extends RefCounted

const Helper: GDScript = preload("res://tests/integration/player_test_helper.gd")
const RANGE_SCENE: PackedScene = preload("res://maps/_test/gun_range.tscn")


class Rig:
	extends RefCounted
	var root: Node3D = null
	var player: PlayerCharacter = null
	var sync: WeaponSync = null
	var targets: TargetRegistry = null
	var input: Dictionary = {"fire": false, "aim": false, "reload": false, "melee": false, "lethal": false}

	func dummy(node_name: String) -> TargetDummy:
		return root.find_child(node_name, true, false) as TargetDummy

	func marker(node_name: String) -> Vector3:
		return (root.find_child(node_name, true, false) as Node3D).global_position

	func controller() -> WeaponController:
		return player.weapons


static func build(test: GutTest, weapons: Array, at_marker: String = "Mark_LaneA_10m") -> Rig:
	var rig: Rig = Rig.new()
	rig.root = RANGE_SCENE.instantiate() as Node3D
	test.add_child_autofree(rig.root)
	rig.targets = TargetRegistry.new()
	rig.root.add_child(rig.targets)
	rig.targets.scan(rig.root)
	rig.sync = WeaponSync.new()
	rig.sync.targets = rig.targets
	rig.root.add_child(rig.sync)
	rig.player = Helper.spawn_player(rig.root, rig.marker(at_marker))
	var input: Dictionary = rig.input
	rig.player.bot_driver = func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.fire = bool(input["fire"])
		f.aim = bool(input["aim"])
		f.reload_pressed = bool(input["reload"])
		f.melee_pressed = bool(input["melee"])
		f.lethal_held = bool(input["lethal"])
		input["reload"] = false
		input["melee"] = false
		return f
	rig.sync.validator.give(1, WeaponCatalog.get_def(&"knife"))
	for wid: Variant in weapons:
		rig.sync.validator.give(1, WeaponCatalog.get_def(StringName(wid)))
	rig.player.weapons.give_default_loadout(weapons)
	rig.player.weapons.recoil_enabled = false
	rig.player.weapons.perfect_accuracy = true
	return rig


static func aim_at(rig: Rig, point: Vector3) -> void:
	var eye: Vector3 = rig.player.weapons.eye_position()
	var d: Vector3 = (point - eye).normalized()
	rig.player.set_view(atan2(-d.x, -d.z), asin(d.y))


# Presses fire until exactly one more shot has gone out (semi weapons need a fresh press).
static func fire_one(test: GutTest, rig: Rig, max_frames: int = 240) -> bool:
	var before: int = rig.player.weapons.shots_total
	for i: int in max_frames:
		rig.input["fire"] = i % 2 == 0
		await Helper.step(test, 1)
		if rig.player.weapons.shots_total > before:
			rig.input["fire"] = false
			return true
	rig.input["fire"] = false
	return false


static func give(rig: Rig, weapon_id: StringName) -> void:
	rig.sync.validator.give(1, WeaponCatalog.get_def(weapon_id))
	rig.player.weapons.give_default_loadout([weapon_id])
