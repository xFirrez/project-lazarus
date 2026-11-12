# AC-8.6 / AC-8.1: the Vesper Peak greybox contains every canonical id of
# maps/vesper_peak/markers_manifest.json — zones (volumes + MapDefinition), the 14 doors with
# their VESPER_PEAK §2.2 costs (17,000 total) unlocking their zones, the live wall-buys, the
# machines / power switch / chute / bridge, and every typed MapMarker with the right kind and zone.
extends GutTest

const MAP: String = "res://maps/vesper_peak/"

var _manifest: Dictionary = {}
var _root: Node3D = null


func before_all() -> void:
	var f: FileAccess = FileAccess.open(MAP + "markers_manifest.json", FileAccess.READ)
	_manifest = JSON.parse_string(f.get_as_text())
	_root = (load(MAP + "vesper_peak.tscn") as PackedScene).instantiate() as Node3D
	add_child(_root)


func after_all() -> void:
	_root.free()


func _named(n: String) -> Node:
	return _root.find_child(n, true, false)


func test_zones_exist() -> void:
	var def: MapDefinition = load(MAP + "map_definition.tres") as MapDefinition
	var vols: Dictionary = {}
	for v: Node in _root.find_children("*", "ZoneVolume", true, false):
		vols[String((v as ZoneVolume).zone)] = true
	for z: Variant in _manifest["zones"]:
		assert_true(vols.has(String(z)), "zone volume %s" % z)
		assert_not_null(def.zone_def(StringName(z)), "MapDefinition zone %s" % z)
		for a: StringName in def.zone_def(StringName(z)).adjacent:
			assert_true(def.zone_def(a).adjacent.has(StringName(z)), "adjacency %s <-> %s symmetric" % [z, a])


func test_doors_costs_and_unlocks() -> void:
	var total: int = 0
	for d: Variant in _manifest["doors"]:
		var b: PurchasableDoor = _named("%s_Buy" % d["id"]) as PurchasableDoor
		assert_not_null(b, "door %s" % d["id"])
		if b == null:
			continue
		assert_eq(b.cost, int(d["cost"]), "%s cost" % d["id"])
		assert_eq(String(b.door_id), String(d["id"]))
		assert_false(b.nav_doors.is_empty(), "%s has a NavDoor" % d["id"])
		assert_true(b.unlocks.size() >= 1, "%s unlocks a zone" % d["id"])
		total += b.cost
	assert_eq(total, int(_manifest["door_total"]))
	assert_eq(total, 17000, "VESPER_PEAK §2: 17,000 points to open everything")


func test_live_nodes() -> void:
	for n: Variant in _manifest["wall_buys_live"]:
		assert_true(_named(String(n)) is WallBuy, "wall-buy %s" % n)
	for n: Variant in _manifest["nodes"]:
		assert_not_null(_named(String(n)), "node %s" % n)
	assert_true(_named("PWR_MainSwitch") is PowerSwitch)
	assert_true(_named("GND_Gondola") is TraversalMachine)
	assert_true((_named("LFT_FreightLift") as TraversalMachine).allow_zombies)
	assert_true((_named("BRG_ReactorBridge") as NavDoor).solid_when_open)


func test_markers() -> void:
	var found: Dictionary = {}
	for n: Node in _root.find_children("*", "MapMarker", true, false):
		var mk: MapMarker = n as MapMarker
		assert_false(found.has(String(mk.marker_id)), "duplicate marker %s" % mk.marker_id)
		found[String(mk.marker_id)] = mk
	for e: Variant in _manifest["markers"]:
		var mk2: MapMarker = found.get(String(e["id"]), null)
		assert_not_null(mk2, "marker %s" % e["id"])
		if mk2 != null:
			assert_eq(String(mk2.kind), String(e["kind"]), "%s kind" % e["id"])
			assert_eq(String(mk2.zone), String(e["zone"]), "%s zone" % e["id"])
	assert_eq(found.size(), (_manifest["markers"] as Array).size(), "no markers missing from the manifest")
	# VESPER_PEAK §5.2 / §5.3 / §6: 7 perks, 7 box locations, 14 lore documents, 8 reels.
	var kinds: Dictionary = {}
	for k: String in found:
		var kind: String = String((found[k] as MapMarker).kind)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
	assert_eq(int(kinds.get("perk", 0)), 7)
	assert_eq(int(kinds.get("box", 0)), 7)
	assert_eq(int(kinds.get("lore", 0)), 14)
	assert_eq(int(kinds.get("reel", 0)), 8)
	assert_eq(int(kinds.get("relay", 0)), 3)
	assert_eq(int(kinds.get("raven", 0)), 5)


func test_spawners_per_zone() -> void:
	var per: Dictionary = {}
	for n: Node in _root.find_children("*", "ZombieSpawner", true, false):
		var z: String = String((n as ZombieSpawner).zone)
		per[z] = int(per.get(z, 0)) + 1
	for z: Variant in _manifest["zones"]:
		assert_true(int(per.get(String(z), 0)) >= 3, "%s has spawners (%d)" % [z, int(per.get(String(z), 0))])
