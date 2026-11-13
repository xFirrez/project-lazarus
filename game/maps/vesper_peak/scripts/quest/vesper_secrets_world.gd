# VesperSecretsWorld — Vesper Peak's collectibles and minor secrets (VESPER_PEAK §6.1, §7.2, §3 S1 / S2;
# DEVELOPMENT_PLAN Step 14 scope 2-3), built on their markers during Match.setup:
#   * a LoreItem on every lore / reel marker (14 documents, 8 in-world reels) + the Lobby guestbook
#   * S1: the room-7 mirror (shows the player as a zombie for a split second; after the guestbook
#     clue it opens the bookcase), the rotating bookcase (NavDoor S1_BookcaseDoor), the free tonic
#     crate (FreePerkCrate, enabled by "ee.s1_open", once per player, respects the cap)
#   * S2: the frozen waterfall (QuestTarget; cracks after power on, shatters to an explosive or Ray
#     Pistol hit -> NavDoor S2_WaterfallIce opens), the hidden fourth music box (Anneliese VO)
#   * the three "Snowblind" music boxes; five frozen ravens (QuestTargets); the departures board
#     spelling "SHE IS STILL HERE" now and then after power
# Secret logic: maps/vesper_peak/scripts/quest/secret_*.gd (QuestGraph vesper_secrets).
# Authority: presentation on every peer; host objectives decide.
class_name VesperSecretsWorld
extends Node3D

const BOARD_IDLE: String = "VALLEY STATION   18:40\nSUMMIT HOTEL     --:--\nVESPERHÖHE       CANCELLED"
const BOARD_MESSAGE: String = "SHE   IS\nSTILL\nHERE"
const RAVEN_IDS: Array[StringName] = [
	&"Raven_1_Z01Roof", &"Raven_2_Fountain", &"Raven_3_Greenhouse", &"Raven_4_Antenna", &"Raven_5_GondolaStation"
]
const MUSIC_BOXES: Array[StringName] = [&"MB1_Luggage", &"MB2_Room12", &"MB3_ObsLocker"]

var match_node: Match = null
var quest: QuestSystem = null
var markers: Dictionary = {}
var lore_items: Array[LoreItem] = []
var mirror: QuestInteractable = null
var bookcase_door: NavDoor = null
var crate: FreePerkCrate = null
var waterfall: QuestTarget = null
var waterfall_door: NavDoor = null
var music_boxes: Array[QuestInteractable] = []
var grotto_box: QuestInteractable = null
var ravens: Array[QuestTarget] = []

var _board: Label3D = null
var _board_until: float = 0.0
var _board_next: float = 0.0
var _bookcase: Node3D = null
var _raven_meshes: Array[Node3D] = []
var _crack: MeshInstance3D = null
var _mirror_flash: float = 0.0
var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func of(m: Match) -> VesperSecretsWorld:
	return (
		m.map_root.get_node_or_null(^"SecretsWorld") as VesperSecretsWorld if m != null and m.map_root != null else null
	)


func setup(m: Match) -> void:
	name = "SecretsWorld"
	match_node = m
	quest = m.quest
	_rng.randomize()
	_board_next = 30.0
	for n: Node in m.map_root.find_children("*", "MapMarker", true, false):
		markers[(n as MapMarker).marker_id] = n
	for n: Node in m.map_root.find_children("*", "NavDoor", true, false):
		if n.name == "S1_BookcaseDoor":
			bookcase_door = n as NavDoor
		elif n.name == "S2_WaterfallIce":
			waterfall_door = n as NavDoor
	_lore()
	_s1()
	_s2()
	_music_boxes()
	_ravens()
	_departures()
	m.session.flag_changed.connect(_on_flag)


func flag(k: String, default: Variant = null) -> Variant:
	return quest.flag(k, default)


func _marker(id: StringName) -> MapMarker:
	var mk: MapMarker = markers.get(id, null)
	if mk != null:
		mk.show_visual = false
	return mk


func _lore() -> void:
	var lib: LoreLibrary = quest.vo.lore
	var ids: Array[StringName] = []
	for n: Variant in markers.keys():
		var mk: MapMarker = markers[n]
		if mk.kind == &"lore" or mk.kind == &"reel":
			ids.append(mk.marker_id)
	ids.sort()  # deterministic order on every peer (the scan uses tree order anyway)
	for id: StringName in ids:
		var mk: MapMarker = _marker(id)
		_add_lore(mk, id, "reel" if mk.kind == &"reel" else "doc", Vector3.ZERO)
	var gb: MapMarker = _marker(&"EE_Guestbook")
	if gb != null and not lib.entry(&"guestbook").is_empty():
		_add_lore(gb, &"guestbook", "doc", Vector3.ZERO).ping_label = "guestbook"


