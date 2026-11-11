# AC-3.1: fire-rate timing for all 4 weapons matches RPM within ±1 ms averaged over 100 shots
# (60 Hz ticks; auto weapons hold the trigger, semi/bolt/pump weapons click every other frame).
extends GutTest

const DT: float = 1.0 / 60.0
const IDS: Array[StringName] = [&"m1911", &"mp40", &"model37", &"kar98k"]


func _measure(def: WeaponDefinition, clicks: bool) -> float:
	var rt: WeaponRuntime = WeaponRuntime.new(def)
	rt.infinite_ammo = true
	rt.make_ready()
	var times: PackedFloat64Array = []
	var t: float = 0.0
	var frame: int = 0
	while times.size() < 101 and frame < 200000:
		var trigger: bool = (frame % 2 == 0) if clicks else true
		var shots: int = rt.update(DT, trigger, false, false)
		for i: int in shots:
			times.append(t)
		t += DT
		frame += 1
	return (times[100] - times[0]) / 100.0


func test_rpm_accuracy_all_weapons() -> void:
	for wid: StringName in IDS:
		var d: WeaponDefinition = WeaponCatalog.get_def(wid)
		var clicks: bool = d.fire_mode != WeaponDefinition.FireMode.AUTO
		var avg: float = _measure(d, clicks)
		var expected: float = 60.0 / d.rpm
		assert_almost_eq(
			avg * 1000.0, expected * 1000.0, 1.0, "%s %.0f RPM: avg interval %.3f ms" % [wid, d.rpm, avg * 1000.0]
		)


func test_semi_auto_needs_a_new_press() -> void:
	var rt: WeaponRuntime = WeaponRuntime.new(WeaponCatalog.get_def(&"m1911"))
	rt.make_ready()
	var shots: int = 0
	for i: int in 120:
		shots += rt.update(DT, true, false, false)
	assert_eq(shots, 1, "holding the trigger fires once")


func test_auto_fire_stops_on_release_and_banks_no_time() -> void:
	var rt: WeaponRuntime = WeaponRuntime.new(WeaponCatalog.get_def(&"mp40"))
	rt.make_ready()
	for i: int in 60:
		rt.update(DT, false, false, false)
	assert_eq(rt.update(DT, true, false, false), 1, "one shot on the press frame, not a burst")


func test_empty_mag_auto_reloads_and_dry_fire_without_reserve() -> void:
	var rt: WeaponRuntime = WeaponRuntime.new(WeaponCatalog.get_def(&"m1911"))
	rt.make_ready()
	rt.mag = 1
	rt.reserve = 0
	var dry: Array = [0]
	rt.dry_fired.connect(func() -> void: dry[0] += 1)
	var shots: int = 0
	for i: int in 60:
		shots += rt.update(DT, i % 2 == 0, false, false)
	assert_eq(shots, 1)
	assert_true(dry[0] > 0, "dry fire with empty mag and reserve")
	assert_eq(rt.state, WeaponRuntime.State.IDLE, "no reload without reserve")
