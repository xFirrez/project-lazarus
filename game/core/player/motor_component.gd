# MotorComponent — first-person locomotion for a PlayerCharacter (GAME_DESIGN §3.1):
# ground acceleration/friction, air control, sprint with stamina, crouch (capsule resize with a
# ceiling check), slide, jump (coyote time + buffer), mantle, step-up, slopes and moving platforms
# (CharacterBody3D platform carry). Consumes one PlayerInputFrame per physics tick.
# Authority: runs only on the owning peer (owner-authoritative movement, ARCHITECTURE §5.1).
class_name MotorComponent
extends Node

signal jumped
signal landed(impact_speed: float, fall_height: float)
signal stepped(height: float)
signal slide_started
signal slide_ended
signal mantle_started(height: float)
signal stance_changed(stance: int)
signal sprint_changed(sprinting: bool)

enum Stance { STAND, CROUCH, SLIDE, MANTLE }

const WORLD_MASK: int = 1

var tuning: PlayerTuning = null
var body: CharacterBody3D = null
var shape: CollisionShape3D = null
var capsule: CapsuleShape3D = null

var stance: Stance = Stance.STAND
var sprinting: bool = false
var stamina: float = 4.0  # seconds of sprint remaining
var speed_multiplier: float = 1.0  # debug only (`speed_hack`), used by the speed-hack net test
var noclip: bool = false
var grounded: bool = true
var current_height: float = 1.8
var last_floor_y: float = 0.0
var wish_dir: Vector3 = Vector3.ZERO
var weapon_speed_multiplier: float = 1.0  # held weapon's move speed (WeaponDefinition)

var _lunge_velocity: Vector3 = Vector3.ZERO
var _lunge_time: float = 0.0

var _recharge_wait: float = 0.0
var _need_sprint_release: bool = false
var _slide_time: float = 0.0
var _slide_cooldown: float = 0.0
var _slide_dir: Vector3 = Vector3.ZERO
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _air_peak_y: float = 0.0
var _air_max_hspeed: float = 0.0
var _prev_vy: float = 0.0
var _mantle_t: float = 0.0
var _mantle_from: Vector3 = Vector3.ZERO
var _mantle_top: Vector3 = Vector3.ZERO
var _mantle_to: Vector3 = Vector3.ZERO
var _mantle_end_stance: Stance = Stance.STAND
var _jumped_this_air: bool = false


func setup(p_body: CharacterBody3D, p_shape: CollisionShape3D, p_tuning: PlayerTuning) -> void:
	body = p_body
	shape = p_shape
	tuning = p_tuning
	capsule = shape.shape as CapsuleShape3D
	stamina = tuning.sprint_duration
	body.floor_max_angle = deg_to_rad(tuning.floor_max_angle_deg)
	body.floor_snap_length = tuning.step_height + 0.05
	body.floor_constant_speed = true
	body.floor_block_on_wall = true
	body.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	body.safe_margin = 0.01
	_set_height(tuning.stand_height)
	last_floor_y = body.global_position.y


func horizontal_speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func is_crouched() -> bool:
	return stance == Stance.CROUCH or stance == Stance.SLIDE


