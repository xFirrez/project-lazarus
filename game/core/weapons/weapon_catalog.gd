# WeaponCatalog — lookup of WeaponDefinitions from the Content registry by id, plus a compact
# network index (position in the id-sorted list, identical on every peer) for unreliable streams.
# Authority: read-only data.
class_name WeaponCatalog
extends RefCounted

static var _sorted: Array[StringName] = []


static func get_def(weapon_id: StringName) -> WeaponDefinition:
	return Content.get_def(&"WeaponDefinition", weapon_id) as WeaponDefinition


static func all_ids() -> Array[StringName]:
	if _sorted.is_empty():
		for res: Resource in Content.get_all(&"WeaponDefinition"):
			_sorted.append((res as WeaponDefinition).id)
		_sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return _sorted


static func index_of(weapon_id: StringName) -> int:
	return all_ids().find(weapon_id)


static func def_at(index: int) -> WeaponDefinition:
	var ids: Array[StringName] = all_ids()
	if index < 0 or index >= ids.size():
		return null
	return get_def(ids[index])


# The Lazarus Forge version of a weapon (GAME_DESIGN §9.3), or null if it has none.
static func upgrade_of(weapon_id: StringName) -> WeaponDefinition:
	var base: WeaponDefinition = get_def(weapon_id)
	if base == null or base.is_upgraded():
		return null
	if base.upgraded != null:
		return base.upgraded
	var up: WeaponDefinition = get_def(StringName(String(weapon_id) + "_up"))
	return up if up != null and up.base_id == weapon_id else null


# The weapon an upgraded definition was forged from (itself for a base weapon).
static func base_of(weapon_id: StringName) -> StringName:
	var d: WeaponDefinition = get_def(weapon_id)
	return d.base_id if d != null and d.base_id != &"" else weapon_id


static func can_upgrade(weapon_id: StringName) -> bool:
	return upgrade_of(weapon_id) != null
