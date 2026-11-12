# AC-3.5 (numeric part): the viewmodel renders on its own layer with its own camera, the main
# camera culls that layer, and in full ADS the sight point projects to the screen centre within
# 1 px at 1080p for every weapon (AC-9.2) (the rendered check is tests/visual/viewmodel_ads.gd).
# AC-3.6: firing the MP40 at a wall for 60 s keeps decal / effect pools at their caps with no
# node, object or memory growth.
extends GutTest

const Helper: GDScript = preload("res://tests/integration/player_test_helper.gd")
const W: GDScript = preload("res://tests/integration/weapon_test_helper.gd")


func test_viewmodel_layer_and_camera() -> void:
	var rig: W.Rig = W.build(self, [&"m1911"])
	await Helper.step(self, 5)
	var vm: Viewmodel = rig.controller().viewmodel
	assert_not_null(vm)
	assert_eq(vm.camera.cull_mask, Viewmodel.LAYER, "viewmodel camera renders only the viewmodel layer")
	assert_eq(rig.player.camera.cull_mask & Viewmodel.LAYER, 0, "world camera culls the viewmodel layer")
	assert_true(vm.viewport.transparent_bg)
	var meshes: Array[Node] = vm.gun.find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 3)
	for m: Node in meshes:
		assert_eq((m as MeshInstance3D).layers, Viewmodel.LAYER, "%s on the viewmodel layer" % m.name)


# AC-9.2: every conventional weapon of the spec table (tests/data/weapons_spec.json).
static func all_weapon_ids() -> Array[StringName]:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/weapons_spec.json"))
	var out: Array[StringName] = []
	for wid: String in spec["weapons"]:
		out.append(StringName(wid))
	return out


func test_ads_alignment_all_weapons() -> void:
	for wid: StringName in all_weapon_ids():
		var rig: W.Rig = W.build(self, [wid])
		var vm: Viewmodel = rig.controller().viewmodel
		vm.breath_enabled = false
		rig.input["aim"] = true
		await Helper.step(self, 60)
		assert_eq(rig.controller().held().ads, 1.0, "%s fully aimed" % wid)
		var size: Vector2 = Vector2(vm.viewport.size)
		var err: Vector2 = vm.sight_screen_position() - size * 0.5
		var err_1080: float = err.length() * 1080.0 / size.y
		assert_true(err_1080 < 1.0, "%s sight within 1 px of centre at 1080p (%.3f px)" % [wid, err_1080])
		rig.root.queue_free()
		await Helper.step(self, 2)


# AC-9.2: every weapon has draw / fire / reload (partial + empty, or the shell-by-shell set) /
# sprint clips, a world model for third person + box display, and a full audio set.
func test_clip_and_audio_sets_all_weapons() -> void:
	var rig: W.Rig = W.build(self, [&"m1911"])
	await Helper.step(self, 5)
	var vm: Viewmodel = rig.controller().viewmodel
	for wid: StringName in all_weapon_ids():
		var def: WeaponDefinition = WeaponCatalog.get_def(wid)
		vm.set_weapon(def, WeaponRuntime.new(def))
		var lib: StringName = StringName(String(wid))
		var clips: Array = [&"draw", &"fire", &"sprint", &"idle", &"holster"]
		clips.append_array(
			[&"reload_start", &"reload_shell"] if def.reload_per_shell else [&"reload_partial", &"reload_empty"]
		)
		for clip: StringName in clips:
			assert_true(vm.anim.has_animation(StringName("%s/%s" % [lib, clip])), "%s has %s" % [wid, clip])
		WeaponAudio.ensure(def)
		for layer: String in ["mech", "body", "tail", "tail_in", "mag_out", "mag_in", "bolt", "raise"]:
			assert_true(Audio.has_event(WeaponAudio.event(def, layer)), "%s audio %s" % [wid, layer])
		var world: Node3D = (
			def.world_scene.instantiate() as Node3D if def.world_scene != null else GreyboxGun.build(def, 1)
		)
		assert_not_null(world.get_node_or_null(^"Muzzle"), "%s world model has a Muzzle" % wid)
		world.free()


