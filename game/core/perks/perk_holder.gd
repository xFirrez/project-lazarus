# PerkHolder — the perks one player holds, in acquisition order (HUD caps), and their effect on the
# player's PlayerStats (each perk is a stat source named after its id). Lives on PlayerCharacter
# (`perk_holder`) on every peer; PerkSystem (host) decides the list and replicates it.
# Authority: mirror of host state; `set_ids` is called on every peer with the host's list.
class_name PerkHolder
extends RefCounted

signal perks_changed(ids: Array[StringName])

var ids: Array[StringName] = []
var stats: PlayerStats = PlayerStats.new()


func has(perk_id: StringName) -> bool:
	return ids.has(perk_id)


func count() -> int:
	return ids.size()


func set_ids(new_ids: Array) -> void:
	var next: Array[StringName] = []
	for v: Variant in new_ids:
		var pid: StringName = StringName(String(v))
		if not next.has(pid) and PerkCatalog.get_def(pid) != null:
			next.append(pid)
	if next == ids:
		return
	for old: StringName in ids:
		if not next.has(old):
			stats.clear_source(old)
	for pid: StringName in next:
		if not stats.has_source(pid):
			stats.set_source(pid, PerkCatalog.get_def(pid).modifiers)
	ids = next
	perks_changed.emit(ids)


func clear() -> void:
	set_ids([])


func id_strings() -> Array:
	var out: Array = []
	for pid: StringName in ids:
		out.append(String(pid))
	return out
