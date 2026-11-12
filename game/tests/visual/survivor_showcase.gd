# Visual check (Step 7): the four survivors on the Arrival Station floor for review — row 1 each
# with a different weapon-class hold (pistol, LMG, shotgun, rifle) and locomotion; row 2 the
# full-body states (downed crawl, revive, slide, crouch walk). Also a first-person frame showing
# the character-tinted arms. Frames go to --autotest-shots (docs/screenshots).
extends "res://tests/net/autotest_base.gd"

const ROW1: Array = [
	[&"calloway", &"hold_pistol", &"idle"],
	[&"orlov", &"hold_lmg", &"walk"],
	[&"brandt", &"hold_shotgun", &"crouch_idle"],
	[&"ashcombe", &"hold_rifle", &"idle"],
]
const ROW2: Array = [
	[&"calloway", &"hold_pistol", &"downed_crawl"],
	[&"orlov", &"hold_rifle", &"revive"],
	[&"brandt", &"hold_rifle", &"slide"],
	[&"ashcombe", &"hold_pistol", &"crouch_walk"],
]

var _out: String = ""


func _ready() -> void:
	timeout = 90.0
	_out = CommandLine.get_value("autotest-shots", "user://screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	EventBus.match_started.connect(func(_m: StringName) -> void: _run.call_deferred())


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw


func _shot(file: String) -> Image:
	await _frames(2)
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(file))
	return img


func _spawn_row(row: Array, z: float) -> Array[SurvivorModel]:
	var out: Array[SurvivorModel] = []
	for i: int in row.size():
		var e: Array = row[i]
		var def: CharacterDefinition = CharacterDefinition.get_def(e[0])
		var m: SurvivorModel = (load(def.model_scene) as PackedScene).instantiate() as SurvivorModel
		m.character = def
		Match.current.map_root.add_child(m)
		m.global_position = Vector3(-2.7 + i * 1.8, 0.05, z)
		m.rotation.y = PI + (i - 1.5) * 0.25  # face the camera, slightly fanned
		out.append(m)
	await _frames(2)
	for i: int in row.size():
		out[i].set_hold(row[i][1])
		out[i].set_locomotion(row[i][2])
	return out


func _run() -> void:
	await _frames(10)
	var me: PlayerCharacter = sync().local_avatar()
	me.health.invulnerable = true
	me.notarget = true
	Match.current.zombies.crowd.frozen = true
	Match.current.rounds.paused = true
	if is_instance_valid(Debug.overlay):
		Debug.overlay.visible = false
	# First-person arms (Calloway's sleeves on the M1911 hero model, then the greybox MP40).
	me.motor.teleport(Vector3(0, 0.05, -1.0))
	me.set_view(PI, -0.05)
	await _frames(40)
	var fp: Image = await _shot("survivor_first_person_arms.png")
	check("first_person_rendered", fp.get_width() > 0)
	Match.current.weapons.host_give(me.peer_id, &"mp40")
	await _frames(60)
	await _shot("survivor_first_person_arms_mp40.png")
	for n: Node in get_tree().get_nodes_in_group(&"hide_for_shots"):
		n.set(&"visible", false)
	me.weapons.viewmodel.container.visible = false
	me.motor.teleport(Vector3(0, 0.05, 6.5))
	var cam: Camera3D = Camera3D.new()
	Match.current.map_root.add_child(cam)
	cam.fov = 55.0
	cam.look_at_from_position(Vector3(0, 1.55, 2.4), Vector3(0, 0.95, -3.0))
	cam.current = true
	var row1: Array[SurvivorModel] = await _spawn_row(ROW1, -3.0)
	await _frames(45)
	var img1: Image = await _shot("survivors_holds.png")
	check("holds_rendered", img1.get_width() > 0)
	for m: SurvivorModel in row1:
		m.queue_free()
	var row2: Array[SurvivorModel] = await _spawn_row(ROW2, -3.0)
	await _frames(45)
	await _shot("survivors_states.png")
	check("states_spawned", row2.size() == 4)
	finish(true)
