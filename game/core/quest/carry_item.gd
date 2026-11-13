# CarryItem — a generic carried objective item (DEVELOPMENT_PLAN Step 14 scope 5): a player picks it
# up with interact; while carried the carrier cannot sprint (PlayerStats `no_sprint`), holds only a
# pistol (WeaponSync carry restriction), glows and is prioritised by zombies (`target_bias` metres
# subtracted from their path distance to the carrier). The carrier drops it with the drop key
# (`carry_drop`, X) — a teammate can pick it up again (passing) — and it is auto-dropped when the
# carrier is downed or leaves. Objectives move it home (`host_reset`) or hide it (`host_set_present`).
# Shared state = MatchSession flags: "carry.<id>.by" carrier peer (0 = on the ground),
# "carry.<id>.pos" ground position, "carry.<id>.on" present in the world.
# Authority: HOST picks up / drops; every peer presents and applies the carrier restrictions.
class_name CarryItem
extends Interactable

const SOURCE: StringName = &"carry"

var item_id: StringName = &""
var display_name: String = "item"
var home: Vector3 = Vector3.ZERO
var target_bias: float = 12.0
var model: Node3D = null  # the map's visual (default: a glowing orb)
var quest: QuestSystem = null
var picks: int = 0  # host (tests)
var drops: int = 0

var _applied_to: int = 0  # peer the restrictions are applied to on this peer
var _light: OmniLight3D = null
var _t: float = 0.0


func _ready() -> void:
	super()
	prompt = "pick up %s" % display_name
	hold_time = 0.5
	use_radius = 2.2
	ping_label = display_name
	if model == null:
		model = _default_model()
	add_child(model)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 1.0, 0.7)
	_light.light_energy = 1.2
	_light.omni_range = 5.0
	add_child(_light)
	if quest != null:
		quest.register_carry(self)
		if quest.match_node != null and quest.match_node.session != null:
			quest.match_node.session.flag_changed.connect(_on_flag)
	global_position = home


func key(suffix: String) -> String:
	return "carry.%s.%s" % [item_id, suffix]


func _flag(suffix: String, default: Variant) -> Variant:
	return quest.flag(key(suffix), default) if quest != null else default


func carrier() -> int:
	return int(_flag("by", 0))


func is_present() -> bool:
	return bool(_flag("on", false))


func ground_position() -> Vector3:
	return _flag("pos", home)


func is_available(player: PlayerCharacter) -> bool:
	return is_present() and carrier() == 0 and player != null and not player.health.is_downed


func host_check(peer_id: int, _player: PlayerCharacter) -> String:
	if not is_present():
		return "Gone"
	if carrier() != 0:
		return "Already carried"
	for other: CarryItem in quest.carry_items.values():
		if other != self and other.carrier() == peer_id:
			return "Hands full"
	return ""


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	return host_pick(peer_id)


# --- host -----------------------------------------------------------------------------------------


func host_pick(peer_id: int) -> bool:
	if not QuestSystem.is_authority() or not is_present() or carrier() != 0:
		return false
	picks += 1
	quest.host_set(key("by"), peer_id)
	quest.host_event(&"carry", {"item": item_id, "event": &"picked", "peer": peer_id})
	return true


func host_drop(peer_id: int) -> void:
	if not QuestSystem.is_authority() or carrier() != peer_id or peer_id == 0:
		return
	var at: Vector3 = global_position
	var p: PlayerCharacter = _avatar(peer_id)
	if p != null:
		at = _floor_below(p.global_position + Vector3.UP * 0.5)
	drops += 1
	quest.host_set(key("pos"), at)
	quest.host_set(key("by"), 0)
	quest.host_event(&"carry", {"item": item_id, "event": &"dropped", "peer": peer_id, "position": at})


func host_reset() -> void:
	if not QuestSystem.is_authority():
		return
	quest.host_set(key("pos"), home)
	quest.host_set(key("by"), 0)


func host_set_present(on: bool) -> void:
	if not QuestSystem.is_authority():
		return
	if not on:
		quest.host_set(key("by"), 0)
	quest.host_set(key("on"), on)


# --- every peer -----------------------------------------------------------------------------------


func _on_flag(k: String, _value: Variant) -> void:
	if k.begins_with("carry.%s." % item_id):
		_apply_restrictions()


func _apply_restrictions() -> void:
	var by: int = carrier() if is_present() else 0
	if by == _applied_to:
		return
	var old: PlayerCharacter = _avatar(_applied_to)
	if old != null:
		old.stats().clear_source(SOURCE)
		old.remove_meta(&"target_bias")
		old.remove_meta(&"carrying")
	_applied_to = by
	var p: PlayerCharacter = _avatar(by)
	if p != null:
		p.stats().set_source(SOURCE, [StatModifier.make(PlayerStats.NO_SPRINT, StatModifier.Op.ADD, 1.0)])
		p.set_meta(&"target_bias", target_bias)
		p.set_meta(&"carrying", item_id)
	var m: Match = quest.match_node if quest != null else null
	if m != null and m.weapons != null and QuestSystem.is_authority():
		if old != null:
			m.weapons.host_set_carry(old.peer_id, false)
		if p != null:
			m.weapons.host_set_carry(p.peer_id, true)
	Audio.play_event_3d(&"carry_pick" if by != 0 else &"carry_drop", global_position)


func _process(delta: float) -> void:
	_t += delta
	visible = is_present()
	if not visible:
		return
	_apply_restrictions()
	var p: PlayerCharacter = _avatar(carrier())
	if p != null:
		var fwd: Vector3 = -p.global_basis.z
		global_position = p.global_position + Vector3.UP * 1.1 + fwd * 0.45
		if p.peer_id == Net.local_id() and Input.is_action_just_pressed(&"carry_drop"):
			quest.request_drop(item_id)
	else:
		global_position = ground_position()
	if model != null:
		model.position.y = 0.35 + sin(_t * 2.2) * 0.06 if p == null else 0.0
		model.rotation.y += delta * 0.9
	_light.light_energy = 1.0 + 0.4 * sin(_t * 5.0)


func _avatar(peer_id: int) -> PlayerCharacter:
	if peer_id == 0 or quest == null or quest.match_node == null or quest.match_node.players == null:
		return null
	return quest.match_node.players.avatars.get(peer_id, null)


func _floor_below(from: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 6.0, 1)
	var hit: Dictionary = space.intersect_ray(q)
	return (hit["position"] as Vector3) if not hit.is_empty() else from


func _default_model() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "CarryModel"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	mi.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 1.0, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 1.0, 0.6)
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	root.add_child(mi)
	return root
