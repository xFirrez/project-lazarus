# ZombieVisual — the presentation of a ZombieActor on every peer (ARCHITECTURE §7.1, §11.3):
# the archetype's ZombieModel variant driven by an AnimationTree built in code:
#   locomotion BlendSpace1D (idle / walk / run by speed tier, playback rate matched to speed)
#   -> mode Transition (loco / crawl / dead) -> action OneShot (attack, tear, climb, stagger;
#   seeked to the replicated action start time) -> hit-react OneShot (head / left / right /
#   stomach, upper-body filter, blended over the base pose).
# Also: procedural head look toward the target (LookAtModifier3D, near zombies only), animation
# LOD by distance to the viewer, gibs (GibModifier + ZombieFx chunks), death animation or
# ragdoll (physical bones, ZombieFx budget of 6), corpse fade, voice lines through the
# ZombieAudio priority system and footsteps.
# Authority: local presentation; reads the actor's replicated state, never writes gameplay state.
class_name ZombieVisual
extends Node3D

# Death presentation by killing weapon / archetype (Step 12): Ray Pistol disintegration (green glow,
# sinks into ash), Conduit char (blackened + sparks), Galvanic electric burst.
enum DeathFx { NONE, DISINTEGRATE, CHAR, BURST }

const DEATH_FX_NAMES: Array[StringName] = [&"", &"disintegrate", &"char", &"burst"]
const DISINTEGRATE_TIME: float = 0.9
const WALK_NATIVE: float = 1.3  # m/s at playback rate 1
const RUN_NATIVE: float = 3.8
const CRAWL_NATIVE: float = 0.8
const LOD_DISTANCES: PackedFloat32Array = [25.0, 50.0]  # full rate, every 2nd frame, every 4th frame
const LOOK_DISTANCE: float = 15.0
const CORPSE_TIME: float = 5.0
const FADE_TIME: float = 1.5
const RISE_DEPTH: float = 1.7
const UPPER_BODY: PackedStringArray = [
	"Spine",
	"Chest",
	"UpperChest",
	"Neck",
	"Head",
	"LeftShoulder",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightShoulder",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand"
]
const ACTION_CLIPS: Dictionary = {
	ZombieActor.Action.ATTACK: &"attack_swipe",
	ZombieActor.Action.TEAR: &"barricade_tear",
	ZombieActor.Action.CLIMB: &"window_climb",
	ZombieActor.Action.STAGGER: &"hit_react_stomach",
}
# Ragdoll bones: [bone, length, radius, mass]
const RAGDOLL_BONES: Array = [
	[&"Hips", 0.22, 0.15, 12.0],
	[&"Chest", 0.3, 0.17, 14.0],
	[&"Head", 0.22, 0.12, 5.0],
	[&"LeftUpperArm", 0.3, 0.06, 2.5],
	[&"LeftLowerArm", 0.3, 0.05, 1.5],
	[&"RightUpperArm", 0.3, 0.06, 2.5],
	[&"RightLowerArm", 0.3, 0.05, 1.5],
	[&"LeftUpperLeg", 0.42, 0.08, 6.0],
	[&"LeftLowerLeg", 0.42, 0.06, 4.0],
	[&"RightUpperLeg", 0.42, 0.08, 6.0],
	[&"RightLowerLeg", 0.42, 0.06, 4.0],
]

# Dread Novice's thermal scope (Step 11): while the local player aims it, zombies glow hot.
static var thermal_on: bool = false
static var _overlays: Dictionary = {}  # state -> overlay material (shared)

var actor: ZombieActor = null
var model: ZombieModel = null
var tree: AnimationTree = null
var look: LookAtModifier3D = null
var look_target: Node3D = null
var gibber: GibModifier = null
var dead: bool = false
var ragdolled: bool = false
var lod: int = 0
var react_count: int = 0
var last_react: StringName = &""
var death_style: String = ""  # "ragdoll" | "animation"
var gib_mask: int = 0
var death_fx: int = DeathFx.NONE
var extra: Node3D = null  # archetype extra visual (Warden armor, Galvanic electrodes)

