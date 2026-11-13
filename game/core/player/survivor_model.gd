# SurvivorModel — third-person body of a player character (Step 7 scope 6): the character's
# retargeted humanoid model (tools/blender/characters/build_survivors.py) driven by the shared
# survivor AnimationLibrary through an AnimationTree built in code:
#   locomotion (Transition): idle / walk / run / crouch_idle / crouch_walk / slide / jump /
#                            downed_crawl / revive
#   upper body (Blend2, spine-up filter): hold_pistol / hold_rifle / hold_shotgun / hold_lmg from
#                            the held weapon's class (off while sprinting, sliding, downed, reviving)
#   one-shots (spine-up filter): fire_pistol / fire_long on relayed shots, reload_pistol /
#                            reload_long on relayed reload starts, drink (Vigor Tonics, Step 10)
# The third-person weapon follows the right hand. Everything is derived from replicated state on
# the PlayerCharacter (position deltas, state flags, remote weapon, relay counters, revive state).
# Authority: local presentation on every peer.
class_name SurvivorModel
extends Node3D

const LIBRARY: StringName = &"survivor"
const LOCO: Array[StringName] = [
	&"idle", &"walk", &"run", &"crouch_idle", &"crouch_walk", &"slide", &"jump", &"downed_crawl", &"revive"
]
const HOLDS: Array[StringName] = [&"hold_pistol", &"hold_rifle", &"hold_shotgun", &"hold_lmg"]
const FIRES: Array[StringName] = [&"fire_pistol", &"fire_long"]
const ACTIONS: Array[StringName] = [&"reload_pistol", &"reload_long", &"drink"]
const UPPER_BONES: PackedStringArray = [
	"Spine",
	"Chest",
	"UpperChest",
	"Neck",
	"Head",
	"LeftShoulder",
	"RightShoulder",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftHand",
	"RightHand"
]
const WALK_SPEED_REF: float = 1.6  # m/s at which the walk clip plays at 1x
const RUN_SPEED_REF: float = 5.5
const HAND_OFFSET: Vector3 = Vector3(0.0, 0.03, 0.06)

@export var model_scene: PackedScene = null
@export var animations: AnimationLibrary = null

var character: CharacterDefinition = null
var model: Node3D = null
var skeleton: Skeleton3D = null
var anim: AnimationPlayer = null
var tree: AnimationTree = null
var locomotion: StringName = &"idle"
var hold: StringName = &"hold_pistol"
var upper_weight: float = 1.0
var fires_played: int = 0
var reloads_played: int = 0

var _last_pos: Vector3 = Vector3.INF
var _speed: float = 0.0
var _seen_replays: int = 0
var _seen_reloads: int = 0
var _hand_bone: int = -1


func _ready() -> void:
	if model_scene == null:
		return
	model = model_scene.instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = PI  # glTF characters face +Z; players face -Z
	add_child(model)
	skeleton = model.get_node_or_null(^"%GeneralSkeleton") as Skeleton3D
	if skeleton == null:
		var found: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
		skeleton = found[0] as Skeleton3D if not found.is_empty() else null
	if skeleton != null:
		_hand_bone = skeleton.find_bone("RightHand")
	for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	anim.root_node = anim.get_path_to(model)
	if animations != null:
		anim.add_animation_library(LIBRARY, animations)
		_build_tree()


func has_clip(clip: StringName) -> bool:
	return animations != null and animations.has_animation(clip)


func _clip_node(clip: StringName) -> AnimationNodeAnimation:
	var n: AnimationNodeAnimation = AnimationNodeAnimation.new()
	n.animation = StringName("%s/%s" % [LIBRARY, clip])
	return n


func _transition(clips: Array[StringName], xfade: float) -> AnimationNodeTransition:
	var t: AnimationNodeTransition = AnimationNodeTransition.new()
	t.xfade_time = xfade
	for c: StringName in clips:
		t.add_input(String(c))
	return t


