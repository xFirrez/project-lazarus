# FreePerkCrate — the free Vigor Tonic interface (DEVELOPMENT_PLAN Step 10 scope 7; used by the S1
# Director's Office reward in Step 14): an interactable crate that, once its MatchSession flag
# `enable_flag` is truthy (or always, when empty), gives each player one free perk they don't hold
# (random, or `perk_id`), ignoring price, power and the perk cap. Claims are a MatchSession flag
# `free_crate.<name>.<player uid>` so they ride late join / reconnect and the state hash.
# Authority: HOST executes through PerkSystem.host_grant_free.
class_name FreePerkCrate
extends Interactable

@export var enable_flag: String = ""
@export var perk_id: StringName = &""
# S1 (VESPER_PEAK §3): the Director's Office crate respects the perk cap.
@export var respect_cap: bool = false


func _ready() -> void:
	super()
	prompt = "take a free Vigor Tonic"
	hold_time = 0.6
	ping_kind = &"machine"
	ping_label = "Free Vigor Tonic"
	_build_visual()


func _session() -> MatchSession:
	return Match.current.session if Match.current != null else null


func claim_key(peer_id: int) -> String:
	var info: Dictionary = Net.peers.get(peer_id, {})
	return "free_crate.%s.%s" % [name, String(info.get("uid", str(peer_id))).substr(0, 8)]


func is_enabled() -> bool:
	var s: MatchSession = _session()
	return enable_flag == "" or (s != null and bool(s.flag(enable_flag, false)))


func claimed(peer_id: int) -> bool:
	var s: MatchSession = _session()
	return s != null and bool(s.flag(claim_key(peer_id), false))


func is_available(player: PlayerCharacter) -> bool:
	return is_enabled() and not claimed(player.peer_id)


func host_check(peer_id: int, _player: PlayerCharacter) -> String:
	var m: Match = Match.current
	if respect_cap and m != null and m.perks != null and m.perks.ids_of(peer_id).size() >= m.perks.cap():
		return "Too many tonics"
	return ""


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	var m: Match = Match.current
	if m == null or m.perks == null:
		return false
	if m.perks.host_grant_free(peer_id, perk_id) == &"":
		return false
	m.session.host_set_flag(claim_key(peer_id), true)
	return true


func _build_visual() -> void:
	var crate: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.7, 0.45, 0.5)
	crate.mesh = bm
	crate.position = Vector3(0, 0.225, 0)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.3, 0.18)
	m.roughness = 0.9
	crate.material_override = m
	add_child(crate)
	var l: Label3D = Label3D.new()
	l.text = "VIGOR TONIC — COMPLIMENTARY"
	l.font_size = 28
	l.pixel_size = 0.002
	l.position = Vector3(0, 0.3, 0.26)
	l.modulate = Color(1.0, 0.85, 0.5)
	add_child(l)