func physics_step(f: PlayerInputFrame, delta: float) -> void:
	if noclip:
		_noclip_step(f, delta)
		return
	_slide_cooldown = maxf(_slide_cooldown - delta, 0.0)
	_jump_buffer = tuning.jump_buffer if f.jump_pressed else maxf(_jump_buffer - delta, 0.0)
	if stance == Stance.MANTLE:
		_mantle_step(delta)
		return
	var on_floor: bool = body.is_on_floor()
	_coyote = tuning.coyote_time if on_floor else maxf(_coyote - delta, 0.0)
	var basis: Basis = Basis(Vector3.UP, body.global_rotation.y)
	wish_dir = basis * Vector3(f.move.x, 0.0, f.move.y)
	wish_dir.y = 0.0
	if wish_dir.length() > 1.0:
		wish_dir = wish_dir.normalized()
	_update_sprint(f, delta, on_floor)
	_update_stance(f, on_floor)
	var hvel: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	if stance == Stance.SLIDE:
		hvel = _slide_velocity(f, delta)
	elif on_floor:
		hvel = _ground_velocity(hvel, delta)
	else:
		hvel = _air_velocity(hvel, delta)
	if _lunge_time > 0.0:
		_lunge_time -= delta
		hvel = _lunge_velocity
	body.velocity.x = hvel.x
	body.velocity.z = hvel.z
	if on_floor or _coyote > 0.0:
		if _jump_buffer > 0.0 and _try_jump():
			on_floor = false
	if not on_floor:
		body.velocity.y -= tuning.gravity * delta
	if _wants_mantle(f, on_floor) and _try_mantle():
		return
	_prev_vy = body.velocity.y
	var stepped_up: bool = on_floor and _try_step_up(delta)
	if stepped_up:
		var saved: Vector3 = body.velocity
		body.velocity = Vector3(0.0, minf(body.velocity.y, 0.0), 0.0)
		body.move_and_slide()
		body.velocity = Vector3(saved.x, body.velocity.y, saved.z)
	else:
		body.move_and_slide()
	_post_move(on_floor)


# Melee lunge: overrides horizontal velocity for `duration` seconds (knife lunge, GAME_DESIGN §3.4).
func lunge(velocity: Vector3, duration: float) -> void:
	_lunge_velocity = Vector3(velocity.x, 0.0, velocity.z)
	_lunge_time = duration


func teleport(pos: Vector3, keep_velocity: bool = false) -> void:
	body.global_position = pos
	if not keep_velocity:
		body.velocity = Vector3.ZERO
	if stance == Stance.MANTLE or stance == Stance.SLIDE:
		_set_stance(Stance.STAND)
	if stance == Stance.STAND and not can_stand():
		_set_stance(Stance.CROUCH)  # teleported under low geometry
	last_floor_y = pos.y
	_air_peak_y = pos.y
	body.reset_physics_interpolation()


func can_stand() -> bool:
	return _fits(body.global_position, tuning.stand_height)


# --- sprint -----------------------------------------------------------------------------------


func _update_sprint(f: PlayerInputFrame, delta: float, on_floor: bool) -> void:
	if not f.sprint:
		_need_sprint_release = false
	var forward_enough: bool = f.move.y <= -tuning.sprint_min_forward
	var want: bool = (
		f.sprint and forward_enough and not f.aim and not f.fire and stance == Stance.STAND and not _need_sprint_release
	)
	if want and not sprinting:
		want = stamina >= tuning.sprint_duration * tuning.sprint_restart_fraction and (on_floor or _coyote > 0.0)
	if sprinting:
		stamina -= delta
		if stamina <= 0.0:
			stamina = 0.0
			want = false
			_need_sprint_release = true
	if want != sprinting and stance != Stance.SLIDE:
		sprinting = want
		sprint_changed.emit(sprinting)
	if sprinting or stance == Stance.SLIDE:
		_recharge_wait = tuning.sprint_recharge_delay
	elif _recharge_wait > 0.0:
		_recharge_wait -= delta
	else:
		stamina = minf(stamina + tuning.sprint_duration / tuning.sprint_recharge_time * delta, tuning.sprint_duration)


# --- stance -----------------------------------------------------------------------------------


func _update_stance(f: PlayerInputFrame, on_floor: bool) -> void:
	match stance:
		Stance.STAND:
			if f.crouch_pressed and sprinting and on_floor and _slide_cooldown <= 0.0:
				_start_slide()
			elif f.crouch:
				_set_stance(Stance.CROUCH)
		Stance.CROUCH:
			if not f.crouch and can_stand():
				_set_stance(Stance.STAND)
		Stance.SLIDE:
			if _slide_time >= tuning.slide_duration or (not on_floor and _slide_time > 0.15):
				_end_slide(f.crouch)