func _add_lore(mk: Node3D, id: StringName, kind: String, offset: Vector3) -> LoreItem:
	var li: LoreItem = LoreItem.new()
	li.name = "Lore_%s" % id
	li.entry_id = id
	li.kind = kind
	li.quest = quest
	li.position = offset
	mk.add_child(li)
	lore_items.append(li)
	return li


func _qi(parent: Node3D, key: StringName, prompt_text: String, avail: Callable, hold: float = 0.4) -> QuestInteractable:
	var qi: QuestInteractable = QuestInteractable.new()
	qi.name = "QI_%s" % key
	qi.quest_key = key
	qi.prompt_fn = func(_p: PlayerCharacter) -> String: return prompt_text
	qi.available_fn = avail
	qi.hold_time = hold
	parent.add_child(qi)
	return qi


func _s1() -> void:
	var mm: MapMarker = _marker(&"S1_Mirror_R7")
	if mm != null:
		mirror = _qi(mm, &"mirror", "look into the cracked mirror", func(_p: PlayerCharacter) -> bool: return true)
		mirror.use_radius = 1.8
	if bookcase_door != null:
		# The NavDoor's own grey block stays hidden; a bookcase swings open on a hinge at its north edge.
		for c: Node in bookcase_door.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
		_bookcase = Node3D.new()
		_bookcase.name = "RotatingBookcase"
		add_child(_bookcase)
		_bookcase.global_position = bookcase_door.global_position + Vector3(0.15, -1.2, 0.8)
		var shelf: MeshInstance3D = VesperProps.make(&"bookcase")
		shelf.position = Vector3(0, 0, -0.8)
		shelf.rotation.y = -PI / 2.0
		_bookcase.add_child(shelf)
	var cm: MapMarker = _marker(&"S1_FreeTonicCrate")
	if cm != null:
		crate = FreePerkCrate.new()
		crate.name = "S1_TonicCrate"
		crate.enable_flag = "ee.s1_open"
		crate.respect_cap = true
		cm.add_child(crate)
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 6
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.35, 0.6, 0.3, 0.0)
	_flash_layer.add_child(_flash_rect)


func _s2() -> void:
	var wm: MapMarker = _marker(&"S2_Waterfall")
	if waterfall_door != null:
		for c: Node in waterfall_door.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
	if wm != null:
		waterfall = QuestTarget.new()
		waterfall.name = "WaterfallIce"
		waterfall.quest_key = &"waterfall"
		waterfall.accepts_fn = func() -> bool: return Power.is_on() and not bool(flag("ee.s2_open", false))
		wm.add_child(waterfall)
		waterfall.position = Vector3(-0.7, 3.0, 0)
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(0.6, 6.0, 8.0)
		waterfall.add_hurtbox(WeaponDefinition.Hitzone.TORSO, shape, Vector3.ZERO)
		# Cracks (after power, the boiler steam warms the cliff): a jagged dark seam on the ice face.
		_crack = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.05, 4.5, 0.12)
		_crack.mesh = bm
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.12, 0.16)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 0.6)
		mat.emission_energy_multiplier = 0.6
		_crack.material_override = mat
		_crack.position = Vector3(0.25, 0, 0)
		_crack.rotation.x = 0.25
		_crack.visible = false
		waterfall.add_child(_crack)
	var gb: MapMarker = _marker(&"MB4_Grotto")
	if gb != null:
		grotto_box = _qi(gb, &"mb_grotto", "wind the music box", func(_p: PlayerCharacter) -> bool: return true, 0.6)
		_box_model(grotto_box, Color(0.55, 0.75, 0.9))


func _music_boxes() -> void:
	for i: int in MUSIC_BOXES.size():
		var mk: MapMarker = _marker(MUSIC_BOXES[i])
		if mk == null:
			continue
		var idx: int = i + 1
		var qi: QuestInteractable = _qi(
			mk,
			StringName("mb_%d" % idx),
			"wind the music box",
			func(_p: PlayerCharacter) -> bool: return not bool(flag("ee.mb.%d" % idx, false)),
			0.6
		)
		_box_model(qi, Color(0.55, 0.35, 0.2))
		music_boxes.append(qi)


func _box_model(parent: Node3D, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.22, 0.14, 0.16)
	mi.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mi.material_override = mat
	mi.position = Vector3(0, 0.07, 0)
	parent.add_child(mi)


