# LazarusForge — the upgrade machine (GAME_DESIGN §9.2; DEVELOPMENT_PLAN Step 11A scope 2). An
# industrial anvil-press built around a glowing vesperite conduit: a base anvil, two press columns,
# a press head that hammers during the sequence, the conduit core between the columns, arc lines
# that flicker while forging and a flash that ramps green -> gold at the end. During OFFER the
# upgraded weapon (with its camo) floats and turns above the anvil. Prompts: insert (5000 / free
# with a Free Upgrade), "In use", "Take <name>" for the owner. Procedural greybox+ (final authored
# mesh in Step 13 replaces `_build_visual`; the interface stays).
# Authority: HOST executes through ForgeSystem; presentation reads the replicated job everywhere.
class_name LazarusForge
extends Interactable

var system: ForgeSystem = null
var index: int = 0

var _head: Node3D = null
var _core_mat: StandardMaterial3D = null
var _flash: OmniLight3D = null
var _arcs: Array[MeshInstance3D] = []
var _float_root: Node3D = null
var _float_model: Node3D = null
var _float_id: StringName = &""
var _label: Label3D = null
var _t: float = 0.0
var _last_hammer: int = -1
var _was_phase: int = ForgeSystem.Phase.IDLE


func _ready() -> void:
	super()
	hold_time = 0.5
	use_radius = 2.4
	ping_kind = &"machine"
	ping_label = "Lazarus Forge"
	prompt = "forge"
	_build_visual()
	if system != null:
		system.job_started.connect(_on_job_started)
		system.job_ended.connect(_on_job_ended)


func focus_point() -> Vector3:
	return global_position + Vector3.UP * 1.1


func is_available(_player: PlayerCharacter) -> bool:
	return system != null


func _held(player: PlayerCharacter) -> StringName:
	var ws: WeaponSync = WeaponSync.instance(self)
	if ws != null and WeaponSync.is_authority() and ws.loadouts.has(player.peer_id):
		return StringName((ws.loadouts[player.peer_id] as Dictionary)["current"])
	var d: WeaponDefinition = player.weapons.held_def() if player.weapons != null else null
	return d.id if d != null else &""


func get_cost(player: PlayerCharacter) -> int:
	if system == null or system.phase(index) != ForgeSystem.Phase.IDLE:
		return 0
	var held: StringName = _held(player)
	return system.cost() if WeaponCatalog.can_upgrade(held) else 0


func get_prompt(player: PlayerCharacter) -> String:
	if system == null:
		return ""
	if not system.is_unlocked():
		return "The Lazarus Forge is dormant"
	match system.phase(index):
		ForgeSystem.Phase.FORGING:
			return "Forging..." if int(system.job_of(index)[0]) == player.peer_id else "In use"
		ForgeSystem.Phase.OFFER:
			if int(system.job_of(index)[0]) != player.peer_id:
				return "In use"
			var up: WeaponDefinition = WeaponCatalog.get_def(StringName(system.job_of(index)[2]))
			return "Hold [F] to take %s" % (up.display_name if up != null else "weapon")
	var held: StringName = _held(player)
	if not WeaponCatalog.can_upgrade(held):
		return "This weapon cannot be upgraded"
	if system.free_pending():
		return "Hold [F] to upgrade your weapon [FREE]"
	return "Hold [F] to upgrade your weapon [%d]" % system.cost()


func host_check(peer_id: int, player: PlayerCharacter) -> String:
	return system.host_check(index, peer_id, _held(player)) if system != null else "invalid"


func host_execute(peer_id: int, player: PlayerCharacter) -> bool:
	return system != null and system.host_use(index, peer_id, _held(player))


# --- presentation --------------------------------------------------------------------------------


func _on_job_started(forge: int, _peer: int, _up: StringName) -> void:
	if forge == index:
		Audio.play_event_3d(&"forge_insert", global_position + Vector3.UP)
		Audio.play_event_3d(&"forge_charge", global_position + Vector3.UP)


func _on_job_ended(forge: int, taken: bool) -> void:
	if forge != index:
		return
	Audio.play_event_3d(&"forge_take" if taken else &"forge_lost", global_position + Vector3.UP)
	_clear_float()


