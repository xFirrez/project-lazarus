# WallBuy — a weapon bought off the wall (GAME_DESIGN §6.2): the definition's cost for the weapon,
# half of it for an ammo refill when already owned (refused when full). Builds a greybox chalk
# board with the weapon's silhouette and name/price so it reads in-world.
# Authority: HOST executes through WeaponSync (loadout + validator ammo); prompts are local.
class_name WallBuy
extends Interactable

@export var weapon_id: StringName = &""


func _ready() -> void:
	super()
	hold_time = 0.35
	_build_visual()


func definition() -> WeaponDefinition:
	return WeaponCatalog.get_def(weapon_id)


func owns(player: PlayerCharacter) -> bool:
	var ws: WeaponSync = WeaponSync.instance(self)
	if ws != null and WeaponSync.is_authority() and ws.loadouts.has(player.peer_id):
		return ((ws.loadouts[player.peer_id] as Dictionary)["ids"] as Array).has(weapon_id)
	return player.weapons != null and player.weapons.inventory.slot_of(weapon_id) >= 0


func get_cost(player: PlayerCharacter) -> int:
	var d: WeaponDefinition = definition()
	if d == null:
		return 0
	return d.cost / 2 if owns(player) else d.cost


func get_prompt(player: PlayerCharacter) -> String:
	var d: WeaponDefinition = definition()
	var label: String = d.display_name if d != null else String(weapon_id)
	if owns(player):
		return "Hold [F] for %s ammo [%d]" % [label, get_cost(player)]
	return "Hold [F] to buy %s [%d]" % [label, get_cost(player)]


func host_check(peer_id: int, player: PlayerCharacter) -> String:
	var d: WeaponDefinition = definition()
	if d == null:
		return "invalid"
	if owns(player):
		var ws: WeaponSync = WeaponSync.instance(self)
		var a: Array = ws.validator.ammo(peer_id, weapon_id)
		if int(a[0]) >= d.mag_size and int(a[1]) >= d.reserve_max:
			return "Ammo full"
	return ""


func host_execute(peer_id: int, player: PlayerCharacter) -> bool:
	var ws: WeaponSync = WeaponSync.instance(self)
	if ws == null:
		return false
	if owns(player):
		ws.host_refill_weapon(peer_id, weapon_id)
		return true
	return ws.host_give(peer_id, weapon_id)


func _build_visual() -> void:
	var board: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.3, 0.6, 0.03)
	board.mesh = bm
	var bmat: StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.12, 0.13, 0.12)
	board.material_override = bmat
	add_child(board)
	var gun: MeshInstance3D = MeshInstance3D.new()
	var gm: BoxMesh = BoxMesh.new()
	gm.size = Vector3(1.0, 0.1, 0.04)
	gun.mesh = gm
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.85, 0.85, 0.8)
	gmat.emission_enabled = true
	gmat.emission = Color(0.4, 0.4, 0.38)
	gun.material_override = gmat
	gun.position = Vector3(0, 0.05, 0.03)
	add_child(gun)
	var label: Label3D = Label3D.new()
	var d: WeaponDefinition = definition()
	label.text = "%s  %d" % [d.display_name if d != null else String(weapon_id), d.cost if d != null else 0]
	label.font_size = 36
	label.position = Vector3(0, -0.2, 0.04)
	label.modulate = Color(0.9, 0.9, 0.85)
	add_child(label)