var _bt: AnimationNodeBlendTree = null
var _gait: float = 0.0
var _shown_action: int = -1
var _shown_action_time: float = -1.0
var _was_crawler: bool = false
var _lod_accum: float = 0.0
var _lod_frame: int = 0
var _voice_timer: float = 0.0
var _step_phase: float = 0.0
var _was_aggro: bool = false
var _ragdoll_sim: PhysicalBoneSimulator3D = null
var _corpse_timer: float = 0.0
var _fading: bool = false
var _pitch: float = 1.0
var _overlay_state: int = -1
var _geoms: Array[GeometryInstance3D] = []


func _ready() -> void:
	actor = get_parent() as ZombieActor
	var arch: ZombieArchetype = actor.archetype
	var scene: PackedScene = arch.variants[clampi(actor.variant, 0, arch.variants.size() - 1)]
	model = scene.instantiate() as ZombieModel
	model.autoplay = &""
	if not is_equal_approx(arch.model_scale, 1.0):
		model.scale = Vector3.ONE * arch.model_scale
	add_child(model)
	if arch.extra_visual != null:
		extra = arch.extra_visual.new() as Node3D
		extra.name = "Extra"
		extra.set_meta(&"visual", self)
		add_child(extra)
	_pitch = randf_range(arch.voice_pitch_range.x, arch.voice_pitch_range.y)
	_voice_timer = randf_range(0.5, arch.groan_interval.y)
	if model.skeleton == null:
		return
	_build_tree()
	_build_modifiers()
	if actor.spawn_kind == ZombieSpawner.Kind.RISER and actor.action == ZombieActor.Action.RISE:
		model.position.y = -RISE_DEPTH


func _build_tree() -> void:
	_bt = AnimationNodeBlendTree.new()
	var loco: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 2.0
	loco.add_blend_point(_anim(&"idle"), 0.0, -1, &"idle")
	loco.add_blend_point(_anim(&"walk"), 1.0, -1, &"walk")
	loco.add_blend_point(_anim(&"run"), 2.0, -1, &"run")
	_bt.add_node(&"loco", loco)
	_bt.add_node(&"loco_rate", AnimationNodeTimeScale.new())
	_bt.connect_node(&"loco_rate", 0, &"loco")
	_bt.add_node(&"crawl", _anim(&"crawl"))
	_bt.add_node(&"crawl_rate", AnimationNodeTimeScale.new())
	_bt.connect_node(&"crawl_rate", 0, &"crawl")
	_bt.add_node(&"death", _anim(&"death_back"))
	var mode: AnimationNodeTransition = AnimationNodeTransition.new()
	mode.input_count = 3
	mode.set_input_name(0, "loco")
	mode.set_input_name(1, "crawl")
	mode.set_input_name(2, "dead")
	mode.xfade_time = 0.2
	_bt.add_node(&"mode", mode)
	_bt.connect_node(&"mode", 0, &"loco_rate")
	_bt.connect_node(&"mode", 1, &"crawl_rate")
	_bt.connect_node(&"mode", 2, &"death")
	var action: AnimationNodeOneShot = AnimationNodeOneShot.new()
	action.fadein_time = 0.12
	action.fadeout_time = 0.2
	_bt.add_node(&"action", action)
	_bt.add_node(&"action_clip", _anim(&"attack_swipe"))
	_bt.add_node(&"action_seek", AnimationNodeTimeSeek.new())
	_bt.add_node(&"action_rate", AnimationNodeTimeScale.new())
	_bt.connect_node(&"action_seek", 0, &"action_clip")
	_bt.connect_node(&"action_rate", 0, &"action_seek")
	_bt.connect_node(&"action", 0, &"mode")
	_bt.connect_node(&"action", 1, &"action_rate")
	var react: AnimationNodeOneShot = AnimationNodeOneShot.new()
	react.fadein_time = 0.05
	react.fadeout_time = 0.18
	react.filter_enabled = true
	for b: String in UPPER_BODY:
		react.set_filter_path(NodePath("%GeneralSkeleton:" + b), true)
	_bt.add_node(&"react", react)
	_bt.add_node(&"react_clip", _anim(&"hit_react_stomach"))
	_bt.connect_node(&"react", 0, &"action")
	_bt.connect_node(&"react", 1, &"react_clip")
	_bt.connect_node(&"output", 0, &"react")
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.add_animation_library(ZombieModel.LIBRARY, model.animations)
	model.add_child(tree)
	tree.root_node = tree.get_path_to(model.model)
	tree.tree_root = _bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	tree.set(&"parameters/loco_rate/scale", 1.0)
	tree.set(&"parameters/crawl_rate/scale", 1.0)
	tree.set(&"parameters/action_rate/scale", 1.0)
	tree.set(&"parameters/mode/transition_request", "loco")