func _process(delta: float) -> void:
	_t += delta
	if system == null:
		return
	var ph: int = system.phase(index)
	var jt: float = system.job_time(index)
	var unlocked: bool = system.is_unlocked()
	# Core: dim and slow when dormant, bright pulse when unlocked, blazing while forging.
	var pulse: float = 0.5 + 0.5 * sin(_t * (6.0 if ph == ForgeSystem.Phase.FORGING else 2.0))
	var energy: float = 0.4 if not unlocked else (1.4 + pulse)
	if ph == ForgeSystem.Phase.FORGING:
		energy = 3.0 + 2.0 * pulse
	_core_mat.emission_energy_multiplier = energy
	# Press head: hammers twice a second while forging, rests up otherwise.
	var head_y: float = 2.15
	if ph == ForgeSystem.Phase.FORGING:
		var beat: float = fmod(jt * 2.0, 1.0)
		head_y = lerpf(2.15, 1.38, smoothstep(0.55, 0.7, beat) * (1.0 - smoothstep(0.75, 1.0, beat)))
		var hit: int = int(jt * 2.0)
		if beat > 0.68 and hit != _last_hammer:
			_last_hammer = hit
			Audio.play_event_3d(&"forge_hammer", global_position + Vector3.UP * 1.3)
	_head.position.y = lerpf(_head.position.y, head_y, clampf(delta * 30.0, 0.0, 1.0))
	for i: int in _arcs.size():
		var a: MeshInstance3D = _arcs[i]
		a.visible = ph == ForgeSystem.Phase.FORGING and fmod(_t * 13.0 + i * 0.37, 1.0) < 0.55
		a.rotation.y = _t * (3.0 + i) + i
	# Flash: green ramp over the sequence, gold burst at the end, soft gold glow during the offer.
	var flash: float = 0.0
	var col: Color = Color(0.3, 1.0, 0.5)
	if ph == ForgeSystem.Phase.FORGING:
		flash = 1.0 + 3.0 * jt / ForgeSystem.FORGE_TIME
		if jt > ForgeSystem.FORGE_TIME - 0.6:
			col = Color(0.3, 1.0, 0.5).lerp(Color(1.0, 0.8, 0.3), (jt - ForgeSystem.FORGE_TIME + 0.6) / 0.6)
			flash = 8.0
	elif ph == ForgeSystem.Phase.OFFER:
		col = Color(1.0, 0.8, 0.35)
		flash = 1.5 + pulse
	_flash.light_color = col
	_flash.light_energy = flash
	if ph == ForgeSystem.Phase.OFFER and _was_phase == ForgeSystem.Phase.FORGING:
		Audio.play_event_3d(&"forge_done", global_position + Vector3.UP)
	_was_phase = ph
	_update_float(ph)


func _update_float(ph: int) -> void:
	if ph != ForgeSystem.Phase.OFFER:
		if _float_model != null:
			_clear_float()
		return
	var up_id: StringName = StringName(system.job_of(index)[2])
	if _float_id != up_id:
		_clear_float()
		var def: WeaponDefinition = WeaponCatalog.get_def(up_id)
		if def == null:
			return
		_float_model = def.world_scene.instantiate() as Node3D if def.world_scene != null else GreyboxGun.build(def, 1)
		_float_model.scale = Vector3.ONE * (2.0 if def.world_scene != null else 1.7)
		WeaponCamo.apply(_float_model, def)
		_float_root.add_child(_float_model)
		_float_id = up_id
		_label.text = def.display_name
	var left: float = ForgeSystem.FORGE_TIME + ForgeSystem.OFFER_TIME - system.job_time(index)
	_float_root.visible = left > 3.0 or fmod(_t * 6.0, 1.0) < 0.6  # blink before it's lost
	_float_root.position.y = 1.75 + sin(_t * 2.0) * 0.06
	_float_root.rotation.y = _t * 0.9
	_label.visible = true


func _clear_float() -> void:
	if _float_model != null:
		_float_model.queue_free()
	_float_model = null
	_float_id = &""
	if _label != null:
		_label.visible = false


