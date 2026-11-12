# MovementValidator — host-side sanity check of one client's owner-authoritative movement
# (ARCHITECTURE §5.1). A distance budget: horizontal travel may not exceed
# validation_max_horizontal_speed × elapsed sender time plus `validation_slack` metres (credit
# never goes below zero, so standing still does not bank allowance); upward travel likewise.
# A single jump larger than the teleport distance (+ free-fall allowance) is corrected at once.
# On a violation the host keeps the last valid position, bumps the correction sequence and tells
# the owner to snap back; states stamped with an older sequence are then ignored as stale.
# After a host teleport / correction (`authorize`, `_correct`) the first state that carries the new
# sequence AND stands within ACK_RADIUS of the authorized position is accepted whatever its stamp:
# the owner's host-clock estimate can lag the host's own clock (clock sync settling right after a
# join), and stamp-ordering those packets against the host's time froze the player for seconds
# (I-031, Step 13).
# Authority: host only. Pure logic (unit-tested in tests/unit/test_movement_validator.gd).
class_name MovementValidator
extends RefCounted

enum Result { ACCEPT, STALE, CORRECT }

const MAX_FALL_SPEED: float = 60.0
const MAX_GAP: float = 1.0
const ACK_RADIUS: float = 2.0

var tuning: PlayerTuning = null
var kill_y: float = -30.0
var position: Vector3 = Vector3.ZERO
var stamp: float = 0.0
var has_state: bool = false
var expected_seq: int = 0
var corrections: int = 0
var last_reason: String = ""

var _excess_h: float = 0.0
var _excess_up: float = 0.0
var _await_ack: bool = false


func _init(p_tuning: PlayerTuning) -> void:
	tuning = p_tuning


# `carry` = displacement of a traversal machine the player rode over this interval (host-computed
# from the deterministic machine motion), which doesn't count against the budget.
func validate(p_stamp: float, pos: Vector3, seq: int, carry: Vector3 = Vector3.ZERO) -> Result:
	if seq != expected_seq:
		return Result.STALE
	var ack: int = _check_ack(p_stamp, pos) if _await_ack or not has_state else -1
	if ack >= 0:
		return ack as Result
	var dt: float = p_stamp - stamp
	if dt <= 0.0:
		return Result.STALE
	dt = minf(dt, MAX_GAP)
	var d: Vector3 = pos - position - carry
	if pos.y < kill_y:
		return _correct("fell out of the world (y=%.1f)" % pos.y)
	if d.length() > tuning.validation_teleport_distance + MAX_FALL_SPEED * dt:
		return _correct("teleport %.2f m in %.3f s" % [d.length(), dt])
	var horiz: float = Vector2(d.x, d.z).length()
	_excess_h = maxf(_excess_h + horiz - tuning.validation_max_horizontal_speed * dt, 0.0)
	_excess_up = maxf(_excess_up + maxf(d.y, 0.0) - tuning.validation_max_vertical_up_speed * dt, 0.0)
	if _excess_h > tuning.validation_slack:
		return _correct("speed %.1f m/s over budget" % (horiz / dt))
	if _excess_up > tuning.validation_slack:
		return _correct("vertical speed %.1f m/s over budget" % (d.y / dt))
	_accept(p_stamp, pos)
	return Result.ACCEPT


# Host-initiated move (respawn, debug teleport): the owner must adopt it via a correction.
func authorize(pos: Vector3, p_stamp: float) -> int:
	expected_seq = (expected_seq + 1) % 65536
	_excess_h = 0.0
	_excess_up = 0.0
	position = pos
	stamp = p_stamp
	has_state = true
	_await_ack = true
	return expected_seq


# The first state ever, or the first acknowledging a snap: (re-)base the owner's clock if it stands
# where we put it. Returns a Result, or -1 to validate normally.
func _check_ack(p_stamp: float, pos: Vector3) -> int:
	if not has_state or pos.distance_to(position) <= ACK_RADIUS:
		_await_ack = false
		_accept(p_stamp, pos)
		return Result.ACCEPT
	if p_stamp <= stamp:
		return Result.STALE
	return -1


func _accept(p_stamp: float, pos: Vector3) -> void:
	position = pos
	stamp = p_stamp
	has_state = true


func _correct(reason: String) -> Result:
	last_reason = reason
	corrections += 1
	expected_seq = (expected_seq + 1) % 65536
	_excess_h = 0.0
	_excess_up = 0.0
	_await_ack = true
	return Result.CORRECT
