# LoreLibrary — a map's lore and voice-over text (DEVELOPMENT_PLAN Step 14 scope 2 / 7), loaded from
# the JSON named by MapDefinition.lore_path (`maps/<map>/lore/lore.json`). Entry kinds:
#   doc   — a readable document {title, zone, body}; `journal` entries appear in the Journal
#   reel  — an audio reel {title, zone, lines: [[speaker, text, seconds], ...]} (subtitled VO)
#   vo    — a quest voice-over beat (same `lines`; not listed in the Journal)
#   clue  — an in-world readable that is not a collectible (the Lobby guestbook)
#   story — a Journal entry unlocked by an event (the "Requiem" summary)
# Authority: static data (every peer loads the same file).
class_name LoreLibrary
extends RefCounted

const KINDS: PackedStringArray = ["doc", "reel", "vo", "clue", "story"]

static var _cache: Dictionary = {}

var map_id: StringName = &""
var path: String = ""
var entries: Dictionary = {}  # id -> Dictionary
var order: Array[StringName] = []
var speakers: Dictionary = {}  # speaker -> {name, pitch, radio}


static func for_map(def: MapDefinition) -> LoreLibrary:
	if def == null or def.lore_path == "":
		var empty: LoreLibrary = LoreLibrary.new()
		empty.map_id = def.id if def != null else &""
		return empty
	return load_path(def.lore_path, def.id)


static func load_path(p: String, id: StringName = &"") -> LoreLibrary:
	if _cache.has(p):
		return _cache[p]
	var lib: LoreLibrary = LoreLibrary.new()
	lib.map_id = id
	lib.path = p
	var text: String = FileAccess.get_file_as_string(p)
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		lib.speakers = (data as Dictionary).get("speakers", {})
		for e: Variant in (data as Dictionary).get("entries", []):
			var d: Dictionary = e
			var eid: StringName = StringName(String(d.get("id", "")))
			if eid == &"":
				continue
			lib.entries[eid] = d
			lib.order.append(eid)
	else:
		Log.error(&"lore", "Cannot parse lore file %s" % p)
	_cache[p] = lib
	return lib


func entry(id: StringName) -> Dictionary:
	return entries.get(id, {})


func kind_of(id: StringName) -> String:
	return String(entry(id).get("kind", ""))


func ids_of_kind(kind: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in order:
		if kind_of(id) == kind:
			out.append(id)
	return out


# Journal-listed entries (documents, reels and story entries), in file order.
func journal_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in order:
		if bool(entry(id).get("journal", kind_of(id) in ["doc", "reel", "story"])):
			out.append(id)
	return out


func lines_of(id: StringName) -> Array:
	return entry(id).get("lines", [])


# Seconds the VO of an entry lasts (sum of its line durations).
func duration_of(id: StringName) -> float:
	var t: float = 0.0
	for l: Variant in lines_of(id):
		t += line_seconds(l as Array)
	return t


static func line_seconds(line: Array) -> float:
	if line.size() > 2:
		return float(line[2])
	return clampf(String(line[1]).length() * 0.065, 1.8, 9.0) if line.size() > 1 else 2.0


# Plain-text transcript ("SPEAKER: line" per line) of a reel / VO entry.
func transcript(id: StringName) -> String:
	var out: PackedStringArray = []
	for l: Variant in lines_of(id):
		var a: Array = l
		out.append("%s: %s" % [speaker_name(String(a[0])), String(a[1])])
	return "\n".join(out)


func speaker_name(speaker: String) -> String:
	return String((speakers.get(speaker, {}) as Dictionary).get("name", speaker))


func speaker_pitch(speaker: String) -> float:
	return float((speakers.get(speaker, {}) as Dictionary).get("pitch", 1.0))


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: StringName in order:
		var e: Dictionary = entry(id)
		var k: String = String(e.get("kind", ""))
		if not KINDS.has(k):
			errors.append("%s: bad kind '%s'" % [id, k])
		if String(e.get("title", "")) == "" and k != "vo":
			errors.append("%s: no title" % id)
		if k in ["doc", "clue", "story"] and String(e.get("body", "")).length() < 40:
			errors.append("%s: body too short" % id)
		if k in ["reel", "vo"]:
			var lines: Array = e.get("lines", [])
			if lines.is_empty():
				errors.append("%s: no lines" % id)
			for l: Variant in lines:
				if not (l is Array) or (l as Array).size() < 2 or not speakers.has(String((l as Array)[0])):
					errors.append("%s: bad line %s" % [id, str(l)])
	return errors
