# WeaponRuntime — per-instance weapon state machine (ARCHITECTURE §6.2): ammo, fire timing,
# reload (partial / empty with an ammo-in point, per-shell for pumps, cancel), raise / lower,
# ADS blend, sprint (blocks fire, sprint-out delay), melee interrupt, spread bloom and the
# consecutive-shot counter that indexes the recoil pattern. Pure logic stepped by `update`,
# so it is unit-testable and deterministic.
# Rules (GAME_DESIGN §4.2, decisions in the Step 3 session report):
#   * Cancelling a reload before the ammo-in point adds nothing; after it, the ammo is kept.
#   * Reload with an empty reserve does not start. Sprinting does NOT cancel a reload (it
#     continues while running). Switching weapons and melee cancel it (ammo-in rule applies).
#   * Pump reloads insert one shell per `shell_insert_time`; pulling the trigger with a shell in
#     the tube stops the reload after the shell in progress is dropped (no ammo for it).
#   * Fire timing carries the sub-frame remainder, so the average interval equals 60 / RPM; a
#     semi-auto click up to SEMI_PRESS_BUFFER early is remembered and fires when ready.
# Authority: runs on the owning peer for feel; the host mirrors ammo for validation.
class_name WeaponRuntime
extends RefCounted

signal fired(shot_index: int)
signal dry_fired
signal reload_started(empty: bool)
signal ammo_added(count: int)
signal reload_finished
signal reload_cancelled(kept_ammo: bool)
signal raise_started
signal lowered
signal melee_started
signal state_changed(state: int)

enum State { HOLSTERED, RAISING, IDLE, RELOADING, LOWERING, MELEE, SPRINT }
enum ShellPhase { START, INSERT, END }

const SEMI_PRESS_BUFFER: float = 0.1  # s before ready in which a semi-auto click is remembered

var def: WeaponDefinition = null
var mag: int = 0
var reserve: int = 0
var state: State = State.HOLSTERED
var state_time: float = 0.0
var ads: float = 0.0  # 0 = hip, 1 = fully aimed
var bloom: float = 0.0  # degrees added to the hip cone by sustained fire
var consecutive_shots: int = 0
var shots_fired: int = 0
var infinite_ammo: bool = false
var auto_reload: bool = true
var reload_empty: bool = false
var reload_ammo_added: bool = false
var shell_phase: ShellPhase = ShellPhase.START
var speed_multiplier: float = 1.0  # handling/reload speed (Quickdraw Fizz later)

var _cooldown: float = 0.0
var _trigger_was_down: bool = false
var _burst_left: int = 0
var _since_shot: float = 1000.0
var _sprint_recover: float = 0.0
var _melee_duration: float = 0.0
var _shell_stop: bool = false
var _buffered: bool = false


func _init(p_def: WeaponDefinition, full: bool = true) -> void:
	def = p_def
	if full:
		mag = def.mag_size
		reserve = def.reserve_max


func can_fire_now() -> bool:
	return state == State.IDLE and _sprint_recover <= 0.0 and _cooldown <= 0.0


func is_reloading() -> bool:
	return state == State.RELOADING


func is_ready() -> bool:
	return state == State.IDLE or state == State.RELOADING or state == State.SPRINT


func total_reload_time() -> float:
	if def.reload_per_shell:
		var shells: int = mini(def.mag_size - mag, reserve)
		return (def.reload_start_time + shells * def.shell_insert_time + def.reload_end_time) / speed_multiplier
	return def.reload_time(mag == 0) / speed_multiplier


# Current spread cone half-angle in degrees. `move_fraction` = horizontal speed / sprint speed.
func spread_deg(move_fraction: float, airborne: bool = false) -> float:
	var hip: float = def.spread_hip + def.spread_move * clampf(move_fraction, 0.0, 1.0) + bloom
	if airborne:
		hip += def.spread_move
	hip = minf(hip, def.spread_max)
	var aimed: float = def.spread_ads + bloom * 0.15
	return lerpf(hip, aimed, ads)


