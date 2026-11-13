# VesperQuestWorld — the in-world objects of "Requiem for Lazarus" (VESPER_PEAK §7, DEVELOPMENT_PLAN
# Step 14): built on the EE MapMarkers during Match.setup (before the target / interaction scans, so
# every peer gets the same ids) and presented from the replicated `ee.*` / quest flags:
#   stage 1  radio console: three dials (interact +1, hold to scroll) + transmit; dial readout
#   stage 2a frozen fountain ice (QuestTarget) with the shard inside; shard pickup in the basin
#   stage 2b morgue drawers (4 glyphs), luminous symbols I-IV (visible only while the lab breaker H3
#            is on), the chained drawer + shard
#   stage 2c the marked Galvanic's glow; its dropped shard
#   stage 3  Soul Containment Pod (shards in, charge glow + gauge, two cables to reseat)
#   stage 4  the Heart (CarryItem, home = the pod); the core socket
#   stage 5  four vesperite nodes orbiting with the containment rings (QuestTargets)
#   stage 6  three stabilizer pylons (hold to repair), the ending moment (letterbox, flash, slow
#            audio), the reactor's calm colour and the storm's calm round
# The logic lives in the stage objectives (scripts/quest/stage*.gd); this node only builds and shows.
# Authority: presentation on every peer; interactables / targets forward to the host's objectives.
class_name VesperQuestWorld
extends Node3D

const GLYPHS: PackedStringArray = ["CROSS", "EYE", "MOON", "STAR"]
const ROMAN: PackedStringArray = ["I", "II", "III", "IV"]
const NODE_ORBIT_SPEED: float = 0.12  # rad/s, with the containment rings
const PYLON_MAX: float = 1000.0
const SHARDS: PackedStringArray = ["a", "b", "c"]
const GREEN: Color = Color(0.45, 1.0, 0.6)

var match_node: Match = null
var quest: QuestSystem = null
var markers: Dictionary = {}  # marker id -> MapMarker

var dials: Array[QuestInteractable] = []
var radio_tx: QuestInteractable = null
var ice: QuestTarget = null
var shard_pickups: Dictionary = {}  # "a" | "b" | "c" -> QuestInteractable
var drawers: Array[QuestInteractable] = []
var pod: QuestInteractable = null
var cables: Array[QuestInteractable] = []
var heart: CarryItem = null
var socket: QuestInteractable = null
var nodes: Array[QuestTarget] = []
var pylons: Array[QuestInteractable] = []

var _radio_label: Label3D = null
var _ice_mesh: MeshInstance3D = null
var _ice_shard: MeshInstance3D = null
var _symbols: Array[Label3D] = []
var _chain: MeshInstance3D = null
var _pod_mat: StandardMaterial3D = null
var _pod_gauge: Label3D = null
var _cable_fx: Array[OmniLight3D] = []
var _socket_heart: MeshInstance3D = null
var _node_meshes: Array[MeshInstance3D] = []
var _pylon_labels: Array[Label3D] = []
var _pylon_lights: Array[OmniLight3D] = []
var _marked_id: int = 0
var _marked_light: OmniLight3D = null
var _ending_at: float = -1.0
var _ending_layer: CanvasLayer = null
var _ending_flash: ColorRect = null
var _tick: float = 0.0


static func of(m: Match) -> VesperQuestWorld:
	if m == null or m.map_root == null:
		return null
	return m.map_root.get_node_or_null(^"QuestWorld") as VesperQuestWorld


func setup(m: Match) -> void:
	name = "QuestWorld"
	match_node = m
	quest = m.quest
	for n: Node in m.map_root.find_children("*", "MapMarker", true, false):
		markers[(n as MapMarker).marker_id] = n
	_radio()
	_fountain()
	_morgue()
	_marked_shard()
	_pod()
	_heart()
	_socket()
	_nodes()
	_pylons()
	m.session.flag_changed.connect(_on_flag)


func marker(id: StringName) -> MapMarker:
	var mk: MapMarker = markers.get(id, null)
	if mk != null:
		mk.show_visual = false
	return mk


func flag(k: String, default: Variant = null) -> Variant:
	return quest.flag(k, default)


func active(step_id: StringName) -> bool:
	return quest.is_active(step_id)


# --- builders ---------------------------------------------------------------------------------------


