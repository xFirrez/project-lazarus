# WeaponInventory — the player's weapon slots (GAME_DESIGN §3.4): `slot_count` primaries
# (2, 3 with Pack Mule later), the knife and the lethal grenade count. Switching lowers the held
# weapon, then raises the next one (raise/lower times per definition). Adding a weapon with all
# slots full replaces the held one. The host decides the loadout (WeaponSync `_wloadout`); the
# owner adopts it here, keeping ammo of weapons it already had.
# Authority: owner-side state; the host mirrors ownership and ammo (HitValidator).
class_name WeaponInventory
extends RefCounted

signal current_changed(slot: int, runtime: WeaponRuntime)
signal loadout_changed

var slot_count: int = 2
var slots: Array[WeaponRuntime] = []
var current: int = 0
var pending: int = -1  # slot being switched to
var melee_def: WeaponDefinition = null
var lethal_def: WeaponDefinition = null
var lethal_count: int = 0


func _init(p_slots: int = 2) -> void:
	slot_count = p_slots


func held() -> WeaponRuntime:
	if current < 0 or current >= slots.size():
		return null
	return slots[current]


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: WeaponRuntime in slots:
		out.append(r.def.id)
	return out


func slot_of(weapon_id: StringName) -> int:
	for i: int in slots.size():
		if slots[i].def.id == weapon_id:
			return i
	return -1


# Adds a weapon (fresh ammo) and returns its slot: a free slot, else replaces the held weapon.
func add_weapon(def: WeaponDefinition) -> int:
	var existing: int = slot_of(def.id)
	if existing >= 0:
		slots[existing].refill()
		return existing
	var rt: WeaponRuntime = WeaponRuntime.new(def)
	if slots.size() < slot_count:
		slots.append(rt)
		loadout_changed.emit()
		return slots.size() - 1
	slots[current] = rt
	rt.make_ready()
	loadout_changed.emit()
	current_changed.emit(current, rt)
	return current


# Adopts a host loadout (slot order). Weapons already held keep their runtime (ammo).
func set_loadout(weapon_ids: Array, defs: Callable, current_id: StringName) -> void:
	var next: Array[WeaponRuntime] = []
	for wid: Variant in weapon_ids:
		var idx: int = slot_of(StringName(wid))
		if idx >= 0:
			next.append(slots[idx])
		else:
			var def: WeaponDefinition = defs.call(StringName(wid))
			if def != null:
				next.append(WeaponRuntime.new(def))
	var prev_held: WeaponRuntime = held()
	slots = next
	var target: int = maxi(slot_of(current_id), 0)
	loadout_changed.emit()
	if slots.is_empty():
		current = 0
		return
	if prev_held == null or not slots.has(prev_held):
		current = target
		pending = -1
		slots[current].raise()
		current_changed.emit(current, slots[current])
	elif slots[target] != prev_held:
		switch_to(target)


func switch_to(slot: int) -> bool:
	if slot < 0 or slot >= slots.size() or slot == current and pending < 0:
		return false
	if pending >= 0:
		pending = slot
		return true
	var h: WeaponRuntime = held()
	if h == null or h.state == WeaponRuntime.State.HOLSTERED:
		current = slot
		slots[current].raise()
		current_changed.emit(current, slots[current])
		return true
	if h.state == WeaponRuntime.State.MELEE:
		return false
	pending = slot
	h.holster()
	return true


func cycle(delta: int) -> bool:
	if slots.size() < 2:
		return false
	var base: int = pending if pending >= 0 else current
	return switch_to(posmod(base + delta, slots.size()))


# Completes a switch once the held weapon is lowered. Call every tick after the runtime update.
func update() -> void:
	if pending < 0:
		return
	var h: WeaponRuntime = held()
	if h == null or h.state == WeaponRuntime.State.HOLSTERED:
		current = pending
		pending = -1
		slots[current].raise()
		current_changed.emit(current, slots[current])