# --- commands ---------------------------------------------------------------------------------


func raise() -> void:
	_set_state(State.RAISING)
	_buffered = false
	_trigger_was_down = true  # a held trigger from the previous weapon must be released first
	raise_started.emit()


func holster() -> void:
	if state == State.HOLSTERED or state == State.LOWERING:
		return
	if state == State.RELOADING:
		cancel_reload()
	ads = 0.0
	_set_state(State.LOWERING)


# Instant switch-in (spawn): skips the raise animation.
func make_ready() -> void:
	_set_state(State.IDLE)


func start_reload() -> bool:
	if state != State.IDLE and state != State.SPRINT:
		return false
	if mag >= def.mag_size or reserve <= 0:
		return false
	reload_empty = mag == 0
	reload_ammo_added = false
	shell_phase = ShellPhase.START
	_shell_stop = false
	_burst_left = 0
	_set_state(State.RELOADING)
	reload_started.emit(reload_empty)
	return true


# Returns true when ammo had already been added (the ammo-in point was passed).
func cancel_reload() -> bool:
	if state != State.RELOADING:
		return false
	var kept: bool = reload_ammo_added
	_set_state(State.IDLE)
	reload_cancelled.emit(kept)
	return kept


func start_melee(duration: float) -> bool:
	if state == State.MELEE or state == State.LOWERING or state == State.HOLSTERED:
		return false
	if state == State.RELOADING:
		cancel_reload()
	_melee_duration = duration
	ads = 0.0
	_burst_left = 0
	_set_state(State.MELEE)
	melee_started.emit()
	return true


func refill() -> void:
	mag = def.mag_size
	reserve = def.reserve_max


# --- tick -------------------------------------------------------------------------------------


# Advances the state machine by dt. Returns the number of shots fired this tick.
func update(dt: float, trigger: bool, wants_ads: bool, sprinting: bool) -> int:
	state_time += dt
	_since_shot += dt
	var pressed: bool = trigger and not _trigger_was_down
	_trigger_was_down = trigger
	var shots: int = 0
	match state:
		State.HOLSTERED:
			pass
		State.RAISING:
			if state_time >= def.raise_time / speed_multiplier:
				_set_state(State.IDLE)
		State.LOWERING:
			if state_time >= def.lower_time / speed_multiplier:
				_set_state(State.HOLSTERED)
				lowered.emit()
		State.MELEE:
			if state_time >= _melee_duration:
				_set_state(State.IDLE)
		State.RELOADING:
			_update_reload(pressed)
		State.SPRINT:
			if not sprinting:
				_sprint_recover = def.sprint_out_time
				_set_state(State.IDLE)
	if sprinting and state == State.IDLE:
		_set_state(State.SPRINT)
		_burst_left = 0
	if state == State.IDLE and _sprint_recover > 0.0:
		_sprint_recover = maxf(_sprint_recover - dt, 0.0)  # weapon coming up from the sprint pose
		_cooldown = maxf(_cooldown - dt, 0.0)
	elif state == State.IDLE:
		shots = _update_fire(dt, trigger, pressed)
	else:
		_cooldown = maxf(_cooldown - dt, 0.0)
	_update_ads(dt, wants_ads)
	if _since_shot > maxf(def.fire_interval() * 1.6, 0.2):
		consecutive_shots = 0
		bloom = maxf(bloom - def.spread_recovery * dt, 0.0)
	return shots