func _qi(
	parent: Node3D,
	key: StringName,
	offset: Vector3,
	prompt_text: Callable,
	avail: Callable,
	hold: float = 0.4,
	radius: float = 2.0
) -> QuestInteractable:
	var qi: QuestInteractable = QuestInteractable.new()
	qi.name = "QI_%s" % key
	qi.quest_key = key
	qi.position = offset
	qi.prompt_fn = prompt_text
	qi.available_fn = avail
	qi.hold_time = hold
	qi.use_radius = radius
	qi.ping_kind = &"item"
	parent.add_child(qi)
	return qi


func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, glow: float = 0.0) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = glow
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size
	return b


func _cyl(r: float, h: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c


func _shard_mesh() -> Mesh:
	var p: PrismMesh = PrismMesh.new()
	p.size = Vector3(0.16, 0.34, 0.12)
	return p


func _label(parent: Node3D, text: String, pos: Vector3, size: float = 0.006, color: Color = Color.WHITE) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = size
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	parent.add_child(l)
	return l


func _radio() -> void:
	var mk: MapMarker = marker(&"EE_RadioConsole")
	if mk == null:
		return
	for i: int in 3:
		var idx: int = i + 1
		var d: QuestInteractable = _qi(
			mk,
			StringName("radio_dial_%d" % idx),
			Vector3(-0.5 + 0.5 * i, 1.0, 0.0),
			func(_p: PlayerCharacter) -> String: return "tune dial %s (%02d)" % [ROMAN[idx - 1], dial(idx)],
			func(_p: PlayerCharacter) -> bool: return bool(flag("ee.radio_live", false)) and active(&"stage1"),
			0.15,
			1.6
		)
		d.continuous = true
		d.repeat_interval = 0.12
		dials.append(d)
	radio_tx = _qi(
		mk,
		&"radio_tx",
		Vector3(0.9, 1.0, 0.0),
		func(_p: PlayerCharacter) -> String: return "transmit on %02d-%02d-%02d" % [dial(1), dial(2), dial(3)],
		func(_p: PlayerCharacter) -> bool: return bool(flag("ee.radio_live", false)) and active(&"stage1"),
		0.6,
		1.6
	)
	radio_tx.ping_label = "radio console"
	_radio_label = _label(mk, "", Vector3(0, 1.6, 0), 0.004, Color(1.0, 0.75, 0.3))


func dial(i: int) -> int:
	return int(flag("ee.dial.%d" % i, 0))


func _fountain() -> void:
	var mk: MapMarker = marker(&"EE_FountainShard")
	if mk == null:
		return
	ice = QuestTarget.new()
	ice.name = "FountainIce"
	ice.quest_key = &"fountain_ice"
	ice.position = Vector3(0, -0.8, 0)
	ice.accepts_fn = func() -> bool: return active(&"stage2a") and not bool(flag("ee.ice_broken", false))
	mk.add_child(ice)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.5, 1.9, 1.5)
	ice.add_hurtbox(WeaponDefinition.Hitzone.TORSO, shape, Vector3.ZERO)
	_ice_mesh = _mesh(ice, _box(Vector3(1.45, 1.8, 1.45)), Color(0.75, 0.9, 1.0, 0.55), Vector3.ZERO)
	_ice_shard = _mesh(ice, _shard_mesh(), GREEN, Vector3(0, 0.1, 0), 3.0)
	# The shard falls into the basin when the ice breaks (fountain base top, south side).
	var pick: QuestInteractable = _shard_pickup(&"a", mk, Vector3(0, -2.8, -3.9))
	shard_pickups["a"] = pick


func _shard_pickup(letter: StringName, parent: Node3D, offset: Vector3) -> QuestInteractable:
	var qi: QuestInteractable = _qi(
		parent,
		StringName("shard_%s" % letter),
		offset,
		func(_p: PlayerCharacter) -> String: return "take the heart shard",
		func(_p: PlayerCharacter) -> bool: return shard_state(letter) == 1,
		0.4,
		2.2
	)
	qi.ping_label = "heart shard"
	var model: MeshInstance3D = _mesh(qi, _shard_mesh(), GREEN, Vector3(0, 0.4, 0), 3.0)
	model.name = "ShardModel"
	model.visible = false
	return qi


func shard_state(letter: StringName) -> int:
	return int(flag("ee.shard.%s" % letter, 0))