func _set_stance(s: Stance) -> void:
	if s == stance:
		return
	stance = s
	if s == Stance.STAND or s == Stance.MANTLE:
		_set_height(tuning.stand_height)
	else:
		_set_height(tuning.crouch_height)
		if sprinting and s != Stance.SLIDE:
			sprinting = false
			sprint_changed.emit(false)
	stance_changed.emit(int(s))


func _set_height(h: float) -> void:
	current_height = h
	capsule.radius = tuning.capsule_radius
	capsule.height = h
	shape.position = Vector3(0.0, h * 0.5, 0.0)


func _start_slide() -> void:
	var hv: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	_slide_dir = hv.normalized() if hv.length() > 0.5 else -body.global_basis.z
	_slide_dir.y = 0.0
	_slide_dir = _slide_dir.normalized()
	_slide_time = 0.0
	_set_stance(Stance.SLIDE)
	sprinting = false
	sprint_changed.emit(false)
	slide_started.emit()


func _end_slide(crouch_held: bool) -> void:
	_slide_cooldown = tuning.slide_cooldown
	# Ends cleanly into a crouch when held or when low geometry blocks standing up.
	_set_stance(Stance.CROUCH if crouch_held or not can_stand() else Stance.STAND)
	slide_ended.emit()


func _slide_velocity(f: PlayerInputFrame, delta: float) -> Vector3:
	_slide_time += delta
	var t: float = clampf(_slide_time / tuning.slide_duration, 0.0, 1.0)
	if wish_dir.length() > 0.1:
		var target: Vector3 = wish_dir.normalized()
		var angle: float = _slide_dir.signed_angle_to(target, Vector3.UP)
		_slide_dir = _slide_dir.rotated(
			Vector3.UP, clampf(angle, -tuning.slide_steer * delta, tuning.slide_steer * delta)
		)
	if body.is_on_wall() and body.get_wall_normal().dot(_slide_dir) < -0.7:
		_slide_time = tuning.slide_duration  # slid into a wall
	if f.jump_pressed and can_stand():
		_end_slide(false)
	var speed: float = lerpf(tuning.slide_start_speed, tuning.slide_end_speed, t) * speed_multiplier
	return _slide_dir * speed


# --- velocity models --------------------------------------------------------------------------


func target_speed() -> float:
	var s: float = tuning.walk_speed
	if stance == Stance.CROUCH:
		s = tuning.crouch_speed
	elif sprinting:
		s = tuning.sprint_speed
	return s * speed_multiplier * weapon_speed_multiplier


func _ground_velocity(hvel: Vector3, delta: float) -> Vector3:
	var wish_len: float = wish_dir.length()
	if wish_len < 0.01:
		var speed: float = hvel.length()
		var drop: float = maxf(speed, tuning.stop_speed) * tuning.friction * delta
		var new_speed: float = maxf(speed - drop, 0.0)
		return hvel * (new_speed / speed) if speed > 0.0001 else Vector3.ZERO
	var target: Vector3 = wish_dir * target_speed()
	return hvel.move_toward(target, tuning.ground_accel * speed_multiplier * delta)


func _air_velocity(hvel: Vector3, delta: float) -> Vector3:
	if wish_dir.length() < 0.01:
		return hvel
	var cap: float = maxf(_air_max_hspeed, tuning.walk_speed * speed_multiplier)
	var next: Vector3 = hvel + wish_dir * tuning.air_accel * delta
	if next.length() > cap:
		next = next.normalized() * maxf(hvel.length(), minf(next.length(), cap))
	return next


# --- jump & landing ---------------------------------------------------------------------------


func _try_jump() -> bool:
	if stance == Stance.CROUCH or stance == Stance.SLIDE:
		if not can_stand():
			return false
		if stance == Stance.SLIDE:
			_end_slide(false)
		_set_stance(Stance.STAND)
	body.velocity.y = tuning.jump_velocity()
	_jump_buffer = 0.0
	_coyote = 0.0
	_jumped_this_air = true
	jumped.emit()
	return true