func _update_fire(dt: float, trigger: bool, pressed: bool) -> int:
	# A weapon that was already ready and idle banks no fire time: timing restarts at the press.
	# While firing (or with a buffered press) the sub-frame remainder carries over, so the average
	# interval is exactly 60 / RPM.
	var was_idle_ready: bool = _cooldown <= 0.0 and not _buffered and _burst_left == 0
	_cooldown -= dt
	if was_idle_ready:
		_cooldown = 0.0
	var shots: int = 0
	var interval: float = def.fire_interval()
	var wants: bool = false
	match def.fire_mode:
		WeaponDefinition.FireMode.AUTO:
			wants = trigger
		WeaponDefinition.FireMode.SEMI:
			if pressed and _cooldown > 0.0 and _cooldown <= SEMI_PRESS_BUFFER:
				_buffered = true  # clicked slightly early: fire the moment the weapon is ready
			wants = (pressed or _buffered) and _cooldown <= 0.0
			if wants:
				_buffered = false
		WeaponDefinition.FireMode.BURST:
			if pressed and _burst_left == 0 and _cooldown <= 0.0:
				_burst_left = def.burst_count
			wants = _burst_left > 0
	if pressed and mag == 0 and _cooldown <= 0.0:
		if reserve > 0 and auto_reload:
			start_reload()
		else:
			dry_fired.emit()
		return 0
	while wants and _cooldown <= 0.0 and mag > 0:
		_fire_one()
		shots += 1
		_cooldown += interval
		if def.fire_mode == WeaponDefinition.FireMode.SEMI:
			wants = false
		elif def.fire_mode == WeaponDefinition.FireMode.BURST:
			_burst_left -= 1
			wants = _burst_left > 0
			if _burst_left == 0:
				_cooldown += interval * 2.0  # pause between bursts
	if mag == 0 and shots > 0 and reserve > 0 and auto_reload:
		start_reload()
	return shots


func _fire_one() -> void:
	if not infinite_ammo:
		mag -= 1
	shots_fired += 1
	_since_shot = 0.0
	bloom = minf(bloom + def.spread_per_shot, maxf(def.spread_max - def.spread_hip, 0.0))
	fired.emit(consecutive_shots)
	consecutive_shots += 1


func _update_reload(trigger_pressed: bool) -> void:
	var t: float = state_time * speed_multiplier
	if not def.reload_per_shell:
		var ammo_in: float = def.ammo_in_empty if reload_empty else def.ammo_in_partial
		if not reload_ammo_added and t >= ammo_in:
			_add_ammo(def.mag_size - mag)
			reload_ammo_added = true
		if t >= def.reload_time(reload_empty):
			_set_state(State.IDLE)
			reload_finished.emit()
		return
	if trigger_pressed and mag > 0:
		_shell_stop = true
	match shell_phase:
		ShellPhase.START:
			if t >= def.reload_start_time:
				state_time -= def.reload_start_time / speed_multiplier
				shell_phase = ShellPhase.INSERT
				if _shell_stop:
					shell_phase = ShellPhase.END
		ShellPhase.INSERT:
			if _shell_stop:
				# Stop now: the shell in hand is not inserted.
				state_time = 0.0
				shell_phase = ShellPhase.END
			elif t >= def.shell_insert_time:
				state_time -= def.shell_insert_time / speed_multiplier
				_add_ammo(1)
				reload_ammo_added = true
				if mag >= def.mag_size or reserve <= 0:
					shell_phase = ShellPhase.END
		ShellPhase.END:
			if t >= def.reload_end_time:
				_set_state(State.IDLE)
				reload_finished.emit()


func _add_ammo(wanted: int) -> void:
	var n: int = mini(wanted, reserve)
	if n <= 0:
		return
	mag += n
	reserve -= n
	ammo_added.emit(n)


func _update_ads(dt: float, wants_ads: bool) -> void:
	var allowed: bool = state == State.IDLE or state == State.RELOADING
	var target: float = 1.0 if wants_ads and allowed else 0.0
	ads = move_toward(ads, target, dt / maxf(def.ads_time / speed_multiplier, 0.01))


func _set_state(s: State) -> void:
	_buffered = false
	state = s
	state_time = 0.0
	state_changed.emit(s)