func _morgue() -> void:
	var wall: MapMarker = marker(&"EE_MorgueDrawers")
	if wall == null:
		return
	# Four labelled drawers along the drawer wall (x 17.8 .. 20.8 at z -10.6, facing +Z... the room).
	for i: int in 4:
		var gi: int = i
		var d: QuestInteractable = _qi(
			wall,
			StringName("drawer_%d" % gi),
			Vector3(-1.5 + 1.0 * i, 0.0, 0.3),
			func(_p: PlayerCharacter) -> String: return "pull the %s drawer" % GLYPHS[gi].to_lower(),
			func(_p: PlayerCharacter) -> bool: return active(&"stage2b") and not bool(flag("ee.chain_open", false)),
			0.5,
			1.6
		)
		_label(d, GLYPHS[gi], Vector3(0, 0.25, 0.05), 0.003, Color(0.8, 0.8, 0.75))
		drawers.append(d)
	for i: int in 4:
		var sm: MapMarker = marker(StringName("EE_Symbol_%d" % (i + 1)))
		if sm == null:
			continue
		var l: Label3D = _label(sm, "", Vector3(0, 0.2, 0), 0.008, Color(0.55, 1.0, 0.95))
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.visible = false
		_symbols.append(l)
	var cm: MapMarker = marker(&"EE_ChainedDrawer")
	if cm != null:
		_chain = _mesh(cm, _box(Vector3(0.9, 0.08, 0.08)), Color(0.4, 0.4, 0.42), Vector3(0, 0.1, 0.25))
		_mesh(_chain, _box(Vector3(0.08, 0.5, 0.08)), Color(0.4, 0.4, 0.42), Vector3(0, 0, 0))
		shard_pickups["b"] = _shard_pickup(&"b", cm, Vector3(0, -0.2, 0.5))


func _marked_shard() -> void:
	# Positioned at the marked Galvanic's death spot (flag "ee.shard.c.pos").
	var holder: Node3D = Node3D.new()
	holder.name = "MarkedShard"
	add_child(holder)
	shard_pickups["c"] = _shard_pickup(&"c", holder, Vector3.ZERO)


func _pod() -> void:
	var mk: MapMarker = marker(&"EE_SoulPod")
	if mk == null:
		return
	_mesh(mk, _cyl(0.9, 0.3), Color(0.3, 0.32, 0.35), Vector3(0, 0.15, 0))
	var glass: MeshInstance3D = _mesh(mk, _cyl(0.7, 2.2), Color(0.4, 1.0, 0.6, 0.35), Vector3(0, 1.4, 0), 0.2)
	_pod_mat = glass.material_override as StandardMaterial3D
	_mesh(mk, _cyl(0.9, 0.3), Color(0.3, 0.32, 0.35), Vector3(0, 2.65, 0))
	_pod_gauge = _label(mk, "", Vector3(0, 3.1, 0), 0.004, GREEN)
	pod = _qi(
		mk,
		&"pod",
		Vector3(0, 1.0, 1.0),
		func(_p: PlayerCharacter) -> String: return "place the heart shards",
		func(_p: PlayerCharacter) -> bool: return active(&"stage3") and not bool(flag("ee.pod_shards", false)),
		0.8
	)
	pod.ping_label = "Soul Containment Pod"
	for i: int in 2:
		var idx: int = i + 1
		var side: float = -1.0 if i == 0 else 1.0
		var c: QuestInteractable = _qi(
			mk,
			StringName("cable_%d" % idx),
			Vector3(side * 1.3, 0.8, 0),
			func(_p: PlayerCharacter) -> String: return "reseat the cable",
			func(_p: PlayerCharacter) -> bool: return bool(flag("ee.cable.%d" % idx, false)),
			2.0
		)
		_mesh(c, _cyl(0.06, 1.4), Color(0.15, 0.15, 0.15), Vector3(-side * 0.4, 0.4, 0)).rotation.z = side * 0.9
		var spark: OmniLight3D = OmniLight3D.new()
		spark.light_color = Color(0.6, 0.85, 1.0)
		spark.omni_range = 3.0
		spark.light_energy = 0.0
		c.add_child(spark)
		_cable_fx.append(spark)
		cables.append(c)


