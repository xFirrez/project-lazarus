# WeaponController — the player's weapons (ARCHITECTURE §6.2). On the LOCAL player it consumes
# PlayerInputFrames (fire, aim, reload, melee, lethal, switching), steps the held WeaponRuntime,
# performs the shots locally ("favor the shooter": spread + behavior raycasts against what this
# peer sees), shows all feedback immediately (viewmodel, recoil, flash, shells, tracers, impacts,
# decals, hit markers, sounds) and hands shot/hit claims to WeaponSync for the host. On REMOTE
# puppets it shows a third-person weapon and replays relayed fire bursts cosmetically from their
# seed (tracers, flash, impacts, spatial audio).
# Authority: owner simulates its weapons; the host validates claims and owns the loadout.
class_name WeaponController
extends Node

signal shot_fired(def: WeaponDefinition, result: Ballistics.ShotResult)
signal hit_confirmed(target: HitTarget, damage: float, zone: int, kill: bool)
signal weapon_changed(def: WeaponDefinition)

const KNIFE_ID: StringName = &"knife"
const FRAG_ID: StringName = &"frag"
const DEFAULT_LOADOUT: Array[StringName] = [&"m1911"]
const LUNGE_TIME: float = 0.15
const SNAP_CONE_DEG: float = 8.0  # Bullseye Bitters ADS head snap cone / range
const SNAP_RANGE: float = 35.0

var player: PlayerCharacter = null
var inventory: WeaponInventory = WeaponInventory.new()
var viewmodel: Viewmodel = null
var hud: WeaponHud = null
var behaviors: Dictionary = {}  # weapon id -> WeaponBehavior
# Debug / test switches.
var recoil_enabled: bool = true
var perfect_accuracy: bool = false
var shots_total: int = 0
var remote_replays: int = 0  # puppets: relayed shots replayed on this peer
var remote_reloads: int = 0  # puppets: relayed reload starts (third-person reload layer)
var remote_def: WeaponDefinition = null  # puppets: weapon shown in third person
# Equipment (Step 9): Drummer Decoy (tactical) and tripmines (placeable); the melee weapon lives in
# `inventory.melee_def` (knife, or the Ice Axe once bought). Counts come from the host loadout.
var tactical_def: WeaponDefinition = null
var tactical_count: int = 0
var placeable_def: WeaponDefinition = null
var placeable_count: int = 0
# Vigor Tonic drink (Step 10): weapon lowered, a bottle in the viewmodel, no firing for DRINK_TIME.
var drinking_def: PerkDefinition = null
var drink_left: float = 0.0
var drinks: int = 0
var aim_snaps: int = 0  # Bullseye Bitters ADS head snaps (tests)
# Forge upgrades (Step 11): alt-fire attachments keep their own runtime (magazine) per attachment id;
# dual-wield weapons alternate the muzzle between the two guns.
var alt_runtimes: Dictionary = {}  # attachment id -> WeaponRuntime
var alt_shots: int = 0
var _left_hand: bool = false
var _equip_seq: int = 0
var _drink_total: float = 0.0
var _drink_bottle: Node3D = null
var _aim_was: bool = false
var _snap_left: float = 0.0
var _snap_yaw: float = 0.0
var _snap_pitch: float = 0.0

var _shot_seq: int = 0
var _throw_seq: int = 0
var _cook_time: float = -1.0
var _lethal_was_held: bool = false
var _recover: float = 0.0  # degrees of vertical recoil still to recover
var _since_fire: float = 10.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _vm_layer: CanvasLayer = null
var _tp_weapon: Node3D = null
var _tp_muzzle: Node3D = null
var _tp_model: Node3D = null