func _post_move(was_on_floor: bool) -> void:
	var on_floor: bool = body.is_on_floor()
	var feet_y: float = body.global_position.y
	if on_floor:
		if not grounded:
			var fall_h: float = maxf(_air_peak_y - feet_y, 0.0)
			landed.emit(maxf(-_prev_vy, 0.0), fall_h)
		last_floor_y = feet_y
		_air_peak_y = feet_y
		_air_max_hspeed = horizontal_speed()
		_jumped_this_air = false
	else:
		if was_on_floor or grounded:
			_air_max_hspeed = horizontal_speed()
		_air_peak_y = maxf(_air_peak_y, feet_y)
	grounded = on_floor


# --- step-up ----------------------------------------------------------------------------------


func _try_step_up(delta: float) -> bool:
	var hv: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
	if hv.length() < 0.0005:
		return false
	var xf: Transform3D = body.global_transform
	var col: KinematicCollision3D = KinematicCollision3D.new()
	var floor_cos: float = cos(body.floor_max_angle)
	# Probe a few cm ahead (a blocked body has ~0 velocity left after move_and_slide), using the
	# body's own safe margin. Only steep contacts are steps; slopes are move_and_slide's job.
	var probe: Vector3 = hv.normalized() * maxf(hv.length(), 0.06)
	if not body.test_move(xf, probe, col, body.safe_margin) or col.get_normal().y >= floor_cos:
		return false
	var final: Vector3 = _step_probe(xf, hv, floor_cos)
	var dy: float = final.y - xf.origin.y
	if final == Vector3.INF or dy < 0.03 or dy > tuning.step_height + 0.02:
		return false
	body.global_position = final
	stepped.emit(dy)
	return true


# Up / forward / down sweep. Returns the resting position on the step, or Vector3.INF.
func _step_probe(xf: Transform3D, hv: Vector3, floor_cos: float) -> Vector3:
	# Sweep a little higher than the max step so a riser exactly step_height tall clears its edge.
	var up: Vector3 = Vector3.UP * (tuning.step_height + 0.06)
	var up_col: KinematicCollision3D = KinematicCollision3D.new()
	if body.test_move(xf, up, up_col, body.safe_margin):
		up = up_col.get_travel()
	if up.y < 0.04:
		return Vector3.INF
	var xf_up: Transform3D = xf.translated(up)
	# Probe at least part of a radius forward so the capsule ends up resting on the tread.
	var fwd: Vector3 = hv.normalized() * maxf(hv.length(), tuning.capsule_radius * 0.6)
	var fwd_col: KinematicCollision3D = KinematicCollision3D.new()
	if body.test_move(xf_up, fwd, fwd_col, body.safe_margin):
		fwd = fwd_col.get_travel()
	if fwd.length() < 0.01:
		return Vector3.INF
	var xf_fwd: Transform3D = xf_up.translated(fwd)
	var down_col: KinematicCollision3D = KinematicCollision3D.new()
	if (
		not body.test_move(xf_fwd, Vector3.DOWN * (up.y + 0.04), down_col, body.safe_margin)
		or down_col.get_normal().y < floor_cos
	):
		return Vector3.INF
	return xf_fwd.origin + down_col.get_travel()


# --- mantle -----------------------------------------------------------------------------------


func _wants_mantle(f: PlayerInputFrame, on_floor: bool) -> bool:
	if f.move.y > -0.5 or stance == Stance.SLIDE:
		return false
	if on_floor:
		return f.jump_pressed or _jump_buffer > 0.0 or body.is_on_wall()
	return true  # airborne and pushing forward: grab the ledge