func _heart() -> void:
	var mk: MapMarker = markers.get(&"EE_SoulPod", null)
	heart = CarryItem.new()
	heart.name = "Heart"
	heart.item_id = &"heart"
	heart.display_name = "the Heart"
	heart.quest = quest
	heart.home = (mk.global_position if mk != null else Vector3.ZERO) + Vector3(0, 0.9, 1.0)
	var model: Node3D = Node3D.new()
	model.name = "HeartModel"
	var gem: SphereMesh = SphereMesh.new()
	gem.radius = 0.2
	gem.height = 0.34
	gem.radial_segments = 6
	gem.rings = 3
	_mesh(model, gem, GREEN, Vector3.ZERO, 4.0)
	heart.model = model
	add_child(heart)


func _socket() -> void:
	var mk: MapMarker = marker(&"EE_CoreSocket")
	if mk == null:
		return
	_mesh(mk, _cyl(0.6, 1.0), Color(0.3, 0.3, 0.32), Vector3(0, 0.5, 0))
	var cradle: TorusMesh = TorusMesh.new()
	cradle.inner_radius = 0.22
	cradle.outer_radius = 0.34
	_mesh(mk, cradle, Color(0.6, 0.55, 0.4), Vector3(0, 1.05, 0))
	var gem: SphereMesh = SphereMesh.new()
	gem.radius = 0.2
	gem.height = 0.34
	_socket_heart = _mesh(mk, gem, GREEN, Vector3(0, 1.25, 0), 5.0)
	_socket_heart.visible = false
	socket = _qi(
		mk,
		&"socket",
		Vector3(0, 1.0, 0),
		func(_p: PlayerCharacter) -> String: return "place the Heart in the core socket",
		func(p: PlayerCharacter) -> bool:
			return active(&"stage4") and p != null and p.get_meta(&"carrying", &"") == &"heart",
		0.8,
		2.4
	)
	socket.ping_label = "core socket"


func _nodes() -> void:
	for i: int in 4:
		var mk: MapMarker = marker(StringName("EE_Node_%d" % (i + 1)))
		var t: QuestTarget = QuestTarget.new()
		t.name = "CalibrationNode%d" % (i + 1)
		t.quest_key = StringName("node_%d" % (i + 1))
		var idx: int = i + 1
		t.accepts_fn = func() -> bool: return int(flag("ee.node", 0)) == idx
		add_child(t)
		if mk != null:
			t.global_position = mk.global_position
			t.set_meta(&"home", mk.global_position)
		var sh: SphereShape3D = SphereShape3D.new()
		sh.radius = 0.75
		t.add_hurtbox(WeaponDefinition.Hitzone.TORSO, sh, Vector3.ZERO)
		var crystal: PrismMesh = PrismMesh.new()
		crystal.size = Vector3(0.9, 1.4, 0.9)
		var mi: MeshInstance3D = _mesh(t, crystal, Color(0.55, 1.0, 0.7), Vector3.ZERO, 4.0)
		mi.visible = false
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = GREEN
		l.omni_range = 6.0
		l.light_energy = 2.0
		mi.add_child(l)
		_node_meshes.append(mi)
		nodes.append(t)


func _pylons() -> void:
	for i: int in 3:
		var mk: MapMarker = marker(StringName("EE_Pylon_%d" % (i + 1)))
		if mk == null:
			continue
		var idx: int = i + 1
		_mesh(mk, _cyl(0.35, 2.6), Color(0.35, 0.37, 0.4), Vector3(0, 1.3, 0))
		_mesh(mk, _cyl(0.5, 0.3), Color(0.25, 0.25, 0.27), Vector3(0, 0.15, 0))
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(0, 2.8, 0)
		light.omni_range = 5.0
		light.light_energy = 0.0
		mk.add_child(light)
		_pylon_lights.append(light)
		_pylon_labels.append(_label(mk, "", Vector3(0, 3.2, 0), 0.005, GREEN))
		var qi: QuestInteractable = _qi(
			mk,
			StringName("pylon_%d" % idx),
			Vector3(0, 1.0, 0),
			func(_p: PlayerCharacter) -> String: return "repair the stabilizer pylon",
			func(_p: PlayerCharacter) -> bool:
				var hp: float = float(flag("ee.pylon.%d" % idx, PYLON_MAX))
				return int(flag("ee.finale", 0)) == 1 and hp > 0.0 and hp < PYLON_MAX,
			0.3,
			2.4
		)
		qi.continuous = true
		qi.repeat_interval = 0.5
		qi.ping_label = "stabilizer pylon"
		pylons.append(qi)


# --- presentation -----------------------------------------------------------------------------------