func setup(p_player: PlayerCharacter) -> void:
	player = p_player
	name = "Weapons"
	_rng.seed = hash([p_player.peer_id, Time.get_ticks_usec()])
	inventory.current_changed.connect(_on_current_changed)
	inventory.melee_def = WeaponCatalog.get_def(KNIFE_ID)
	inventory.lethal_def = WeaponCatalog.get_def(FRAG_ID)
	if inventory.lethal_def != null:
		inventory.lethal_count = inventory.lethal_def.carry_start
	if inventory.melee_def != null:
		WeaponAudio.ensure(inventory.melee_def)
	WeaponAudio.ensure_common()
	if player.is_local:
		_vm_layer = CanvasLayer.new()
		_vm_layer.name = "ViewmodelLayer"
		_vm_layer.layer = 4
		_vm_layer.add_to_group(&"hide_for_shots")
		player.add_child(_vm_layer)
		viewmodel = Viewmodel.new()
		viewmodel.name = "Viewmodel"
		if inventory.melee_def != null:
			viewmodel.melee_time = inventory.melee_def.melee_time
		add_child(viewmodel)
		viewmodel.setup(player, _vm_layer)
		hud = WeaponHud.new()
		hud.controller = self
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "WeaponHudLayer"
		layer.layer = 6
		layer.add_to_group(&"hide_for_shots")
		player.add_child(layer)
		layer.add_child(hud)
		if player.hud != null:
			player.hud.show_crosshair = false
	else:
		_build_tp_weapon()


# Local loadout without a host (tests, standalone scenes): gives the default weapons directly.
func give_default_loadout(ids: Array = DEFAULT_LOADOUT) -> void:
	apply_loadout(ids, ids[0] if not ids.is_empty() else &"", -1)
	var h: WeaponRuntime = held()
	if h != null:
		h.make_ready()


func held() -> WeaponRuntime:
	return inventory.held()


func held_def() -> WeaponDefinition:
	var h: WeaponRuntime = held()
	return h.def if h != null else null


func behavior_for(def: WeaponDefinition) -> WeaponBehavior:
	if not behaviors.has(def.id):
		behaviors[def.id] = WeaponBehavior.for_definition(def)
	return behaviors[def.id]


func cooking() -> bool:
	return _cook_time >= 0.0


func cook_time_left() -> float:
	if not cooking() or inventory.lethal_def == null:
		return 0.0
	return maxf(inventory.lethal_def.fuse_time - _cook_time, 0.0)


func current_spread() -> float:
	var h: WeaponRuntime = held()
	if h == null or perfect_accuracy:
		return 0.0
	var frac: float = player.motor.horizontal_speed() / maxf(player.tuning.sprint_speed, 0.1)
	return h.spread_deg(frac, not player.motor.grounded)


func eye_position() -> Vector3:
	return player.global_position + Vector3(0.0, player.camera_rig.eye_height, 0.0)


func aim_forward() -> Vector3:
	return -player.camera_rig.view_basis().z


# --- host-driven loadout ----------------------------------------------------------------------


func apply_loadout(ids: Array, current_id: StringName, lethal: int) -> void:
	for wid: Variant in ids:
		var d: WeaponDefinition = WeaponCatalog.get_def(StringName(wid))
		if d != null:
			WeaponAudio.ensure(d)
	inventory.set_loadout(ids, WeaponCatalog.get_def, current_id)
	if lethal >= 0:
		inventory.lethal_count = lethal


func apply_equipment(
	melee_id: StringName, tactical_id: StringName, tac_n: int, place_id: StringName, place_n: int
) -> void:
	var melee: WeaponDefinition = WeaponCatalog.get_def(melee_id)
	if melee != null and melee != inventory.melee_def:
		inventory.melee_def = melee
		WeaponAudio.ensure(melee)
		if viewmodel != null:
			viewmodel.melee_time = melee.melee_time
	tactical_def = WeaponCatalog.get_def(tactical_id) if tactical_id != &"" else null
	tactical_count = tac_n
	placeable_def = WeaponCatalog.get_def(place_id) if place_id != &"" else null
	placeable_count = place_n


