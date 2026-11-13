# CarryLoadout — the pistol-only loadout of a CarryItem carrier (DEVELOPMENT_PLAN Step 14 scope 5):
# the other weapons are hidden from the loadout (the owner cannot switch to them) and come back when
# the item is dropped; a temporary M1911 is added if the player owns no pistol. Weapons gained while
# carrying are kept. Works on WeaponSync's host loadout dictionary.
# Authority: HOST (WeaponSync.host_set_carry broadcasts the result).
class_name CarryLoadout
extends RefCounted


# Returns true when the loadout changed.
static func apply(ws: WeaponSync, lo: Dictionary, peer_id: int, on: bool) -> bool:
	if bool(lo.get("carry", false)) == on:
		return false
	lo["carry"] = on
	if on:
		var best: WeaponDefinition = null
		for wid: Variant in lo["ids"]:
			var d: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
			if d != null and d.weapon_class == WeaponDefinition.WeaponClass.PISTOL:
				if best == null or d.damage * d.rpm > best.damage * best.rpm:
					best = d
		lo["carry_ids"] = (lo["ids"] as Array).duplicate()
		lo["pre_carry"] = lo["current"]
		if best == null:
			best = WeaponCatalog.get_def(WeaponSync.LAST_STAND_PISTOL)
			if best == null:
				return false
			lo["carry_added"] = best.id
			ws.validator.give(peer_id, best)
		lo["ids"] = [best.id]
		lo["current"] = best.id
	else:
		var held: Array = lo["ids"]
		var full: Array = (lo.get("carry_ids", held) as Array).duplicate()
		for wid: Variant in held:
			if not full.has(wid) and StringName(wid) != StringName(lo.get("carry_added", &"")):
				full.append(wid)
		var added: StringName = StringName(lo.get("carry_added", &""))
		if added != &"" and not full.has(added):
			ws.validator.take(peer_id, added)
		lo["ids"] = full
		lo.erase("carry_ids")
		lo.erase("carry_added")
		var back: StringName = StringName(lo.get("pre_carry", &""))
		lo["current"] = back if full.has(back) else (StringName(full[0]) if not full.is_empty() else &"")
	return true