func _upper_filter(node: AnimationNode) -> void:
	node.filter_enabled = true
	var ref: Animation = animations.get_animation(&"hold_pistol")
	for i: int in ref.get_track_count():
		var path: NodePath = ref.track_get_path(i)
		if UPPER_BONES.has(String(path.get_concatenated_subnames())):
			node.set_filter_path(path, true)


func _build_tree() -> void:
	var bt: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var loco: AnimationNodeTransition = _transition(LOCO, 0.18)
	bt.add_node(&"loco", loco)
	for i: int in LOCO.size():
		bt.add_node(StringName("l_" + LOCO[i]), _clip_node(LOCO[i]))
		bt.connect_node(&"loco", i, StringName("l_" + LOCO[i]))
	var holds: AnimationNodeTransition = _transition(HOLDS, 0.2)
	bt.add_node(&"hold", holds)
	for i: int in HOLDS.size():
		bt.add_node(StringName("h_" + HOLDS[i]), _clip_node(HOLDS[i]))
		bt.connect_node(&"hold", i, StringName("h_" + HOLDS[i]))
	var upper: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	_upper_filter(upper)
	bt.add_node(&"upper", upper)
	bt.connect_node(&"upper", 0, &"loco")
	bt.connect_node(&"upper", 1, &"hold")
	var fire_sel: AnimationNodeTransition = _transition(FIRES, 0.0)
	bt.add_node(&"fire_sel", fire_sel)
	for i: int in FIRES.size():
		bt.add_node(StringName("f_" + FIRES[i]), _clip_node(FIRES[i]))
		bt.connect_node(&"fire_sel", i, StringName("f_" + FIRES[i]))
	var fire: AnimationNodeOneShot = AnimationNodeOneShot.new()
	fire.fadein_time = 0.03
	fire.fadeout_time = 0.1
	_upper_filter(fire)
	bt.add_node(&"fire", fire)
	bt.connect_node(&"fire", 0, &"upper")
	bt.connect_node(&"fire", 1, &"fire_sel")
	var act_sel: AnimationNodeTransition = _transition(ACTIONS, 0.0)
	bt.add_node(&"act_sel", act_sel)
	for i: int in ACTIONS.size():
		bt.add_node(StringName("a_" + ACTIONS[i]), _clip_node(ACTIONS[i]))
		bt.connect_node(&"act_sel", i, StringName("a_" + ACTIONS[i]))
	var act: AnimationNodeOneShot = AnimationNodeOneShot.new()
	act.fadein_time = 0.12
	act.fadeout_time = 0.2
	_upper_filter(act)
	bt.add_node(&"action", act)
	bt.connect_node(&"action", 0, &"fire")
	bt.connect_node(&"action", 1, &"act_sel")
	var scale: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	bt.add_node(&"speed", scale)
	bt.connect_node(&"speed", 0, &"action")
	bt.connect_node(&"output", 0, &"speed")
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = bt
	add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.root_node = tree.get_path_to(model)
	tree.active = true
	tree.set(&"parameters/upper/blend_amount", 1.0)
	# Transition nodes start with no current state (= rest pose) until a request arrives.
	tree.set(&"parameters/loco/transition_request", String(locomotion))
	tree.set(&"parameters/hold/transition_request", String(hold))
	tree.set(&"parameters/fire_sel/transition_request", "fire_pistol")
	tree.set(&"parameters/act_sel/transition_request", "reload_pistol")


static func hold_for(def: WeaponDefinition) -> StringName:
	if def == null:
		return &"hold_pistol"
	match def.weapon_class:
		WeaponDefinition.WeaponClass.PISTOL, WeaponDefinition.WeaponClass.MELEE, WeaponDefinition.WeaponClass.LETHAL:
			return &"hold_pistol"
		WeaponDefinition.WeaponClass.SHOTGUN:
			return &"hold_shotgun"
		WeaponDefinition.WeaponClass.LMG:
			return &"hold_lmg"
	return &"hold_rifle"


