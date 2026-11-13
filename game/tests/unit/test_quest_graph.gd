# Quest engine data (Step 14, ARCHITECTURE §10): Vesper Peak's graphs validate (known prerequisites,
# no cycles, objectives set), the Requiem order matches VESPER_PEAK §7 (2a/2b/2c parallel after 1,
# 3 after all three), debug-jump ancestry, the lore file (14 documents, 9 reels, VO lines with known
# speakers) and the deterministic stage rules (frequency pick, drawer order, ice hit values).
extends GutTest

const STAGE0: String = "res://maps/vesper_peak/scripts/quest/stage0_stirs.gd"
const STAGE2A: String = "res://maps/vesper_peak/scripts/quest/stage2a_frozen_heart.gd"
const STAGE2B: String = "res://maps/vesper_peak/scripts/quest/stage2b_chained_drawer.gd"

var _def: MapDefinition = null


func before_all() -> void:
	_def = load("res://maps/vesper_peak/map_definition.tres") as MapDefinition


func _graph(id: StringName) -> QuestGraph:
	for g: QuestGraph in _def.quests:
		if g.id == id:
			return g
	return null


func test_graphs_validate() -> void:
	assert_eq(_def.quests.size(), 2)
	for g: QuestGraph in _def.quests:
		assert_eq(g.validate(), PackedStringArray(), "%s validates" % g.id)


func test_requiem_order() -> void:
	var g: QuestGraph = _graph(&"requiem")
	assert_eq(g.step(&"stage0").prerequisites, [] as Array[StringName])
	for s: StringName in [&"stage2a", &"stage2b", &"stage2c"]:
		assert_eq(g.step(s).prerequisites, [&"stage1"] as Array[StringName])
	assert_eq(g.step(&"stage3").prerequisites.size(), 3)
	assert_true(g.step(&"stage6").completes_graph)
	assert_eq(g.badge, &"requiem")
	assert_true(g.journal_unlocks.has(&"R09"))
	var anc: Array[StringName] = g.ancestors(&"stage4")
	assert_eq(anc.size(), 6, str(anc))
	assert_lt(anc.find(&"stage1"), anc.find(&"stage2b"))
	assert_lt(anc.find(&"stage2c"), anc.find(&"stage3"))


func test_cycle_detected() -> void:
	var g: QuestGraph = QuestGraph.new()
	for pair: Array in [[&"a", &"b"], [&"b", &"a"]]:
		var s: QuestStep = QuestStep.new()
		s.id = pair[0]
		s.prerequisites = [pair[1]] as Array[StringName]
		s.objective = QuestObjective
		g.steps.append(s)
	assert_false(g.validate().is_empty())


func test_lore_file() -> void:
	var lib: LoreLibrary = LoreLibrary.for_map(_def)
	assert_eq(lib.validate(), PackedStringArray())
	assert_eq(lib.ids_of_kind("doc").size(), 14)
	assert_eq(lib.ids_of_kind("reel").size(), 9)
	for i: int in 14:
		assert_false(lib.entry(StringName("L%02d" % (i + 1))).is_empty(), "L%02d" % (i + 1))
	for i: int in 9:
		assert_false(lib.entry(StringName("R%02d" % (i + 1))).is_empty(), "R%02d" % (i + 1))
	assert_true(lib.journal_ids().has(&"requiem"))
	assert_false(lib.journal_ids().has(&"vo_contact"))
	assert_false(lib.journal_ids().has(&"guestbook"))
	assert_string_contains(String(lib.entry(&"guestbook").get("body", "")), "seven")
	assert_gt(lib.duration_of(&"vo_contact"), 6.0)
	assert_string_contains(lib.transcript(&"R08"), "Dr. Elise Varga:")


func test_frequency_pick_deterministic() -> void:
	var s0: Script = load(STAGE0)
	var a: Array = s0.call(&"pick", 1234)
	assert_eq(a, s0.call(&"pick", 1234))
	assert_eq((a[0] as Array).size(), 3)
	var seen: Dictionary = {}
	for d: Variant in a[0]:
		seen[d] = true
	assert_eq(seen.size(), 3, "three different documents")
	for n: Variant in a[1]:
		assert_between(int(n), 10, 99)
	var differs: bool = false
	for seed_value: int in 20:
		differs = differs or s0.call(&"pick", seed_value) != a
	assert_true(differs)


func test_drawer_order_permutation() -> void:
	var s2b: Script = load(STAGE2B)
	for seed_value: int in 30:
		var o: Array = s2b.call(&"order_for", seed_value)
		var sorted: Array = o.duplicate()
		sorted.sort()
		assert_eq(sorted, [0, 1, 2, 3])


func test_ice_hit_values() -> void:
	var s2a: Script = load(STAGE2A)
	assert_eq(float(s2a.call(&"hit_value", DamageInfo.Kind.BULLET, &"kar98k", 1500.0)), 0.0)
	assert_eq(float(s2a.call(&"hit_value", DamageInfo.Kind.BULLET, &"ray_pistol", 1000.0)), 1000.0)
	for w: StringName in [&"law", &"frag", &"ray_pistol"]:
		var d: WeaponDefinition = WeaponCatalog.get_def(w)
		var v: float = float(s2a.call(&"hit_value", DamageInfo.Kind.EXPLOSIVE, w, d.splash_damage_centre))
		if w == &"ray_pistol":
			v += float(s2a.call(&"hit_value", DamageInfo.Kind.BULLET, w, d.damage))
		if w == &"law":
			v += float(s2a.call(&"hit_value", DamageInfo.Kind.EXPLOSIVE, w, d.damage))
		assert_gte(v, 2000.0, "%s breaks the ice (%.0f)" % [w, v])
	var cl: WeaponDefinition = WeaponCatalog.get_def(&"china_lake")
	assert_gte(
		float(s2a.call(&"hit_value", DamageInfo.Kind.EXPLOSIVE, &"china_lake", cl.damage + cl.splash_damage_centre)),
		2000.0
	)