# The held weapon's alt-fire attachment runtime (Skullcrusher's launcher), created on first use.
func alt_runtime() -> WeaponRuntime:
	var h: WeaponRuntime = held()
	if h == null or h.def.alt_fire_id == &"":
		return null
	if not alt_runtimes.has(h.def.alt_fire_id):
		var d: WeaponDefinition = WeaponCatalog.get_def(h.def.alt_fire_id)
		if d == null:
			return null
		WeaponAudio.ensure(d)
		var rt: WeaponRuntime = WeaponRuntime.new(d)
		rt.make_ready()
		rt.dry_fired.connect(_on_runtime_dry)
		rt.ammo_added.connect(_on_ammo_added.bind(rt))
		alt_runtimes[d.id] = rt
	return alt_runtimes[h.def.alt_fire_id]


func set_ammo(weapon_id: StringName, mag: int, reserve: int) -> void:
	if alt_runtimes.has(weapon_id):
		var art: WeaponRuntime = alt_runtimes[weapon_id]
		if mag >= 0:
			art.mag = mag
		art.reserve = reserve
	var idx: int = inventory.slot_of(weapon_id)
	if idx >= 0:
		if mag >= 0:  # -1 = keep the magazine (Max Ammo)
			inventory.slots[idx].mag = mag
		inventory.slots[idx].reserve = reserve


func set_infinite_ammo(on: bool) -> void:
	for rt: WeaponRuntime in inventory.slots:
		rt.infinite_ammo = on


# --- local simulation (physics tick) ----------------------------------------------------------


func physics_step(f: PlayerInputFrame, dt: float) -> void:
	var h: WeaponRuntime = held()
	apply_stats()
	if drink_left > 0.0:
		_update_drink(dt)
		inventory.update()
		return
	_update_aim_snap(f, dt)
	if f.switch_slot >= 0:
		inventory.switch_to(f.switch_slot)
	elif f.switch_delta != 0:
		inventory.cycle(f.switch_delta)
	if f.melee_pressed:
		_try_melee()
	if h != null and f.reload_pressed:
		h.start_reload()
	_update_lethal(f, dt)
	if f.tactical_pressed:
		_throw_tactical()
	if f.placeable_pressed:
		_place_mine()
	_since_fire += dt
	if h != null:
		player.motor.weapon_speed_multiplier = h.def.move_speed_multiplier
		var trigger: bool = f.fire and not cooking()
		var shots: int = h.update(dt, trigger, f.aim, player.motor.sprinting)
		for i: int in shots:
			_fire_shot(h)
		var alt: WeaponRuntime = alt_runtime()
		if alt != null and h.is_ready():
			var alt_n: int = alt.update(dt, f.alt_fire and not f.fire, false, player.motor.sprinting)
			for i: int in alt_n:
				alt_shots += 1
				_fire_shot(alt)
		if player.is_local:
			ZombieVisual.thermal_on = h.def.thermal_scope and h.ads > 0.6
	inventory.update()
	_update_recoil_recovery(dt)


# Perk stats (PlayerStats) onto every held runtime and the slot count (Quickdraw, Twin-Fire,
# Bullseye, Pack Mule). Cheap: a few dictionary lookups per tick.
func apply_stats() -> void:
	if player == null:
		return
	var st: PlayerStats = player.stats()
	var speed: float = st.value(PlayerStats.RELOAD_SPEED, 1.0)
	var rate: float = st.value(PlayerStats.FIRE_RATE, 1.0)
	var hip: float = st.value(PlayerStats.HIP_SPREAD, 1.0)
	for rt: WeaponRuntime in inventory.slots:
		rt.speed_multiplier = speed
		rt.rate_multiplier = rate
		rt.hip_multiplier = hip
	inventory.slot_count = WeaponSync.PRIMARY_SLOTS + int(st.value(PlayerStats.WEAPON_SLOTS, 0.0))


# --- Vigor Tonic drink --------------------------------------------------------------------------


func is_drinking() -> bool:
	return drink_left > 0.0


# Owner (PerkSystem `_perk_drink`): lower the weapon, show the perk's bottle for `seconds`.
func begin_drink(def: PerkDefinition, seconds: float) -> void:
	drinking_def = def
	drink_left = seconds
	_drink_total = seconds
	drinks += 1
	_cook_time = -1.0
	var h: WeaponRuntime = held()
	if h != null:
		h.holster()
	if viewmodel != null and viewmodel.sway_root != null:
		if _drink_bottle != null:
			_drink_bottle.queue_free()
		_drink_bottle = PerkBottle.build(def, Viewmodel.LAYER)
		_drink_bottle.scale = Vector3.ONE * 1.4
		viewmodel.sway_root.add_child(_drink_bottle)
		_pose_bottle(0.0)


