# AC-7.5 (automated part): the four playable characters are retargeted humanoids that play the
# survivor library (locomotion, crouch, slide, jump, downed crawl, revive, drink, per-class weapon
# holds, fire / reload layers); the weapon-hold layer really changes the arm pose per class and
# the locomotion layer still drives the legs underneath it; each model is distinct and in budget.
extends GutTest

const CHARS: Array[StringName] = [&"calloway", &"orlov", &"brandt", &"ashcombe"]
const CLIPS: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"crouch_idle",
	&"crouch_walk",
	&"slide",
	&"jump",
	&"downed_crawl",
	&"revive",
	&"drink",
	&"hold_pistol",
	&"hold_rifle",
	&"hold_shotgun",
	&"hold_lmg",
	&"fire_pistol",
	&"fire_long",
	&"reload_pistol",
	&"reload_long"
]


func _spawn(c: StringName) -> SurvivorModel:
	var def: CharacterDefinition = CharacterDefinition.get_def(c)
	var m: SurvivorModel = (load(def.model_scene) as PackedScene).instantiate() as SurvivorModel
	m.character = def
	add_child_autofree(m)
	return m


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _bone_rot(m: SurvivorModel, bone: String) -> Quaternion:
	return m.skeleton.get_bone_pose_rotation(m.skeleton.find_bone(bone))


func test_each_character_has_a_retargeted_model_and_full_library() -> void:
	var heights: Array[float] = []
	for c: StringName in CHARS:
		var m: SurvivorModel = _spawn(c)
		await _frames(2)
		assert_not_null(m.skeleton, "%s skeleton" % c)
		assert_eq(m.skeleton.name, &"GeneralSkeleton", "%s retargeted through the BoneMap" % c)
		assert_not_null(m.tree, "%s animation tree" % c)
		for clip: StringName in CLIPS:
			assert_true(m.has_clip(clip), "%s has %s" % [c, clip])
		heights.append(m.skeleton.get_bone_global_rest(m.skeleton.find_bone("Head")).origin.y)
		var tris: int = 0
		for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s: int in mesh.get_surface_count():
				tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_between(tris, 4000, 12000, "%s triangles in budget (%d)" % [c, tris])
	var distinct: Dictionary = {}
	for h: float in heights:
		distinct[snappedf(h, 0.01)] = true
	assert_gt(distinct.size(), 2, "characters have different proportions %s" % str(heights))


func test_weapon_class_holds_change_the_arms() -> void:
	var m: SurvivorModel = _spawn(&"orlov")
	await _frames(3)
	var poses: Dictionary = {}
	for h: StringName in SurvivorModel.HOLDS:
		m.set_hold(h)
		await _frames(25)
		poses[h] = _bone_rot(m, "RightUpperArm")
	for i: int in SurvivorModel.HOLDS.size():
		for j: int in range(i + 1, SurvivorModel.HOLDS.size()):
			var a: Quaternion = poses[SurvivorModel.HOLDS[i]]
			var b: Quaternion = poses[SurvivorModel.HOLDS[j]]
			assert_gt(
				a.angle_to(b),
				deg_to_rad(4.0),
				"%s vs %s arm pose differs" % [SurvivorModel.HOLDS[i], SurvivorModel.HOLDS[j]]
			)


func test_locomotion_drives_legs_under_the_upper_layer() -> void:
	var m: SurvivorModel = _spawn(&"brandt")
	await _frames(3)
	m.set_hold(&"hold_rifle")
	m.set_locomotion(&"idle")
	await _frames(20)
	var arm_idle: Quaternion = _bone_rot(m, "RightUpperArm")
	var leg_idle: Quaternion = _bone_rot(m, "LeftUpperLeg")
	m.set_locomotion(&"crouch_idle")
	await _frames(20)
	assert_gt(_bone_rot(m, "LeftUpperLeg").angle_to(leg_idle), deg_to_rad(30.0), "crouch bends the legs")
	assert_lt(_bone_rot(m, "RightUpperArm").angle_to(arm_idle), deg_to_rad(6.0), "rifle hold kept while crouching")
	m.set_locomotion(&"downed_crawl")
	await _frames(25)
	var hips: Vector3 = m.skeleton.get_bone_pose_position(m.skeleton.find_bone("Hips"))
	var rest: Vector3 = m.skeleton.get_bone_rest(m.skeleton.find_bone("Hips")).origin
	assert_lt(hips.y, rest.y - 0.4, "downed: hips on the ground (%.2f vs rest %.2f)" % [hips.y, rest.y])
	m.play_fire(null)
	m.play_action(&"reload_pistol")
	await _frames(5)
	assert_eq(m.fires_played, 1)
	assert_eq(m.reloads_played, 1)


