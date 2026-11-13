# AC-12.3 (rules): the Lazarus Conduit buildable — three parts (coil / lens / stock), each spawning
# at one of two Vesper Peak markers chosen per match (seeded: the same seed gives the same layout,
# every option occurs), the Lab Workbench, power required, reward and the box-pool unlock flag.
extends GutTest

var def: BuildableDef = null


func before_all() -> void:
	def = load("res://maps/vesper_peak/buildables/conduit.tres") as BuildableDef


func test_definition() -> void:
	assert_eq(def.parts, [&"coil", &"lens", &"stock"] as Array[StringName])
	assert_eq(def.workbench_marker, &"WB_LabWorkbench")
	assert_true(def.requires_power)
	assert_eq(def.reward_weapon, &"lazarus_conduit")
	assert_eq(def.unlock_flag, "conduit_built")
	var vesper: MapDefinition = load("res://maps/vesper_peak/map_definition.tres") as MapDefinition
	assert_true(vesper.buildables.has(def), "Vesper Peak lists the Conduit")


func test_two_options_per_part_exist_as_markers() -> void:
	var manifest: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://maps/vesper_peak/markers_manifest.json")
	)
	var ids: Array = []
	for m: Variant in manifest["markers"] if manifest is Dictionary else manifest:
		ids.append(String((m as Dictionary)["id"]))
	assert_true(ids.has(String(def.workbench_marker)))
	for p: StringName in def.parts:
		assert_eq(def.options_of(p).size(), 2, "%s: two locations" % p)
		for mk: StringName in def.options_of(p):
			assert_true(ids.has(String(mk)), "%s marker exists" % mk)


func test_seeded_locations() -> void:
	assert_eq(BuildableSystem.choose_locations(def, 1234), BuildableSystem.choose_locations(def, 1234), "seeded")
	var seen: Dictionary = {}
	for s: int in 100:
		var locs: Dictionary = BuildableSystem.choose_locations(def, s)
		assert_eq(locs.size(), 3)
		for p: Variant in locs:
			assert_between(int(locs[p]), 0, 1)
			seen["%s%d" % [p, locs[p]]] = true
	assert_eq(seen.size(), 6, "every option occurs over 100 matches")