func _on_flag(key: String, value: Variant) -> void:
	if not quest.started_presentation():
		return
	match key:
		"ee.ice_broken":
			if bool(value) and ice != null:
				Audio.play_event_3d(&"ice_shatter", ice.global_position)
		"ee.chain_open":
			if bool(value) and _chain != null:
				Audio.play_event_3d(&"drawer_slam", _chain.global_position)
		"ee.drawer_step":
			if drawers.size() > 0:
				Audio.play_event_3d(&"drawer_pull", drawers[0].global_position)
		"ee.nodes_broken":
			Audio.play_event_3d(&"node_break", Vector3(28, -44, -50))
		"ee.victory_at":
			_begin_ending()
	if key.begins_with("ee.dial."):
		Audio.play_event_3d(&"radio_dial", dials[0].global_position if not dials.is_empty() else Vector3.ZERO)
	elif key.begins_with("ee.cable.") and bool(value):
		var i: int = int(key.get_slice(".", 2)) - 1
		if i >= 0 and i < cables.size():
			Audio.play_event_3d(&"cable_spark", cables[i].global_position)
			Audio.play_event_3d(&"quest_alarm", cables[i].global_position)
	elif key.begins_with("ee.shard.") and key.count(".") == 2 and int(value) == 2:
		Audio.play_event(&"carry_pick")