func _build_modifiers() -> void:
	var sk: Skeleton3D = model.skeleton
	look_target = Node3D.new()
	look_target.name = "LookTarget"
	look_target.top_level = true
	add_child(look_target)
	look = LookAtModifier3D.new()
	look.name = "HeadLook"
	look.bone_name = "Head"
	look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	look.use_angle_limitation = true
	look.symmetry_limitation = true
	look.primary_limit_angle = deg_to_rad(110.0)
	look.secondary_limit_angle = deg_to_rad(70.0)
	look.duration = 0.25
	look.influence = 0.0
	sk.add_child(look)
	look.target_node = look.get_path_to(look_target)
	gibber = GibModifier.new()
	gibber.name = "Gibs"
	sk.add_child(gibber)


func _anim(clip: StringName) -> AnimationNodeAnimation:
	var n: AnimationNodeAnimation = AnimationNodeAnimation.new()
	n.animation = StringName("%s/%s" % [ZombieModel.LIBRARY, clip])
	return n


# --- per frame --------------------------------------------------------------------------------


func _process(delta: float) -> void:
	if tree == null:
		return
	if dead:
		_process_corpse(delta)
		_advance(delta)
		return
	var view_d: float = _viewer_distance()
	lod = 0 if view_d < LOD_DISTANCES[0] else (1 if view_d < LOD_DISTANCES[1] else 2)
	_update_locomotion(delta)
	_update_action()
	_update_rise()
	_update_look(view_d, delta)
	_update_audio(delta, view_d)
	_update_status()
	if actor.flags & ZombieActor.Flag.FROZEN != 0:
		return  # frozen solid: the pose holds (Coolant Purge)
	_advance(delta)


# Status tint from the replicated flags: frozen = ice, burning = embers, thermal scope = hot white.
func _update_status() -> void:
	var st: int = 0
	if actor.flags & ZombieActor.Flag.FROZEN != 0:
		st = 1
	elif actor.flags & ZombieActor.Flag.BURNING != 0:
		st = 2
	elif actor.flags & ZombieActor.Flag.ELECTROCUTED != 0:
		st = 4
	elif thermal_on:
		st = 3
	elif actor.archetype.glow_color.a > 0.0:
		st = 5
	if st == _overlay_state:
		return
	_overlay_state = st
	if _geoms.is_empty():
		for n: Node in model.find_children("*", "GeometryInstance3D", true, false):
			_geoms.append(n as GeometryInstance3D)
	var mat: Material = overlay_material(st) if st != 5 else glow_material(actor.archetype)
	for g: GeometryInstance3D in _geoms:
		if is_instance_valid(g):
			g.material_overlay = mat


static func death_fx_id(fx_name: StringName) -> int:
	return maxi(DEATH_FX_NAMES.find(fx_name), 0)


# Archetype glow (Galvanic electrodes): emissive additive overlay, shared per archetype.
static func glow_material(arch: ZombieArchetype) -> Material:
	var key: String = "glow_%s" % arch.id
	if not _overlays.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = arch.glow_color
		m.emission_enabled = true
		m.emission = Color(arch.glow_color.r, arch.glow_color.g, arch.glow_color.b) * 1.2
		_overlays[key] = m
	return _overlays[key]