func cancel_drink() -> void:
	if drink_left <= 0.0:
		return
	drink_left = 0.0
	_end_drink()


func _update_drink(dt: float) -> void:
	drink_left = maxf(drink_left - dt, 0.0)
	_pose_bottle(1.0 - drink_left / maxf(_drink_total, 0.01))
	if drink_left <= 0.0:
		_end_drink()


func _end_drink() -> void:
	drinking_def = null
	if _drink_bottle != null:
		_drink_bottle.queue_free()
		_drink_bottle = null
	var h: WeaponRuntime = held()
	if h != null and not player.health.is_downed:
		h.raise()  # raise speed follows reload_speed (Quickdraw raises faster, GAME_DESIGN §8)


# Bottle path in viewmodel space: up from below, tilt to the mouth, drink, drop away.
func _pose_bottle(u: float) -> void:
	if _drink_bottle == null:
		return
	var up: float = smoothstep(0.0, 0.2, u)
	var tilt: float = smoothstep(0.15, 0.35, u) * (1.0 - smoothstep(0.85, 1.0, u))
	var down: float = smoothstep(0.85, 1.0, u)
	_drink_bottle.position = Vector3(0.06 - 0.04 * tilt, lerpf(-0.45, -0.17, up) + 0.07 * tilt - 0.4 * down, -0.32)
	_drink_bottle.rotation = Vector3(deg_to_rad(95.0) * tilt + sin(u * 40.0) * 0.03 * tilt, 0.0, deg_to_rad(-12.0))


# --- Bullseye Bitters: ADS snaps to the nearest zombie head in a small cone ----------------------


func _update_aim_snap(f: PlayerInputFrame, dt: float) -> void:
	var snap_time: float = player.stats().value(PlayerStats.AIM_SNAP, 0.0)
	if f.aim and not _aim_was and snap_time > 0.0:
		var head: Vector3 = snap_target()
		if head != Vector3.INF:
			var dir: Vector3 = (head - eye_position()).normalized()
			_snap_yaw = atan2(-dir.x, -dir.z)
			_snap_pitch = asin(clampf(dir.y, -1.0, 1.0))
			_snap_left = snap_time
			aim_snaps += 1
	_aim_was = f.aim
	if _snap_left <= 0.0 or not f.aim:
		_snap_left = 0.0
		return
	var k: float = clampf(dt / _snap_left, 0.0, 1.0)
	_snap_left -= dt
	var rig: CameraRig = player.camera_rig
	rig.yaw = lerp_angle(rig.yaw, _snap_yaw, k)
	rig.pitch = lerpf(rig.pitch, _snap_pitch, k)


# Nearest visible zombie head within SNAP_CONE_DEG of the view (Vector3.INF = none).
func snap_target() -> Vector3:
	var zs: ZombieSync = ZombieSync.instance(player)
	if zs == null:
		return Vector3.INF
	var eye: Vector3 = eye_position()
	var fwd: Vector3 = aim_forward()
	var best: Vector3 = Vector3.INF
	var best_angle: float = deg_to_rad(SNAP_CONE_DEG)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for a: ZombieActor in zs.actors.values():
		if not a.alive:
			continue
		for hb: Hurtbox in a.hurtboxes:
			if hb.zone != WeaponDefinition.Hitzone.HEAD:
				continue
			var to: Vector3 = hb.global_position - eye
			var d: float = to.length()
			if d > SNAP_RANGE or d < 0.5:
				continue
			var ang: float = fwd.angle_to(to / d)
			if ang >= best_angle:
				continue
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, hb.global_position, 1)
			if not space.intersect_ray(q).is_empty():
				continue
			best_angle = ang
			best = hb.global_position
	return best