func _try_mantle() -> bool:
	var forward: Vector3 = -body.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var xf: Transform3D = body.global_transform
	var probe: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(xf, forward * 0.25, probe):
		return false
	if probe.get_normal().y > 0.3:
		return false
	var feet: Vector3 = body.global_position
	var ref_y: float = minf(last_floor_y, feet.y) if body.is_on_floor() else last_floor_y
	var reach: Vector3 = feet + forward * (tuning.capsule_radius + 0.3)
	var top_y: float = ref_y + tuning.mantle_max_height + 0.05
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(reach.x, top_y, reach.z), Vector3(reach.x, ref_y + tuning.mantle_min_height, reach.z), WORLD_MASK
	)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	if (hit["normal"] as Vector3).y < 0.7:
		return false
	var ledge_y: float = (hit["position"] as Vector3).y
	var height: float = ledge_y - ref_y
	if height < tuning.mantle_min_height or height > tuning.mantle_max_height + 0.02:
		return false
	var target: Vector3 = Vector3(reach.x, ledge_y + 0.03, reach.z) + forward * 0.1
	var end_stance: Stance = Stance.STAND
	if not _fits(target, tuning.stand_height):
		if not _fits(target, tuning.crouch_height):
			return false
		end_stance = Stance.CROUCH
	var top: Vector3 = Vector3(feet.x, ledge_y + 0.03, feet.z)
	var mantle_h: float = tuning.crouch_height if end_stance == Stance.CROUCH else tuning.stand_height
	# The scripted mantle moves without collision, so both legs of the path must be swept clear.
	if not _sweep_clear(feet, top, mantle_h) or not _sweep_clear(top, target, mantle_h):
		return false
	_mantle_from = feet
	_mantle_top = top
	_mantle_to = target
	_mantle_t = 0.0
	_mantle_end_stance = end_stance
	if sprinting:
		sprinting = false
		sprint_changed.emit(false)
	_set_stance(Stance.MANTLE)
	if end_stance == Stance.CROUCH:
		_set_height(tuning.crouch_height)
	body.velocity = Vector3.ZERO
	mantle_started.emit(height)
	return true


func _mantle_step(delta: float) -> void:
	_mantle_t += delta / maxf(tuning.mantle_duration, 0.05)
	var t: float = clampf(_mantle_t, 0.0, 1.0)
	var pos: Vector3
	if t < 0.6:
		pos = _mantle_from.lerp(_mantle_top, ease(t / 0.6, 0.6))
	else:
		pos = _mantle_top.lerp(_mantle_to, (t - 0.6) / 0.4)
	body.global_position = pos
	if t >= 1.0:
		var end: Stance = _mantle_end_stance
		stance = Stance.STAND
		_set_height(tuning.stand_height)
		if end == Stance.CROUCH:
			_set_stance(Stance.CROUCH)
		else:
			stance_changed.emit(int(Stance.STAND))
		body.velocity = -body.global_basis.z * tuning.walk_speed * 0.5
		body.velocity.y = 0.0
		last_floor_y = pos.y
		_air_peak_y = pos.y
		body.move_and_slide()
		grounded = body.is_on_floor()


# --- helpers ----------------------------------------------------------------------------------


# True if a capsule of the given height standing at `feet` overlaps no world geometry.
func _fits(feet: Vector3, height: float) -> bool:
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = tuning.capsule_radius - 0.02
	cap.height = height - 0.04
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0.0, height * 0.5 + 0.01, 0.0))
	q.collision_mask = WORLD_MASK
	q.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# Sweeps a slightly thinner capsule between two feet positions (thinner so touching walls do not
# count). True if nothing in the world blocks the whole motion.
func _sweep_clear(from_feet: Vector3, to_feet: Vector3, height: float) -> bool:
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = tuning.capsule_radius - 0.03
	cap.height = height - 0.06
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, from_feet + Vector3(0.0, height * 0.5 + 0.02, 0.0))
	q.motion = to_feet - from_feet
	q.collision_mask = WORLD_MASK
	q.exclude = [body.get_rid()]
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	if not space.intersect_shape(q, 1).is_empty():
		return false
	var fractions: PackedFloat32Array = space.cast_motion(q)
	return fractions.size() == 2 and fractions[0] >= 1.0


func _noclip_step(f: PlayerInputFrame, _delta: float) -> void:
	var cam_basis: Basis = body.global_basis
	var dir: Vector3 = cam_basis * Vector3(f.move.x, 0.0, f.move.y)
	if f.jump_held:
		dir.y += 1.0
	if f.crouch:
		dir.y -= 1.0
	body.velocity = dir * tuning.sprint_speed * (2.0 if f.sprint else 1.0)
	body.global_position += body.velocity * _delta
