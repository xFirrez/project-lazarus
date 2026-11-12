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
		return ws.host_owns(player.peer_id, weapon_id)
	var wc: WeaponController = player.weapons
	if wc == null:
		return false
	if wc.inventory.slot_of(weapon_id) >= 0:
		return true
	if wc.inventory.melee_def != null and wc.inventory.melee_def.id == weapon_id:
		return true
	return wc.placeable_def != null and wc.placeable_def.id == weapon_id


# Equipment (Ice Axe, tripmines) is bought once; guns can be re-bought as ammo.
func is_equipment() -> bool:
	var d: WeaponDefinition = definition()
	return d != null and d.is_equipment()


func get_cost(player: PlayerCharacter) -> int:
	var d: WeaponDefinition = definition()
	if d == null:
		return 0
	if is_equipment():
		return 0 if owns(player) else d.cost
	return d.cost / 2 if owns(player) else d.cost


func get_prompt(player: PlayerCharacter) -> String:
	var d: WeaponDefinition = definition()
	var label: String = d.display_name if d != null else String(weapon_id)
	if owns(player) and is_equipment():
		return "%s owned" % label
	if owns(player):
		return "Hold [F] for %s ammo [%d]" % [label, get_cost(player)]
	return "Hold [F] to buy %s [%d]" % [label, get_cost(player)]


func host_check(peer_id: int, player: PlayerCharacter) -> String:
	var d: WeaponDefinition = definition()
	if d == null:
		return "invalid"
	if owns(player) and is_equipment():
		return "Already owned"
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


# VESPER_PEAK §5.1: a stenciled military silhouette on a canvas tarp, with a crate below.
func _build_visual() -> void:
	var d: WeaponDefinition = definition()
	var tarp: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.4, 0.75, 0.02)
	tarp.mesh = bm
	var tmat: StandardMaterial3D = StandardMaterial3D.new()
	tmat.albedo_color = Color(0.45, 0.43, 0.32)  # olive-drab canvas
	tmat.roughness = 1.0
	tarp.material_override = tmat
	add_child(tarp)
	for i: int in 4:  # grommets
		var g: MeshInstance3D = MeshInstance3D.new()
		var gm: BoxMesh = BoxMesh.new()
		gm.size = Vector3(0.04, 0.04, 0.01)
		g.mesh = gm
		g.position = Vector3(-0.66 + 1.32 * (i % 2), 0.34 - 0.68 * (i / 2), 0.015)
		g.material_override = _flat(Color(0.6, 0.55, 0.4))
		add_child(g)
	var stencil: StandardMaterial3D = _flat(Color(0.08, 0.08, 0.07))
	for part: Array in _silhouette(d):
		var mi: MeshInstance3D = MeshInstance3D.new()
		var pm: BoxMesh = BoxMesh.new()
		pm.size = Vector3((part[1] as Vector2).x, (part[1] as Vector2).y, 0.005)
		mi.mesh = pm
		var p: Vector2 = part[0]
		mi.position = Vector3(p.x, p.y + 0.06, 0.013)
		mi.rotation.z = float(part[2])
		mi.material_override = stencil
		add_child(mi)
	var crate: MeshInstance3D = MeshInstance3D.new()
	var cm: BoxMesh = BoxMesh.new()
	cm.size = Vector3(0.8, 0.45, 0.45)
	crate.mesh = cm
	crate.position = Vector3(0, -1.275, 0.25)  # wall-buys hang 1.5 m above the floor
	crate.material_override = _flat(Color(0.35, 0.27, 0.16))
	add_child(crate)
	var label: Label3D = Label3D.new()
	label.text = "%s  %d" % [d.display_name.to_upper() if d != null else String(weapon_id), d.cost if d != null else 0]
	label.font_size = 34
	label.position = Vector3(0, -0.26, 0.03)
	label.modulate = Color(0.1, 0.1, 0.09)
	label.outline_size = 0
	add_child(label)


# Stencil pieces [centre, size, roll] by weapon class (a readable silhouette, not a model).
static func _silhouette(d: WeaponDefinition) -> Array:
	if d == null:
		return []
	match d.weapon_class:
		WeaponDefinition.WeaponClass.PISTOL:
			return [[Vector2(0.0, 0.05), Vector2(0.4, 0.09), 0.0], [Vector2(0.12, -0.06), Vector2(0.09, 0.2), -0.25]]
		WeaponDefinition.WeaponClass.MELEE:
			return [[Vector2(0.0, 0.0), Vector2(0.06, 0.55), 0.6], [Vector2(-0.14, 0.18), Vector2(0.3, 0.07), 0.6]]
		WeaponDefinition.WeaponClass.PLACEABLE:
			return [[Vector2(0.0, 0.0), Vector2(0.4, 0.24), 0.0], [Vector2(-0.12, -0.17), Vector2(0.04, 0.12), 0.3]]
		WeaponDefinition.WeaponClass.SHOTGUN:
			return [
				[Vector2(-0.1, 0.06), Vector2(0.95, 0.06), 0.0],
				[Vector2(0.42, 0.0), Vector2(0.3, 0.1), -0.12],
				[Vector2(-0.2, 0.0), Vector2(0.22, 0.06), 0.0]
			]
		WeaponDefinition.WeaponClass.PRECISION:
			return [
				[Vector2(0.0, 0.03), Vector2(1.15, 0.07), 0.0],
				[Vector2(0.0, 0.11), Vector2(0.36, 0.06), 0.0],
				[Vector2(0.45, -0.03), Vector2(0.3, 0.11), -0.1]
			]
	return [
		[Vector2(0.0, 0.05), Vector2(0.85, 0.08), 0.0],
		[Vector2(0.38, 0.0), Vector2(0.25, 0.11), -0.1],
		[Vector2(-0.02, -0.08), Vector2(0.08, 0.2), 0.2],
		[Vector2(0.12, -0.07), Vector2(0.06, 0.15), -0.3]
	]


static func _flat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m