func test_hip_fire_crosshair_bloom() -> void:
	var rig: W.Rig = W.build(self, [&"mp40"])
	rig.controller().perfect_accuracy = false
	await Helper.step(self, 10)
	var idle: float = rig.controller().current_spread()
	rig.input["fire"] = true
	await Helper.step(self, 30)
	var firing: float = rig.controller().current_spread()
	rig.input["fire"] = false
	assert_true(firing > idle + 1.0, "sustained fire blooms the hip cone (%.2f -> %.2f)" % [idle, firing])
	await Helper.step(self, 90)
	assert_almost_eq(rig.controller().current_spread(), idle, 0.01, "bloom recovers")
	rig.input["aim"] = true
	await Helper.step(self, 30)
	assert_true(rig.controller().current_spread() < 0.3, "ADS cone near zero")


func test_mp40_60s_pools_capped_no_growth() -> void:
	var rig: W.Rig = W.build(self, [&"mp40"], "Mark_Walls")
	rig.player.motor.teleport(Vector3(16, 0.05, -9))
	rig.controller().set_infinite_ammo(true)
	rig.controller().perfect_accuracy = false
	await Helper.step(self, 10)
	W.aim_at(rig, Vector3(16, 1.5, -12))  # concrete wall: decals on every hit
	rig.input["fire"] = true
	var fx: WeaponFx = WeaponFx.of(rig.player)
	var warm: int = 0
	while (fx.decals.size() < WeaponFx.DECAL_CAP or warm < 600) and warm < 1800:  # >= 10 s, pools full
		await Helper.step(self, 30)
		warm += 30
	gut.p("warm-up %.1f s" % (warm / 60.0))
	var census0: Dictionary = _census(get_tree().root)
	var nodes0: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects0: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var mem0: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var shots0: int = rig.controller().shots_total
	for i: int in 50:
		W.aim_at(rig, Vector3(16, 1.5, -12))
		await Helper.step(self, 60)
	var shots: int = rig.controller().shots_total - shots0
	var c: Dictionary = fx.counts()
	gut.p("60 s MP40: %d shots, pools %s" % [rig.controller().shots_total, str(c)])
	assert_almost_eq(float(shots), 50.0 * 550.0 / 60.0, 3.0, "full-auto for 50 s at 550 RPM")
	assert_eq(int(c["decals"]), WeaponFx.DECAL_CAP, "decals at the 128 cap")
	assert_true(int(c["impacts"]) <= WeaponFx.IMPACT_CAP)
	assert_true(int(c["shells"]) <= WeaponFx.SHELL_CAP)
	assert_true(int(c["tracers"]) <= WeaponFx.TRACER_CAP)
	assert_true(int(c["flashes"]) <= WeaponFx.FLASH_CAP)
	var dn: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes0
	var dobj: float = Performance.get_monitor(Performance.OBJECT_COUNT) - objects0
	var dmem: float = Performance.get_monitor(Performance.MEMORY_STATIC) - mem0
	gut.p("growth over 50 s: nodes %+d objects %+d static memory %+.1f KiB" % [dn, dobj, dmem / 1024.0])
	var census1: Dictionary = _census(get_tree().root)
	for k: String in census1:
		if int(census1[k]) != int(census0.get(k, 0)):
			gut.p("node class %s: %d -> %d" % [k, census0.get(k, 0), census1[k]])
	assert_eq(dn, 0.0, "no node growth")
	assert_true(dobj < 64.0, "no object growth (%d)" % dobj)
	assert_true(dmem < 1024.0 * 1024.0, "static memory growth < 1 MiB (%.1f KiB)" % (dmem / 1024.0))
	rig.input["fire"] = false


static func _census(n: Node, out: Dictionary = {}) -> Dictionary:
	out[n.get_class()] = int(out.get(n.get_class(), 0)) + 1
	for c: Node in n.get_children(true):
		_census(c, out)
	return out