static func overlay_material(st: int) -> Material:
	if st == 0:
		return null
	if st == 4:
		if not _overlays.has(4):
			var e: StandardMaterial3D = StandardMaterial3D.new()
			e.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			e.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			e.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			e.albedo_color = Color(0.55, 0.85, 1.0, 0.7)
			_overlays[4] = e
		return _overlays[4]
	if st == 6 or st == 7:
		if not _overlays.has(st):
			var d: StandardMaterial3D = StandardMaterial3D.new()
			d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			d.albedo_color = Color(0.35, 1.0, 0.45, 0.8) if st == 6 else Color(0.03, 0.03, 0.03, 0.85)
			d.emission_enabled = st == 6
			d.emission = Color(0.35, 1.0, 0.45) * 2.0
			d.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if st == 6 else BaseMaterial3D.BLEND_MODE_MIX
			_overlays[st] = d
		return _overlays[st]
	if not _overlays.has(st):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if st == 3 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if st != 1 else BaseMaterial3D.BLEND_MODE_MIX
		var c: Color = [Color(), Color(0.65, 0.85, 1.0, 0.75), Color(1.0, 0.35, 0.05, 0.45), Color(1.0, 0.9, 0.6, 0.8)][st]
		m.albedo_color = c
		m.emission_enabled = st != 1
		m.emission = Color(c.r, c.g, c.b) * (1.5 if st == 3 else 0.8)
		if st == 1:
			m.roughness = 0.1
			m.metallic_specular = 1.0
		_overlays[st] = m
	return _overlays[st]


func _advance(delta: float) -> void:
	_lod_accum += delta
	_lod_frame += 1
	var every: int = 1 << lod  # 1, 2, 4
	if _lod_frame % every == 0 or dead:
		tree.advance(_lod_accum)
		_lod_accum = 0.0


func _viewer_distance() -> float:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		return cam.global_position.distance_to(actor.global_position)
	return 0.0


func _update_locomotion(delta: float) -> void:
	var crawler: bool = actor.is_crawler() or actor.action == ZombieActor.Action.VENT
	if crawler != _was_crawler:
		tree.set(&"parameters/mode/transition_request", "crawl" if crawler else "loco")
		if actor.is_crawler() and not _was_crawler and gib_mask & (ZombieSync.Gib.LEG_L | ZombieSync.Gib.LEG_R) == 0:
			_apply_gibs(ZombieSync.Gib.LEG_L | ZombieSync.Gib.LEG_R, Vector3.UP)
		_was_crawler = crawler
	var spd: float = actor.speed
	if crawler:
		tree.set(&"parameters/crawl_rate/scale", clampf(spd / CRAWL_NATIVE, 0.2, 2.0))
		return
	var want: float = 0.0
	if spd > 0.15:
		want = (
			1.0 if actor.tier <= ZombieArchetype.Tier.WALK else (1.6 if actor.tier == ZombieArchetype.Tier.JOG else 2.0)
		)
	_gait = move_toward(_gait, want, delta * 3.0)
	tree.set(&"parameters/loco/blend_position", _gait)
	var native: float = lerpf(WALK_NATIVE, RUN_NATIVE, clampf(_gait - 1.0, 0.0, 1.0))
	var rate: float = clampf(spd / native, 0.5, 1.8) if _gait > 0.5 else 1.0
	tree.set(&"parameters/loco_rate/scale", rate)


