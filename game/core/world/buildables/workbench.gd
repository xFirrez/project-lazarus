# Workbench — where a buildable is assembled (DEVELOPMENT_PLAN Step 12A scope 3; Vesper Peak's Lab
# Workbench WB, Z11): with every part collected, hold `build_time` (power when required) to build;
# the built item then rests on the bench until the first player who doesn't own it takes it. The
# bench shows the collected parts laid out and, once built, the item itself. After the claim the
# bench is spent (the item joins the Relic Box pool through `unlock_flag`).
# Authority: HOST executes builds / claims (BuildableSystem); every peer presents from the flags.
class_name Workbench
extends Interactable

var system: BuildableSystem = null
var def: BuildableDef = null
var _slots: Dictionary = {}  # part -> MeshInstance3D on the bench
var _item: Node3D = null
var _label: Label3D = null


func _ready() -> void:
	super()
	hold_time = def.build_time
	use_radius = 2.2
	ping_kind = &"machine"
	ping_label = "%s workbench" % def.display_name
	_build_visual()
	refresh()


func _state() -> int:
	return system.state(def.id) if system != null else BuildableSystem.State.COLLECTING


func is_available(_player: PlayerCharacter) -> bool:
	return _state() != BuildableSystem.State.CLAIMED


func get_prompt(player: PlayerCharacter) -> String:
	match _state():
		BuildableSystem.State.BUILT:
			return "Hold [F] to take the %s" % def.display_name
		BuildableSystem.State.COLLECTING:
			if not system.all_parts(def.id):
				return "%s: parts %d / %d" % [def.display_name, system.parts_collected(def.id), def.parts.size()]
	return super(player)


func host_check(peer_id: int, _player: PlayerCharacter) -> String:
	match _state():
		BuildableSystem.State.COLLECTING:
			if not system.all_parts(def.id):
				return "Missing parts"
			if def.requires_power and not Power.is_on():
				return "Requires power"
		BuildableSystem.State.BUILT:
			if system.match_node.weapons != null and system.match_node.weapons.host_owns(peer_id, def.reward_weapon):
				return "You already have one"
		_:
			return "Spent"
	return ""


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	if _state() == BuildableSystem.State.COLLECTING:
		return system.host_build(peer_id, def)
	return system.host_claim(peer_id, def)


func refresh() -> void:
	prompt = "build the %s" % def.display_name
	hold_time = def.build_time if _state() == BuildableSystem.State.COLLECTING else 0.4
	for p: Variant in _slots:
		(_slots[p] as Node3D).visible = system.has_part(def.id, p) and _state() == BuildableSystem.State.COLLECTING
	if _item != null:
		_item.visible = _state() == BuildableSystem.State.BUILT
	if _label != null:
		_label.text = (
			"%s — %s"
			% [
				"LAB WORKBENCH",
				["%d / %d PARTS" % [system.parts_collected(def.id), def.parts.size()], "READY", "EMPTY"][_state()]
			]
		)


func _build_visual() -> void:
	var table: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.6, 0.08, 0.8)
	table.mesh = bm
	table.position = Vector3(0, 0.9, 0)
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.45, 0.47, 0.5)
	steel.metallic = 0.6
	table.material_override = steel
	add_child(table)
	for x: float in [-0.7, 0.7]:
		for z: float in [-0.32, 0.32]:
			var leg: MeshInstance3D = MeshInstance3D.new()
			var lm: BoxMesh = BoxMesh.new()
			lm.size = Vector3(0.06, 0.9, 0.06)
			leg.mesh = lm
			leg.position = Vector3(x, 0.45, z)
			leg.material_override = steel
			add_child(leg)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(0.55, 0.9, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.4, 0.85, 1.0)
	var i: int = 0
	for p: StringName in def.parts:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var pm: BoxMesh = BoxMesh.new()
		pm.size = Vector3(0.2, 0.08, 0.14)
		mi.mesh = pm
		mi.material_override = glow
		mi.position = Vector3(-0.5 + 0.5 * i, 0.98, 0)
		add_child(mi)
		_slots[p] = mi
		i += 1
	var reward: WeaponDefinition = WeaponCatalog.get_def(def.reward_weapon)
	if reward != null:
		_item = GreyboxGun.build(reward, 1)
		_item.position = Vector3(0, 1.05, 0)
		_item.rotation.y = PI * 0.5
		_item.scale = Vector3.ONE * 1.6
		add_child(_item)
	_label = Label3D.new()
	_label.font_size = 28
	_label.pixel_size = 0.002
	_label.position = Vector3(0, 1.3, -0.4)
	_label.modulate = Color(0.7, 0.95, 1.0)
	add_child(_label)
