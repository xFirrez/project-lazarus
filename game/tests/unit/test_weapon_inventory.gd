# Inventory: slot count, replace-held when full, switch timing (lower + raise), cycling,
# loadout adoption keeps ammo.
extends GutTest

const DT: float = 1.0 / 60.0


func _tick(inv: WeaponInventory, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		inv.held().update(DT, false, false, false)
		inv.update()


func test_add_and_replace_when_full() -> void:
	var inv: WeaponInventory = WeaponInventory.new(2)
	assert_eq(inv.add_weapon(WeaponCatalog.get_def(&"m1911")), 0)
	assert_eq(inv.add_weapon(WeaponCatalog.get_def(&"mp40")), 1)
	inv.current = 1
	assert_eq(inv.add_weapon(WeaponCatalog.get_def(&"kar98k")), 1, "full: replaces the held weapon")
	assert_eq(inv.ids(), [&"m1911", &"kar98k"] as Array[StringName])
	var inv3: WeaponInventory = WeaponInventory.new(3)
	for wid: StringName in [&"m1911", &"mp40", &"kar98k"]:
		inv3.add_weapon(WeaponCatalog.get_def(wid))
	assert_eq(inv3.slots.size(), 3, "config-driven third slot (Pack Mule)")


func test_switch_takes_lower_plus_raise_time() -> void:
	var inv: WeaponInventory = WeaponInventory.new(2)
	inv.set_loadout([&"m1911", &"mp40"], WeaponCatalog.get_def, &"m1911")
	_tick(inv, 1.0)
	assert_eq(inv.held().state, WeaponRuntime.State.IDLE)
	inv.switch_to(1)
	var lower: float = WeaponCatalog.get_def(&"m1911").lower_time
	var raise: float = WeaponCatalog.get_def(&"mp40").raise_time
	var frames: int = 0
	while not (inv.held().def.id == &"mp40" and inv.held().state == WeaponRuntime.State.IDLE) and frames < 200:
		_tick(inv, DT)
		frames += 1
	assert_almost_eq(frames * DT, lower + raise, DT * 2.0, "switch time")


func test_cycle_wraps() -> void:
	var inv: WeaponInventory = WeaponInventory.new(2)
	inv.set_loadout([&"m1911", &"mp40"], WeaponCatalog.get_def, &"m1911")
	_tick(inv, 1.0)
	inv.cycle(-1)
	_tick(inv, 1.5)
	assert_eq(inv.held().def.id, &"mp40")
	inv.cycle(1)
	_tick(inv, 1.5)
	assert_eq(inv.held().def.id, &"m1911")


func test_loadout_keeps_existing_ammo() -> void:
	var inv: WeaponInventory = WeaponInventory.new(2)
	inv.set_loadout([&"m1911"], WeaponCatalog.get_def, &"m1911")
	inv.held().mag = 3
	inv.set_loadout([&"m1911", &"mp40"], WeaponCatalog.get_def, &"m1911")
	assert_eq(inv.slots[0].mag, 3)
	assert_eq(inv.slots[1].mag, 32)