func _update_action() -> void:
	if actor.action == _shown_action and is_equal_approx(actor.action_time, _shown_action_time):
		return
	_shown_action = actor.action
	_shown_action_time = actor.action_time
	var clip: StringName = ACTION_CLIPS.get(actor.action, &"")
	if clip == &"":
		if tree.get(&"parameters/action/active"):
			tree.set(&"parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		return
	(_bt.get_node(&"action_clip") as AnimationNodeAnimation).animation = StringName(
		"%s/%s" % [ZombieModel.LIBRARY, clip]
	)
	var rate: float = 1.0
	if actor.action == ZombieActor.Action.TEAR:
		rate = actor.archetype.tear_time / actor.archetype.tear_time_for(actor.tier)
	elif actor.action == ZombieActor.Action.CLIMB:
		rate = 1.2 / actor.archetype.climb_time
	tree.set(&"parameters/action_rate/scale", rate)
	var elapsed: float = maxf(Net.host_time() - actor.action_time, 0.0) if Net.is_active() else 0.0
	tree.set(&"parameters/action_seek/seek_request", elapsed * rate)
	tree.set(&"parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	if actor.action == ZombieActor.Action.ATTACK:
		_voice(&"zombie_attack", 0.5, true)


func _update_rise() -> void:
	if model.position.y >= 0.0:
		return
	if actor.action != ZombieActor.Action.RISE:
		model.position.y = 0.0
		return
	var t: float = (Net.host_time() - actor.action_time) if Net.is_active() else 0.0
	if not Net.is_active() and actor.sim != null:
		t = actor.sim.state_time
	model.position.y = -RISE_DEPTH * (1.0 - clampf(t / ZombieSim.RISE_TIME, 0.0, 1.0))


func _update_look(view_d: float, delta: float) -> void:
	var want: float = 0.0
	if view_d < LOOK_DISTANCE and actor.look_target != Vector3.INF and actor.action != ZombieActor.Action.CLIMB:
		look_target.global_position = actor.look_target
		want = 0.85
	elif actor.sim == null and view_d < LOOK_DISTANCE:
		# Clients don't replicate the target: look at the nearest player.
		var p: Vector3 = _nearest_player()
		if p != Vector3.INF and p.distance_to(actor.global_position) < 8.0:
			look_target.global_position = p + Vector3.UP * 1.5
			want = 0.85
	look.influence = move_toward(look.influence, want, delta * 3.0)
	look.active = look.influence > 0.01


func _nearest_player() -> Vector3:
	var ps: PlayerSync = Match.current.players if Match.current != null else null
	if ps == null:
		return Vector3.INF
	var best: Vector3 = Vector3.INF
	for id: int in ps.avatars:
		var p: Vector3 = (ps.avatars[id] as PlayerCharacter).global_position
		if (
			best == Vector3.INF
			or p.distance_squared_to(actor.global_position) < best.distance_squared_to(actor.global_position)
		):
			best = p
	return best


func _update_audio(delta: float, view_d: float) -> void:
	var aggro: bool = actor.flags & ZombieActor.Flag.AGGRO != 0
	if aggro and not _was_aggro and actor.tier >= ZombieArchetype.Tier.RUN:
		_voice(&"zombie_scream", 0.9, false, view_d)
	_was_aggro = aggro
	_voice_timer -= delta
	if _voice_timer <= 0.0:
		var arch: ZombieArchetype = actor.archetype
		_voice_timer = randf_range(arch.groan_interval.x, arch.groan_interval.y)
		_voice(ZombieAudio.groan_event(actor.net_id + randi() % 3), 1.5, false, view_d)
	if view_d < 15.0 and actor.speed > 0.3 and not actor.is_crawler():
		_step_phase += delta * actor.speed / 0.7
		if _step_phase >= 1.0:
			_step_phase -= 1.0
			Audio.play_event_3d(&"zombie_step", actor.global_position, _pitch)


func _voice(event: StringName, seconds: float, force: bool, distance: float = -1.0) -> void:
	var d: float = distance if distance >= 0.0 else _viewer_distance()
	if force or ZombieAudio.request_voice(get_instance_id(), d, seconds):
		Audio.play_event_3d(event, actor.global_position + Vector3.UP * 1.6, _pitch)


# --- reactions --------------------------------------------------------------------------------


func on_hit(_amount: float, zone: int, kind: int, lethal: bool) -> void:
	if tree == null or dead or lethal:
		return
	var clip: StringName = &"hit_react_stomach"
	match zone:
		WeaponDefinition.Hitzone.HEAD, WeaponDefinition.Hitzone.NECK:
			clip = &"hit_react_head"
		WeaponDefinition.Hitzone.LIMB:
			clip = &"hit_react_left" if (react_count + actor.net_id) % 2 == 0 else &"hit_react_right"
	if kind == DamageInfo.Kind.EXPLOSIVE:
		clip = &"hit_react_stomach"
	(_bt.get_node(&"react_clip") as AnimationNodeAnimation).animation = StringName(
		"%s/%s" % [ZombieModel.LIBRARY, clip]
	)
	tree.set(&"parameters/react/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	react_count += 1
	last_react = clip
	if react_count % 3 == 1:
		_voice(&"zombie_pain", 0.3, false)


func die(p_gib_mask: int, dir: Vector3, _zone: int, _kind: int) -> void:
	if dead:
		return
	dead = true
	actor.set_collision_enabled(false)
	if tree == null:
		actor.queue_free()
		return
	look.active = false
	model.position.y = 0.0
	_apply_gibs(p_gib_mask, dir)
	_voice(&"zombie_death", 1.1, true)
	_present_death_fx()
	var fx: ZombieFx = _fx()
	if fx != null and death_fx != DeathFx.DISINTEGRATE and fx.acquire_ragdoll(self):
		_start_ragdoll(dir)
	else:
		death_style = "animation"
		tree.set(&"parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		tree.set(&"parameters/mode/transition_request", "dead")
	_corpse_timer = CORPSE_TIME


func _present_death_fx() -> void:
	if death_fx == DeathFx.NONE:
		return
	var at: PackedVector3Array = PackedVector3Array([actor.global_position + Vector3.UP * 1.0])
	var wfx: WonderFx = WonderFx.of(self)
	match death_fx:
		DeathFx.DISINTEGRATE:
			_set_overlay(overlay_material(6))
			# Sinks into green ash (moving, not scaling: the hurtbox shapes ride the skeleton).
			var tw: Tween = create_tween()
			tw.tween_property(model, ^"position:y", -RISE_DEPTH, DISINTEGRATE_TIME).set_ease(Tween.EASE_IN)
			if wfx != null:
				wfx.present(WonderFx.Kind.BURST, at, 1.2, WonderFx.Variant.GREEN)
			Audio.play_event_3d(&"ray_disintegrate", actor.global_position)
		DeathFx.CHAR:
			_set_overlay(overlay_material(7))
			if wfx != null:
				wfx.present(WonderFx.Kind.SPARKS, at, 1.0, WonderFx.Variant.ELECTRIC)
		DeathFx.BURST:
			if wfx != null:
				wfx.present(WonderFx.Kind.BURST, at, 3.0, WonderFx.Variant.ELECTRIC)
			Audio.play_event_3d(&"galvanic_burst", actor.global_position)


# Overlays on imported GLB meshes must be cleared before the meshes are freed (headless shutdown
# errors otherwise; same rule as WeaponCamo).
func _exit_tree() -> void:
	for g: GeometryInstance3D in _geoms:
		if is_instance_valid(g):
			g.material_overlay = null


func _set_overlay(mat: Material) -> void:
	_overlay_state = 99  # keep the death overlay (status updates stop with death)
	if _geoms.is_empty():
		for n: Node in model.find_children("*", "GeometryInstance3D", true, false):
			_geoms.append(n as GeometryInstance3D)
	for g: GeometryInstance3D in _geoms:
		if is_instance_valid(g):
			g.material_overlay = mat


func _apply_gibs(mask: int, dir: Vector3) -> void:
	if mask == 0 or gibber == null:
		return
	gib_mask |= mask
	var sk: Skeleton3D = model.skeleton
	var fx: ZombieFx = _fx()
	var parts: Array = [
		[ZombieSync.Gib.HEAD, &"Head", 4],
		[ZombieSync.Gib.ARM_L, &"LeftLowerArm", 2],
		[ZombieSync.Gib.ARM_R, &"RightLowerArm", 2],
		[ZombieSync.Gib.LEG_L, &"LeftLowerLeg", 2],
		[ZombieSync.Gib.LEG_R, &"RightLowerLeg", 2]
	]
	for p: Array in parts:
		if mask & int(p[0]) == 0:
			continue
		var bone: int = sk.find_bone(p[1])
		gibber.hide_bone(bone)
		if fx != null and bone >= 0:
			fx.spawn_gibs((sk.global_transform * sk.get_bone_global_pose(bone)).origin, dir, int(p[2]))


func _fx() -> ZombieFx:
	var zs: ZombieSync = ZombieSync.instance(self)
	return zs.fx if zs != null else null


func _start_ragdoll(dir: Vector3) -> void:
	death_style = "ragdoll"
	ragdolled = true
	var sk: Skeleton3D = model.skeleton
	tree.active = false
	_ragdoll_sim = PhysicalBoneSimulator3D.new()
	_ragdoll_sim.name = "Ragdoll"
	sk.add_child(_ragdoll_sim)
	sk.move_child(_ragdoll_sim, look.get_index())  # before the gib modifier
	for b: Array in RAGDOLL_BONES:
		var pb: PhysicalBone3D = PhysicalBone3D.new()
		pb.name = "PB_%s" % b[0]
		pb.bone_name = b[0]
		pb.mass = float(b[3])
		pb.collision_layer = 0
		pb.collision_mask = 1
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE if b[0] != &"Hips" else PhysicalBone3D.JOINT_TYPE_NONE
		var half: float = float(b[1]) * 0.5
		pb.body_offset = Transform3D(Basis(), Vector3(0, half, 0))
		pb.joint_offset = Transform3D(Basis(), Vector3(0, -half, 0))
		pb.linear_damp = 0.3
		pb.angular_damp = 2.0
		var cs: CollisionShape3D = CollisionShape3D.new()
		var cap: CapsuleShape3D = CapsuleShape3D.new()
		cap.radius = float(b[2])
		cap.height = maxf(float(b[1]), float(b[2]) * 2.0 + 0.01)
		cs.shape = cap
		pb.add_child(cs)
		_ragdoll_sim.add_child(pb)
	_ragdoll_sim.physical_bones_start_simulation()
	var push: Vector3 = (dir.normalized() if dir.length() > 0.01 else Vector3.BACK) * 2.5 + Vector3.UP * 0.8
	for pb: Node in _ragdoll_sim.get_children():
		if pb.name in [&"PB_Chest", &"PB_Head"]:
			(pb as PhysicalBone3D).apply_central_impulse(push * (pb as PhysicalBone3D).mass * 0.6)
	Audio.play_event_3d(&"zombie_body_fall", actor.global_position)


# Pool overflow: stop the bodies where they are (asleep, no gravity) and start the fade early.
func freeze_ragdoll() -> void:
	if _ragdoll_sim == null:
		return
	for pb: Node in _ragdoll_sim.get_children():
		var b: PhysicalBone3D = pb as PhysicalBone3D
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		b.gravity_scale = 0.0
		b.linear_damp = 100.0
		b.angular_damp = 100.0
	_corpse_timer = minf(_corpse_timer, 1.0)


func ragdoll_root_position() -> Vector3:
	if _ragdoll_sim == null:
		return actor.global_position
	var hips: PhysicalBone3D = _ragdoll_sim.get_node_or_null(^"PB_Hips") as PhysicalBone3D
	return hips.global_position if hips != null else actor.global_position


func _process_corpse(delta: float) -> void:
	_corpse_timer -= delta
	if _corpse_timer > 0.0:
		return
	if not _fading:
		_fading = true
		var fx: ZombieFx = _fx()
		if fx != null:
			fx.release_ragdoll(self)
		if _ragdoll_sim != null:
			freeze_ragdoll()
	var t: float = -_corpse_timer / FADE_TIME
	if _ragdoll_sim != null:
		# Simulated bones follow their bodies, so sink the bodies themselves.
		for pb: Node in _ragdoll_sim.get_children():
			(pb as PhysicalBone3D).global_position += Vector3.DOWN * 0.6 / FADE_TIME * delta
	else:
		model.position.y = -0.6 * t
	if t >= 1.0:
		actor.queue_free()
