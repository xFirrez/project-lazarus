# CharacterDefinition — one playable character (GAME_DESIGN §14): names, bio, identification
# colour (HUD points list, name tags, pings, markers), sleeve tint for the first-person arms and
# the third-person model scene. Discovered by the Content registry (content/characters/<id>/).
# Authority: read-only data identical on every peer.
class_name CharacterDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""  # short name used in prompts ("Hold [F] to revive Brandt")
@export var full_name: String = ""
@export var nationality: String = ""
@export_multiline var bio: String = ""
@export var color: Color = Color.WHITE  # identification colour (§13 "Player identification")
@export var sleeve_color: Color = Color(0.3, 0.3, 0.3)  # first-person arms / jacket tint
@export var skin_color: Color = Color(0.85, 0.68, 0.55)
@export var order: int = 0  # lobby order / default slot
@export_file("*.tscn") var model_scene: String = ""


# All characters sorted by `order` (lobby order).
static func all_sorted() -> Array[CharacterDefinition]:
	var out: Array[CharacterDefinition] = []
	for res: Resource in Content.get_all(&"CharacterDefinition"):
		out.append(res as CharacterDefinition)
	out.sort_custom(func(a: CharacterDefinition, b: CharacterDefinition) -> bool: return a.order < b.order)
	return out


static func ids_sorted() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CharacterDefinition in all_sorted():
		out.append(c.id)
	return out


static func get_def(char_id: StringName) -> CharacterDefinition:
	return Content.get_def(&"CharacterDefinition", char_id) as CharacterDefinition


# Character for a slot index when none was chosen (host bots, test entry points).
static func for_slot(slot: int) -> CharacterDefinition:
	var list: Array[CharacterDefinition] = all_sorted()
	return list[slot % list.size()] if not list.is_empty() else null