func _fire_shot(h: WeaponRuntime) -> void:
	var def: WeaponDefinition = h.def
	_shot_seq += 1
	shots_total += 1
	_since_fire = 0.0
	var ctx: WeaponBehavior.ShotContext = WeaponBehavior.ShotContext.new()
	ctx.space = player.get_world_3d().direct_space_state
	ctx.def = def
	ctx.origin = eye_position()
	ctx.forward = aim_forward()
	ctx.spread_deg = current_spread()
	ctx.seed = Ballistics.shot_seed(player.peer_id, _shot_seq)
	var result: Ballistics.ShotResult = behavior_for(def).fire(ctx)
	_apply_recoil(def, h)
	_present_local_shot(def, h, result)
	_confirm_hits(def, result)
	WeaponSync.submit_shot(self, def, _shot_seq, ctx, result)
	shot_fired.emit(def, result)


func _try_melee() -> void:
	var knife: WeaponDefinition = inventory.melee_def
	var h: WeaponRuntime = held()
	if knife == null or cooking():
		return
	if h != null and not h.start_melee(knife.melee_time):
		return
	_shot_seq += 1
	var ctx: WeaponBehavior.ShotContext = WeaponBehavior.ShotContext.new()
	ctx.space = player.get_world_3d().direct_space_state
	ctx.def = knife
	ctx.origin = eye_position()
	ctx.forward = aim_forward()
	ctx.seed = Ballistics.shot_seed(player.peer_id, _shot_seq)
	var result: Ballistics.ShotResult = behavior_for(knife).fire(ctx)
	if viewmodel != null:
		viewmodel.play(&"melee")
	if not result.hits.is_empty():
		var rec: Ballistics.HitRecord = result.hits[0]
		var flat: Vector3 = rec.position - ctx.origin
		flat.y = 0.0
		var lunge_dist: float = maxf(flat.length() - knife.melee_reach, 0.0)
		if lunge_dist > 0.05:
			player.motor.lunge(flat.normalized() * (lunge_dist / LUNGE_TIME), LUNGE_TIME)
		Audio.play_event(&"melee_hit")
		WeaponFx.of(self).impact(result.impacts[0], false)
	_confirm_hits(knife, result)
	WeaponSync.submit_shot(self, knife, _shot_seq, ctx, result)
	shot_fired.emit(knife, result)


func _update_lethal(f: PlayerInputFrame, dt: float) -> void:
	var def: WeaponDefinition = inventory.lethal_def
	var pressed: bool = f.lethal_held and not _lethal_was_held
	var released: bool = not f.lethal_held and _lethal_was_held
	_lethal_was_held = f.lethal_held
	if def == null:
		return
	if pressed and not cooking() and inventory.lethal_count > 0:
		_cook_time = 0.0
		Audio.play_event(&"frag_pin")
		return
	if not cooking():
		return
	_cook_time += dt
	if _cook_time >= def.fuse_time:
		_throw(def, 0.0)  # cooked too long: it goes off in hand
	elif released:
		_throw(def, def.throw_speed)


func _throw(def: WeaponDefinition, speed: float) -> void:
	var fuse_left: float = maxf(def.fuse_time - _cook_time, 0.0)
	_cook_time = -1.0
	inventory.lethal_count -= 1
	_throw_seq += 1
	var fwd: Vector3 = aim_forward()
	var origin: Vector3 = eye_position() + fwd * 0.4 + Vector3.DOWN * 0.1
	var vel: Vector3 = fwd * speed + Vector3.UP * (2.5 if speed > 0.0 else 0.0) + player.velocity * 0.5
	Audio.play_event(&"frag_throw")
	WeaponSync.submit_throw(self, def, _throw_seq, origin, vel, fuse_left)


func _throw_tactical() -> void:
	if tactical_def == null or tactical_count <= 0 or cooking():
		return
	tactical_count -= 1
	_equip_seq += 1
	var fwd: Vector3 = aim_forward()
	var origin: Vector3 = eye_position() + fwd * 0.4 + Vector3.DOWN * 0.1
	var vel: Vector3 = fwd * tactical_def.throw_speed + Vector3.UP * 2.5 + player.velocity * 0.5
	Audio.play_event(&"frag_throw")
	WeaponSync.submit_tactical(self, tactical_def, 1000 + _equip_seq, origin, vel)