func _process(delta: float) -> void:
	if match_node == null or quest == null:
		return
	_update_storm()
	_update_nodes()
	_update_marked()
	_update_ending(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.1
	if _radio_label != null:
		_radio_label.visible = bool(flag("ee.radio_live", false))
		_radio_label.text = "%s %02d   %s %02d   %s %02d" % [ROMAN[0], dial(1), ROMAN[1], dial(2), ROMAN[2], dial(3)]
	if ice != null:
		var broken: bool = bool(flag("ee.ice_broken", false))
		_ice_mesh.visible = not broken
		_ice_shard.visible = not broken
	for letter: String in SHARDS:
		var qi: QuestInteractable = shard_pickups.get(letter, null)
		if qi == null:
			continue
		var on: bool = shard_state(StringName(letter)) == 1
		(qi.get_node(^"ShardModel") as Node3D).visible = on
		if letter == "c":
			qi.get_parent().global_position = flag("ee.shard.c.pos", Vector3(0, -500, 0))
	_update_morgue()
	_update_pod()
	if _socket_heart != null:
		_socket_heart.visible = bool(flag("ee.heart_socketed", false))
	_update_pylons()


# The storm subsides for one round after the finale ("ee.storm_calm_round").
func _update_storm() -> void:
	var art: VesperArt = match_node.map_root.get(&"art") as VesperArt
	if art == null or art.storm == null:
		return
	var until: int = int(flag("ee.storm_calm_round", 0))
	var r: int = match_node.rounds.current_round if match_node.rounds != null else 0
	art.storm.calm = until > 0 and r <= until


func _update_morgue() -> void:
	var order: Array = flag("ee.drawer_order", [])
	var show: bool = (
		match_node.hazards != null
		and match_node.hazards.breaker_active()
		and not quest.is_done(&"stage2b")
		and order.size() == 4
	)
	for i: int in _symbols.size():
		_symbols[i].visible = show
		if show:
			_symbols[i].text = "%s\n%s" % [ROMAN[i], GLYPHS[int(order[i])]]
	if _chain != null:
		_chain.visible = not bool(flag("ee.chain_open", false))


func _update_pod() -> void:
	if _pod_mat == null:
		return
	var need: int = maxi(int(flag("ee.souls_needed", 0)), 1)
	var souls: int = int(flag("ee.souls", 0))
	var placed: bool = bool(flag("ee.pod_shards", false))
	var charged: bool = bool(flag("ee.heart_charged", false))
	var frac: float = 1.0 if charged else (float(souls) / need if placed else 0.0)
	_pod_mat.emission_energy_multiplier = (
		0.2 + frac * 3.0 + (0.4 * sin(Time.get_ticks_msec() * 0.006) if placed else 0.0)
	)
	var bars: int = int(round(frac * 10.0))
	_pod_gauge.visible = placed and not quest.is_done(&"stage4")
	_pod_gauge.text = "|".repeat(bars) + ".".repeat(10 - bars)
	for i: int in _cable_fx.size():
		var loose: bool = bool(flag("ee.cable.%d" % (i + 1), false))
		_cable_fx[i].light_energy = (randf() * 3.0) if loose else 0.0


func _update_nodes() -> void:
	var activ: int = int(flag("ee.node", 0))
	var t: float = Net.host_time()
	for i: int in nodes.size():
		var n: QuestTarget = nodes[i]
		if n.has_meta(&"home"):
			var home: Vector3 = n.get_meta(&"home")
			var c: Vector3 = Vector3(28.0, home.y, -50.0)
			var off: Vector3 = home - c
			var a: float = t * NODE_ORBIT_SPEED
			n.global_position = c + off.rotated(Vector3.UP, a) + Vector3(0, sin(t * 1.3 + i) * 0.3, 0)
		_node_meshes[i].visible = activ == i + 1
		_node_meshes[i].rotate_y(0.02)


func _update_pylons() -> void:
	var finale: int = int(flag("ee.finale", 0))
	for i: int in _pylon_labels.size():
		var hp: float = float(flag("ee.pylon.%d" % (i + 1), PYLON_MAX))
		var on: bool = finale == 1
		_pylon_labels[i].visible = on
		var bars: int = int(ceil(hp / PYLON_MAX * 8.0))
		_pylon_labels[i].text = "#".repeat(bars) + "-".repeat(8 - bars)
		var col: Color = Color(1.0, 0.3, 0.2).lerp(GREEN, hp / PYLON_MAX)
		_pylon_labels[i].modulate = col
		_pylon_lights[i].light_color = col
		_pylon_lights[i].light_energy = (1.5 if hp > 0.0 else 0.0) if on else 0.0


func _update_marked() -> void:
	var id: int = int(flag("ee.marked", 0))
	if id == _marked_id and (_marked_light == null or is_instance_valid(_marked_light)):
		return
	if _marked_light != null and is_instance_valid(_marked_light):
		_marked_light.queue_free()
	_marked_light = null
	_marked_id = id
	if id == 0 or match_node.zombies == null:
		return
	var a: ZombieActor = match_node.zombies.actors.get(id, null)
	if a == null:
		_marked_id = -1  # not replicated yet: retry next frame
		return
	_marked_light = OmniLight3D.new()
	_marked_light.name = "MarkedGlow"
	_marked_light.light_color = Color(0.85, 0.95, 1.0)
	_marked_light.light_energy = 4.0
	_marked_light.omni_range = 6.0
	_marked_light.position = Vector3(0, 1.4, 0)
	a.add_child(_marked_light)
	Audio.play_event_3d(&"marked_whine", a.global_position)


# The finale's in-engine moment (every peer, players keep control): letterbox bars, a white flash
# from the core, three energy pulses and the audio slowed for 10 s (presentation-only "slow motion";
# the simulation keeps real time so co-op stays in sync).
func _begin_ending() -> void:
	_ending_at = 0.0
	Audio.play_event_3d(&"core_flare", Vector3(28, -44, -50))
	Audio.play_event(&"finale_sting")
	var art: VesperArt = match_node.map_root.get(&"art") as VesperArt
	if art != null:
		art.energy_pulse()
	if _ending_layer == null:
		_ending_layer = CanvasLayer.new()
		_ending_layer.layer = 6
		_ending_layer.add_to_group(&"hide_for_shots")
		add_child(_ending_layer)
		for top: bool in [true, false]:
			var bar: ColorRect = ColorRect.new()
			bar.color = Color.BLACK
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
			bar.custom_minimum_size = Vector2(0, 80)
			if not top:
				bar.position.y = -80
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ending_layer.add_child(bar)
		_ending_flash = ColorRect.new()
		_ending_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ending_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ending_layer.add_child(_ending_flash)
	_ending_layer.visible = true


func ending_active() -> bool:
	return _ending_at >= 0.0


func _update_ending(delta: float) -> void:
	if _ending_at < 0.0:
		return
	_ending_at += delta
	_ending_flash.color = Color(1, 1, 1, clampf(1.0 - _ending_at / 2.5, 0.0, 1.0))
	AudioServer.playback_speed_scale = 0.75 if _ending_at < 10.0 else 1.0
	if _ending_at >= 10.0:
		_ending_at = -1.0
		_ending_layer.visible = false
		AudioServer.playback_speed_scale = 1.0


func _exit_tree() -> void:
	AudioServer.playback_speed_scale = 1.0