# Locomotion clip from replicated state (pure; unit-tested).
static func locomotion_for(flags: int, speed: float, reviving: bool) -> StringName:
	if flags & 16:
		return &"downed_crawl"
	if reviving:
		return &"revive"
	var stance: int = flags & 3
	if stance == MotorComponent.Stance.SLIDE:
		return &"slide"
	if (flags & 4) == 0:
		return &"jump"
	var moving: bool = speed > 0.35
	if stance == MotorComponent.Stance.CROUCH:
		return &"crouch_walk" if moving else &"crouch_idle"
	if not moving:
		return &"idle"
	return &"run" if (flags & 8) != 0 or speed > 4.2 else &"walk"


func update_from(p: PlayerCharacter, delta: float) -> void:
	if tree == null or delta <= 0.0:
		return
	var pos: Vector3 = p.global_position
	if _last_pos != Vector3.INF:
		var v: Vector3 = (pos - _last_pos) / delta
		_speed = lerpf(_speed, Vector2(v.x, v.z).length(), clampf(delta * 10.0, 0.0, 1.0))
	_last_pos = pos
	var flags: int = p.remote_flags if not p.is_bot else p.state_flags()
	var reviving: bool = _is_reviving(p)
	set_locomotion(locomotion_for(flags, _speed, reviving))
	var def: WeaponDefinition = p.weapons.remote_def if p.weapons != null else null
	set_hold(hold_for(def))
	var full_body: bool = locomotion in [&"run", &"slide", &"downed_crawl", &"revive"]
	upper_weight = move_toward(upper_weight, 0.0 if full_body else 1.0, delta * 6.0)
	tree.set(&"parameters/upper/blend_amount", upper_weight)
	var rate: float = 1.0
	if locomotion == &"walk" or locomotion == &"crouch_walk":
		rate = clampf(_speed / WALK_SPEED_REF, 0.6, 1.8)
	elif locomotion == &"run":
		rate = clampf(_speed / RUN_SPEED_REF, 0.7, 1.5)
	tree.set(&"parameters/speed/scale", rate)
	if p.weapons != null:
		if p.weapons.remote_replays != _seen_replays:
			_seen_replays = p.weapons.remote_replays
			play_fire(def)
		if p.weapons.remote_reloads != _seen_reloads:
			_seen_reloads = p.weapons.remote_reloads
			play_action(&"reload_pistol" if hold == &"hold_pistol" else &"reload_long")
		_attach_weapon(p.weapons.tp_weapon_node(), p)


func set_locomotion(clip: StringName) -> void:
	if clip == locomotion or tree == null:
		return
	locomotion = clip
	tree.set(&"parameters/loco/transition_request", String(clip))


func set_hold(clip: StringName) -> void:
	if clip == hold or tree == null:
		return
	hold = clip
	tree.set(&"parameters/hold/transition_request", String(clip))


func play_fire(def: WeaponDefinition) -> void:
	if tree == null:
		return
	fires_played += 1
	var long: bool = def != null and def.weapon_class != WeaponDefinition.WeaponClass.PISTOL
	tree.set(&"parameters/fire_sel/transition_request", "fire_long" if long else "fire_pistol")
	tree.set(&"parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func play_action(clip: StringName) -> void:
	if tree == null or not ACTIONS.has(clip):
		return
	reloads_played += 1 if clip != &"drink" else 0
	tree.set(&"parameters/act_sel/transition_request", String(clip))
	tree.set(&"parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _is_reviving(p: PlayerCharacter) -> bool:
	var m: Match = Match.current
	if m == null or m.downed == null:
		return false
	for t: Variant in m.downed.revivers:
		if int(m.downed.revivers[t]) == p.peer_id:
			return true
	return false


# Keeps the third-person weapon in the right hand (it lives on the PlayerCharacter, not the model).
func _attach_weapon(w: Node3D, p: PlayerCharacter) -> void:
	if w == null or skeleton == null or _hand_bone < 0:
		return
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_hand_bone)
	var aim: Basis = Basis.from_euler(Vector3(p.remote_pitch if not p.is_bot else p.get_pitch(), p.rotation.y, 0.0))
	w.global_transform = Transform3D(aim, hand.origin + aim * HAND_OFFSET)