# Tripmine: on the floor up to 1.6 m in front of the player, facing away from them.
func _place_mine() -> void:
	if placeable_def == null or placeable_count <= 0:
		return
	var fwd: Vector3 = aim_forward()
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		return
	fwd = fwd.normalized()
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var probe: Vector3 = player.global_position + fwd * 1.2 + Vector3.UP * 0.8
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		probe, probe + Vector3.DOWN * 2.0, Ballistics.WORLD_MASK
	)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return
	placeable_count -= 1
	_equip_seq += 1
	WeaponSync.submit_mine(self, _equip_seq, hit["position"], atan2(fwd.x, fwd.z))


# --- recoil -----------------------------------------------------------------------------------


func _apply_recoil(def: WeaponDefinition, h: WeaponRuntime) -> void:
	if not recoil_enabled:
		return
	var kick: Vector2 = def.recoil_kick(h.consecutive_shots - 1)
	kick.x += _rng.randf_range(-def.recoil_random, def.recoil_random)
	kick *= lerpf(1.0, def.recoil_ads_multiplier, h.ads)
	player.camera_rig.add_look(Vector2(-deg_to_rad(kick.x), deg_to_rad(kick.y)))
	player.camera_rig.add_punch(Vector2(kick.x * 0.3, def.view_kick))
	_recover += kick.y * def.recoil_recovery


func _update_recoil_recovery(dt: float) -> void:
	var def: WeaponDefinition = held_def()
	if def == null or _recover <= 0.0 or _since_fire < def.fire_interval() * 1.2:
		return
	var step: float = minf(_recover, _recover * def.recoil_recovery_speed * dt + 0.05 * dt)
	_recover -= step
	player.camera_rig.add_look(Vector2(0.0, -deg_to_rad(step)))


# --- presentation -----------------------------------------------------------------------------


func render_update(delta: float) -> void:
	if viewmodel != null:
		viewmodel.update(delta)
		player.camera_rig.aim_offset = viewmodel.breath_offset()
		var h: WeaponRuntime = held()
		if h != null:
			player.camera.fov *= lerpf(1.0, h.def.ads_fov_multiplier, smoothstep(0.0, 1.0, h.ads))
	if _tp_weapon != null:
		_tp_weapon.rotation.x = player.remote_pitch


func _present_local_shot(def: WeaponDefinition, h: WeaponRuntime, result: Ballistics.ShotResult) -> void:
	Audio.play_event(WeaponAudio.event(def, "mech"))
	Audio.play_event(WeaponAudio.event(def, "body"))
	if def.is_upgraded():
		Audio.play_event(WeaponAudio.event(def, "zap"))  # the Forge layer (GAME_DESIGN §9.2)
	Audio.play_event(WeaponAudio.tail_event(def, player.get_world_3d().direct_space_state, eye_position()))
	var fx: WeaponFx = WeaponFx.of(self)
	var muzzle: Vector3 = eye_position() + aim_forward() * 0.5
	if viewmodel != null and viewmodel.gun != null:
		viewmodel.update(0.0)  # make sure the viewmodel follows the camera before sampling markers
		viewmodel.kick(h.ads)
		viewmodel.play(&"fire")
		_left_hand = def.dual_wield and not _left_hand
		var mx: Transform3D = viewmodel.muzzle_transform(_left_hand)
		muzzle = mx.origin
		fx.muzzle_flash(mx, def.muzzle_flash_scale, true)
		var b: Basis = player.camera_rig.view_basis()
		var eject_vel: Vector3 = b * Vector3(_rng.randf_range(1.2, 2.0), _rng.randf_range(1.5, 2.5), 0.3)
		fx.shell(viewmodel.eject_position(), eject_vel + player.velocity, def.shell_size)
	_present_impacts(def, result, muzzle, h.shots_fired)


