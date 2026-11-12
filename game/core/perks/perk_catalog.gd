# PerkCatalog — lookup of PerkDefinitions from the Content registry (content/perks/*.tres).
# Authority: read-only data.
class_name PerkCatalog
extends RefCounted


static func get_def(perk_id: StringName) -> PerkDefinition:
	return Content.get_def(&"PerkDefinition", perk_id) as PerkDefinition


# Every perk, in sort order (machine / HUD / debug listing order; identical on every peer).
static func all() -> Array[PerkDefinition]:
	var out: Array[PerkDefinition] = []
	for res: Resource in Content.get_all(&"PerkDefinition"):
		out.append(res as PerkDefinition)
	out.sort_custom(
		func(a: PerkDefinition, b: PerkDefinition) -> bool:
			return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.id) < String(b.id)
	)
	return out


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: PerkDefinition in all():
		out.append(d.id)
	return out


static func by_marker(marker_id: StringName) -> PerkDefinition:
	for d: PerkDefinition in all():
		if d.marker_id == marker_id:
			return d
	return null