func _build_visual() -> void:
	var iron: StandardMaterial3D = _mat(Color(0.18, 0.18, 0.2), 0.8, 0.45)
	var brass: StandardMaterial3D = _mat(Color(0.55, 0.42, 0.2), 0.9, 0.35)
	var dark: StandardMaterial3D = _mat(Color(0.08, 0.08, 0.09), 0.5, 0.7)
	_core_mat = _mat(Color(0.2, 0.9, 0.45), 0.0, 0.3)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(0.3, 1.0, 0.55)
	# Base plinth + anvil.
	_box("Plinth", Vector3(2.6, 0.35, 1.8), Vector3(0, 0.175, 0), dark)
	_box("AnvilFoot", Vector3(1.1, 0.5, 0.7), Vector3(0, 0.6, 0), iron)
	_box("AnvilFace", Vector3(1.6, 0.25, 0.8), Vector3(0, 0.98, 0), iron)
	_box("AnvilHorn", Vector3(0.5, 0.16, 0.3), Vector3(1.0, 0.98, 0), iron)
	# Press columns + crossbeam.
	for side: float in [-1.0, 1.0]:
		_box("Column", Vector3(0.28, 3.0, 0.28), Vector3(side * 1.1, 1.85, -0.55), brass)
		_box("Column", Vector3(0.28, 3.0, 0.28), Vector3(side * 1.1, 1.85, 0.55), brass)
		_cyl("Coil", 0.2, 0.9, Vector3(side * 1.1, 1.2, 0.0), _core_mat)
	_box("Crossbeam", Vector3(2.6, 0.35, 1.4), Vector3(0, 3.35, 0), brass)
	# Vesperite conduit: a tall crystal tube feeding the press from above.
	_cyl("Conduit", 0.16, 1.0, Vector3(0, 3.0, 0), _core_mat)
	var crystal: MeshInstance3D = _cyl("CoreCrystal", 0.3, 0.6, Vector3(0, 3.85, 0), _core_mat)
	crystal.rotation.z = 0.0
	# Press head (animated).
	_head = Node3D.new()
	_head.name = "PressHead"
	_head.position = Vector3(0, 2.15, 0)
	add_child(_head)
	var hm: MeshInstance3D = MeshInstance3D.new()
	var hb: BoxMesh = BoxMesh.new()
	hb.size = Vector3(1.0, 0.5, 0.7)
	hm.mesh = hb
	hm.material_override = iron
	_head.add_child(hm)
	var rod: MeshInstance3D = MeshInstance3D.new()
	var rm: CylinderMesh = CylinderMesh.new()
	rm.top_radius = 0.08
	rm.bottom_radius = 0.08
	rm.height = 1.0
	rod.mesh = rm
	rod.position.y = 0.6
	rod.material_override = brass
	_head.add_child(rod)
	# Arcs: thin bright planes that flicker around the anvil while forging.
	var arc_mat: StandardMaterial3D = StandardMaterial3D.new()
	arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_mat.albedo_color = Color(0.6, 1.0, 0.75)
	arc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i: int in 4:
		var a: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(0.04, 1.2)
		a.mesh = q
		a.material_override = arc_mat
		a.position = Vector3(0.0, 1.6, 0.0)
		a.rotation.z = 0.9 + i * 0.45
		a.visible = false
		add_child(a)
		_arcs.append(a)
	_flash = OmniLight3D.new()
	_flash.position = Vector3(0, 1.6, 0)
	_flash.omni_range = 8.0
	_flash.light_energy = 0.0
	add_child(_flash)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.position = Vector3(0, 3.6, 0)
	glow.light_color = Color(0.35, 1.0, 0.55)
	glow.light_energy = 0.8
	glow.omni_range = 6.0
	add_child(glow)
	_float_root = Node3D.new()
	_float_root.name = "Offer"
	_float_root.position = Vector3(0, 1.75, 0)
	add_child(_float_root)
	_label = Label3D.new()
	_label.position = Vector3(0, 2.45, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.004
	_label.modulate = Color(1.0, 0.85, 0.4)
	_label.visible = false
	add_child(_label)
	var sign: Label3D = Label3D.new()
	sign.text = "LAZARUS FORGE"
	sign.position = Vector3(0, 3.35, 0.72)
	sign.pixel_size = 0.005
	sign.modulate = Color(0.45, 1.0, 0.65)
	add_child(sign)


func _box(n: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _cyl(n: String, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


static func _mat(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m