func _present_impacts(def: WeaponDefinition, result: Ballistics.ShotResult, muzzle: Vector3, shot_n: int) -> void:
	var fx: WeaponFx = WeaponFx.of(self)
	fx.shots_shown += 1
	if def.tracer_every > 0 and shot_n % def.tracer_every == 0:
		var n: int = 0
		for end: Vector3 in result.tracer_ends:
			if n < 3:  # a few pellet tracers are plenty
				fx.tracer(muzzle, end, def.tracer_color.a > 0.0)
			n += 1
	var sounds: int = 0
	for imp: Ballistics.Impact in result.impacts:
		fx.impact(imp, sounds < 2)
		sounds += 1


func _confirm_hits(def: WeaponDefinition, result: Ballistics.ShotResult) -> void:
	if result.hits.is_empty():
		return
	var per_target: Dictionary = {}  # HitTarget -> [damage, best zone]
	for rec: Ballistics.HitRecord in result.hits:
		var dmg: float = DamageModel.melee_damage(def) if def.is_melee() else Ballistics.damage_for(def, rec)
		var e: Array = per_target.get(rec.target, [0.0, WeaponDefinition.Hitzone.LIMB])
		e[0] = float(e[0]) + dmg
		if rec.zone < int(e[1]):
			e[1] = rec.zone
		per_target[rec.target] = e
	var best: WeaponHud.Marker = WeaponHud.Marker.HIT
	for t: HitTarget in per_target:
		var e2: Array = per_target[t]
		var kill: bool = t.predicted_lethal(float(e2[0]))
		if kill:
			best = WeaponHud.Marker.KILL
		elif int(e2[1]) == WeaponDefinition.Hitzone.HEAD and best != WeaponHud.Marker.KILL:
			best = WeaponHud.Marker.HEAD
		hit_confirmed.emit(t, float(e2[0]), int(e2[1]), kill)
	if hud != null:
		hud.show_marker(best)
	match best:
		WeaponHud.Marker.KILL:
			Audio.play_event(&"hit_kill")
		WeaponHud.Marker.HEAD:
			Audio.play_event(&"hit_head")
		_:
			Audio.play_event(&"hit_body")


func _on_current_changed(_slot: int, rt: WeaponRuntime) -> void:
	_recover = 0.0
	if not rt.has_meta(&"controller_connected"):
		rt.set_meta(&"controller_connected", true)
		rt.dry_fired.connect(_on_runtime_dry)
		rt.reload_started.connect(_on_reload_started.bind(rt))
		rt.ammo_added.connect(_on_ammo_added.bind(rt))
		rt.reload_cancelled.connect(_on_reload_cancelled.bind(rt))
		rt.state_changed.connect(_on_state_changed.bind(rt))
	if viewmodel != null:
		viewmodel.set_weapon(rt.def, rt)
		if rt.state == WeaponRuntime.State.RAISING:
			viewmodel.play(&"draw")
	WeaponSync.submit_switch(self, rt.def)
	weapon_changed.emit(rt.def)


func _on_runtime_dry() -> void:
	Audio.play_event(&"wpn_dry")


func _on_reload_started(empty: bool, rt: WeaponRuntime) -> void:
	if viewmodel == null or rt != held():
		return
	WeaponSync.submit_reload_start(self)
	if rt.def.reload_per_shell:
		viewmodel.play(&"reload_start", rt.speed_multiplier)
	else:
		viewmodel.play(&"reload_empty" if empty else &"reload_partial", rt.speed_multiplier)


func _on_ammo_added(_n: int, rt: WeaponRuntime) -> void:
	WeaponSync.submit_reload(self, rt.def, rt.mag, rt.reserve)


func _on_reload_cancelled(_kept: bool, rt: WeaponRuntime) -> void:
	if viewmodel != null and rt == held() and rt.state != WeaponRuntime.State.LOWERING:
		viewmodel.play(&"idle")


func _on_state_changed(state: int, rt: WeaponRuntime) -> void:
	if viewmodel == null or rt != held():
		return
	if state == WeaponRuntime.State.LOWERING:
		viewmodel.play(&"holster")
	elif state == WeaponRuntime.State.RAISING:
		viewmodel.play(&"draw")