func _ravens() -> void:
	for i: int in RAVEN_IDS.size():
		var mk: MapMarker = _marker(RAVEN_IDS[i])
		if mk == null:
			continue
		var idx: int = i + 1
		var t: QuestTarget = QuestTarget.new()
		t.name = "FrozenRaven%d" % idx
		t.quest_key = StringName("raven_%d" % idx)
		t.accepts_fn = func() -> bool: return not bool(flag("ee.raven.%d" % idx, false))
		mk.add_child(t)
		var sh: SphereShape3D = SphereShape3D.new()
		sh.radius = 0.35
		t.add_hurtbox(WeaponDefinition.Hitzone.TORSO, sh, Vector3(0, 0.2, 0))
		var body: Node3D = Node3D.new()
		t.add_child(body)
		var bm: SphereMesh = SphereMesh.new()
		bm.radius = 0.16
		bm.height = 0.3
		var head: SphereMesh = SphereMesh.new()
		head.radius = 0.08
		head.height = 0.16
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.13, 0.16)
		mat.roughness = 0.3
		mat.clearcoat_enabled = true  # rimed with ice
		for part: Array in [[bm, Vector3(0, 0.15, 0)], [head, Vector3(0, 0.32, 0.12)]]:
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = part[0]
			mi.material_override = mat
			mi.position = part[1]
			body.add_child(mi)
		_raven_meshes.append(body)
		ravens.append(t)


func _departures() -> void:
	var mk: MapMarker = _marker(&"EE_DeparturesBoard")
	if mk == null:
		return
	_board = Label3D.new()
	_board.name = "DeparturesBoardText"
	_board.pixel_size = 0.006
	_board.font_size = 48
	_board.modulate = Color(1.0, 0.8, 0.35)
	_board.rotation.y = PI
	_board.position = Vector3(0, 0, -0.12)
	_board.text = BOARD_IDLE
	mk.add_child(_board)


# --- presentation -----------------------------------------------------------------------------------


func _on_flag(key: String, value: Variant) -> void:
	var live: bool = quest.started_presentation()
	match key:
		"ee.s1_open":
			if bool(value) and _bookcase != null:
				if live:
					Audio.play_event_3d(&"bookcase_grind", _bookcase.global_position)
					var tw: Tween = _bookcase.create_tween()
					tw.tween_property(_bookcase, "rotation:y", -PI / 2.0, 2.2)
				else:
					_bookcase.rotation.y = -PI / 2.0
		"ee.mirror_uses":
			if live and mirror != null:
				var me: PlayerCharacter = match_node.players.local_avatar()
				if me != null and me.global_position.distance_to(mirror.global_position) < 4.0:
					_mirror_flash = 0.35
					Audio.play_event(&"mirror_flash")
		"ee.s2_open":
			if bool(value):
				for n: Node in get_tree().get_nodes_in_group(&"s2_ice"):
					(n as Node3D).visible = false
				if live and waterfall != null:
					Audio.play_event_3d(&"ice_shatter", waterfall.global_position)
		"ee.snowblind_at":
			if live:
				Audio.play_event(&"snowblind")
	if key.begins_with("ee.mb.") and bool(value) and live:
		var i: int = int(key.get_slice(".", 2)) - 1
		if i >= 0 and i < music_boxes.size():
			Audio.play_event_3d(&"music_box", music_boxes[i].global_position)
	elif key.begins_with("ee.raven.") and bool(value) and live:
		var i: int = int(key.get_slice(".", 2)) - 1
		if i >= 0 and i < ravens.size():
			Audio.play_event_3d(&"raven_hit", ravens[i].global_position)


func _process(delta: float) -> void:
	if match_node == null or quest == null:
		return
	for i: int in _raven_meshes.size():
		_raven_meshes[i].visible = not bool(flag("ee.raven.%d" % (i + 1), false))
	if _crack != null:
		_crack.visible = Power.is_on() and not bool(flag("ee.s2_open", false))
	_mirror_flash = maxf(_mirror_flash - delta, 0.0)
	if _flash_rect != null:
		_flash_rect.color.a = 0.55 * (_mirror_flash / 0.35)
	_update_board(delta)


func _update_board(delta: float) -> void:
	if _board == null:
		return
	if not Power.is_on():
		_board.text = BOARD_IDLE
		_board.modulate.a = 0.25
		return
	_board.modulate.a = 1.0
	_board_next -= delta
	if _board_next <= 0.0:
		_board_next = _rng.randf_range(45.0, 90.0)
		_board_until = 4.0
	_board_until = maxf(_board_until - delta, 0.0)
	_board.text = BOARD_MESSAGE if _board_until > 0.0 else BOARD_IDLE