func test_state_mapping() -> void:
	assert_eq(SurvivorModel.locomotion_for(4, 0.0, false), &"idle")
	assert_eq(SurvivorModel.locomotion_for(4, 1.5, false), &"walk")
	assert_eq(SurvivorModel.locomotion_for(4 | 8, 6.0, false), &"run")
	assert_eq(SurvivorModel.locomotion_for(4 | MotorComponent.Stance.CROUCH, 0.0, false), &"crouch_idle")
	assert_eq(SurvivorModel.locomotion_for(4 | MotorComponent.Stance.CROUCH, 1.0, false), &"crouch_walk")
	assert_eq(SurvivorModel.locomotion_for(4 | MotorComponent.Stance.SLIDE, 6.0, false), &"slide")
	assert_eq(SurvivorModel.locomotion_for(0, 3.0, false), &"jump")
	assert_eq(SurvivorModel.locomotion_for(4 | 16, 0.5, false), &"downed_crawl")
	assert_eq(SurvivorModel.locomotion_for(4, 0.0, true), &"revive")
	var wc: Dictionary = {
		&"m1911": &"hold_pistol", &"mp40": &"hold_rifle", &"m14": &"hold_rifle", &"coachgun": &"hold_shotgun"
	}
	for wid: StringName in wc:
		var def: WeaponDefinition = WeaponCatalog.get_def(wid)
		if def != null:
			assert_eq(SurvivorModel.hold_for(def), wc[wid], String(wid))
	var lmg: WeaponDefinition = WeaponDefinition.new()
	lmg.weapon_class = WeaponDefinition.WeaponClass.LMG
	assert_eq(SurvivorModel.hold_for(lmg), &"hold_lmg")


func test_first_person_arms_use_the_character_colours() -> void:
	for c: StringName in [&"calloway", &"ashcombe"] as Array[StringName]:
		var def: CharacterDefinition = CharacterDefinition.get_def(c)
		var gun: Node3D = GreyboxGun.build(WeaponCatalog.get_def(&"mp40"))
		add_child_autofree(gun)
		ViewmodelArms.attach(gun, WeaponCatalog.get_def(&"mp40"), def, Viewmodel.LAYER)
		var sleeve: MeshInstance3D = gun.get_node(^"Arms/RightSleeve") as MeshInstance3D
		assert_eq((sleeve.material_override as StandardMaterial3D).albedo_color, def.sleeve_color, "%s sleeve" % c)
		assert_not_null(gun.get_node_or_null(^"Arms/LeftHand"), "two-handed weapon gets a support hand")


func test_authored_m1911_arms_are_tinted() -> void:
	var def: WeaponDefinition = WeaponCatalog.get_def(&"m1911")
	if def.viewmodel_scene == null:
		pass_test("no authored M1911 viewmodel")
		return
	var gun: Node3D = def.viewmodel_scene.instantiate() as Node3D
	add_child_autofree(gun)
	var ch: CharacterDefinition = CharacterDefinition.get_def(&"brandt")
	var mesh: MeshInstance3D = ViewmodelArms.attach(gun, def, ch, Viewmodel.LAYER) as MeshInstance3D
	assert_not_null(mesh, "authored arms found")
	assert_null(gun.get_node_or_null(^"Arms/RightSleeve"), "no placeholder arms on an authored viewmodel")
	var tinted: int = 0
	for i: int in mesh.mesh.get_surface_count():
		var o: Material = mesh.get_surface_override_material(i)
		if o is ShaderMaterial and (o as ShaderMaterial).get_shader_parameter(&"albedo") == ch.sleeve_color:
			tinted += 1
	assert_gt(tinted, 0, "sleeve surface tinted to Brandt's sleeve colour")