# --- remote puppets ---------------------------------------------------------------------------


func set_remote_weapon(def: WeaponDefinition) -> void:
	remote_def = def
	if def != null:
		WeaponAudio.ensure(def)
	if _tp_weapon == null:
		return
	var mesh: MeshInstance3D = _tp_weapon.get_child(0) as MeshInstance3D
	if _tp_model != null:
		_tp_model.queue_free()
		_tp_model = null
	if def != null and def.world_scene != null:
		# Authored world model: hide the greybox block and fire from the model's Muzzle marker.
		_tp_model = def.world_scene.instantiate() as Node3D
		_tp_model.scale = Vector3.ONE * 1.15
		_tp_weapon.add_child(_tp_model)
		mesh.visible = false
		WeaponCamo.apply(_tp_model, def)
		var m: Node3D = _tp_model.get_node_or_null(^"Muzzle") as Node3D
		_tp_muzzle.position = m.position * _tp_model.scale if m != null else Vector3(0, 0.02, -0.22)
		return
	mesh.visible = true
	mesh.material_overlay = WeaponCamo.material(def.camo) if def != null else null
	var length: float = 0.22
	match def.viewmodel_style if def != null else &"pistol":
		&"smg":
			length = 0.55
		&"shotgun":
			length = 0.85
		&"rifle_scoped", &"rifle":
			length = 1.0
		&"lmg":
			length = 1.15
		&"launcher":
			length = 0.95
		&"crossbow":
			length = 0.75
	(mesh.mesh as BoxMesh).size = Vector3(0.06, 0.09, length)
	mesh.position = Vector3(0, 0, -length * 0.5)
	_tp_muzzle.position = Vector3(0, 0.02, -length)


# Cosmetic replay of a relayed shot on an observer: same seed -> same spread -> same impacts.
func replay_remote_shot(
	def: WeaponDefinition, seed_value: int, origin: Vector3, forward: Vector3, spread: float
) -> void:
	if def == null:
		return
	remote_replays += 1
	if remote_def != def:
		set_remote_weapon(def)
	var pos: Vector3 = player.global_position + Vector3.UP * 1.4
	Audio.play_event_3d(WeaponAudio.event(def, "body"), pos)
	Audio.play_event_3d(WeaponAudio.tail_event(def, player.get_world_3d().direct_space_state, pos), pos)
	Audio.play_event_3d(WeaponAudio.event(def, "mech"), pos)
	if def.is_upgraded():
		Audio.play_event_3d(WeaponAudio.event(def, "zap"), pos)
	var fx: WeaponFx = WeaponFx.of(self)
	var muzzle: Vector3 = _tp_muzzle.global_position if _tp_muzzle != null else pos
	if _tp_muzzle != null:
		fx.muzzle_flash(_tp_muzzle.global_transform, def.muzzle_flash_scale * 1.3, false)
	if def.is_melee():
		return
	var ctx: WeaponBehavior.ShotContext = WeaponBehavior.ShotContext.new()
	ctx.space = player.get_world_3d().direct_space_state
	ctx.def = def
	ctx.origin = origin
	ctx.forward = forward
	ctx.spread_deg = spread
	ctx.seed = seed_value
	var result: Ballistics.ShotResult = behavior_for(def).fire(ctx)
	_present_impacts(def, result, muzzle, 0)


# Third-person weapon node (SurvivorModel attaches it to the right hand).
func tp_weapon_node() -> Node3D:
	return _tp_weapon


func _build_tp_weapon() -> void:
	_tp_weapon = Node3D.new()
	_tp_weapon.name = "TPWeapon"
	_tp_weapon.position = Vector3(0.22, 1.32, -0.25)
	player.add_child(_tp_weapon)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.06, 0.09, 0.22)
	mi.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.22)
	mi.material_override = mat
	_tp_weapon.add_child(mi)
	_tp_muzzle = Node3D.new()
	_tp_muzzle.name = "Muzzle"
	_tp_weapon.add_child(_tp_muzzle)
	set_remote_weapon(WeaponCatalog.get_def(DEFAULT_LOADOUT[0]))
