# Host movement validation (AC-2.5 speed-hack part): legit motion is never corrected,
# a 3x speed hack is corrected within a fraction of a second, teleports are corrected at once,
# stale states after a correction are ignored, host-authorized teleports are accepted.
extends GutTest

const RATE: float = 1.0 / 30.0

var v: MovementValidator = null
var t: PlayerTuning = null


func before_each() -> void:
	t = PlayerTuning.new()
	v = MovementValidator.new(t)


func _run(speed: float, seconds: float, start_stamp: float = 0.0, seq: int = 0) -> Array:
	var results: Array = []
	var n: int = roundi(seconds / RATE)
	for i: int in n + 1:
		var stamp: float = start_stamp + i * RATE
		results.append(v.validate(stamp, Vector3(0, 0, -speed * stamp), seq))
	return results


func test_legit_sprint_and_slide_accepted() -> void:
	var r: Array = _run(t.sprint_speed, 5.0)
	assert_false(r.has(MovementValidator.Result.CORRECT))
	v = MovementValidator.new(t)
	r = _run(t.slide_start_speed + 2.0, 3.0)  # slide on a moving platform
	assert_false(r.has(MovementValidator.Result.CORRECT))
	assert_eq(v.corrections, 0)


func test_lost_packets_do_not_trigger() -> void:
	var stamp: float = 0.0
	var pos: Vector3 = Vector3.ZERO
	for i: int in 200:
		stamp += RATE * (3 if i % 7 == 0 else 1)  # bursts of loss
		pos = Vector3(0, 0, -t.sprint_speed * stamp)
		assert_ne(v.validate(stamp, pos, 0), MovementValidator.Result.CORRECT)


func test_speed_hack_3x_corrected_quickly() -> void:
	var r: Array = _run(t.sprint_speed * 3.0, 1.0)
	var first: int = r.find(MovementValidator.Result.CORRECT)
	assert_gt(first, 0, "corrected")
	assert_lt(first * RATE, 0.4, "within 0.4 s (%.2f s)" % (first * RATE))
	assert_true(v.position.z > -t.sprint_speed * 3.0 * first * RATE, "kept the last valid position")


func test_stale_after_correction_then_resume() -> void:
	_run(t.sprint_speed * 3.0, 0.5)
	assert_gt(v.corrections, 0)
	var seq: int = v.expected_seq
	assert_eq(v.validate(10.0, Vector3.ZERO, seq - 1), MovementValidator.Result.STALE, "old sequence ignored")
	assert_eq(v.validate(10.0, v.position, seq), MovementValidator.Result.ACCEPT, "acked sequence accepted")


func test_teleport_corrected_immediately() -> void:
	v.validate(0.0, Vector3.ZERO, 0)
	assert_eq(v.validate(RATE, Vector3(30, 0, 0), 0), MovementValidator.Result.CORRECT)
	assert_string_contains(v.last_reason, "teleport")


func test_falling_is_allowed() -> void:
	v.validate(0.0, Vector3(0, 10, 0), 0)
	assert_eq(v.validate(0.5, Vector3(0, 7.5, 0), 0), MovementValidator.Result.ACCEPT)


func test_fly_hack_corrected() -> void:
	var r: Array = []
	for i: int in 60:
		r.append(v.validate(i * RATE, Vector3(0, i * RATE * 25.0, 0), 0))
	assert_true(r.has(MovementValidator.Result.CORRECT), "25 m/s upward is corrected")


func test_authorized_teleport() -> void:
	v.validate(0.0, Vector3.ZERO, 0)
	var seq: int = v.authorize(Vector3(50, 0, 0), 0.1)
	assert_eq(v.validate(0.15, Vector3(50, 0, 0), seq), MovementValidator.Result.ACCEPT)
	assert_eq(v.corrections, 0, "authorized moves are not violations")


# I-031: right after a join the owner's host-clock estimate can lag the host's clock; the first
# state acknowledging a teleport is accepted at the authorized spot whatever its stamp, and the
# owner's later states then validate against the owner's own timeline.
func test_teleport_ack_with_lagging_owner_clock() -> void:
	v.validate(0.0, Vector3.ZERO, 0)
	var seq: int = v.authorize(Vector3(50, 0, 0), 10.0)  # host clock 10 s, owner thinks ~2 s
	assert_eq(v.validate(2.0, Vector3(50.05, 0, 0), seq), MovementValidator.Result.ACCEPT, "ack accepted")
	assert_eq(v.validate(2.0 + RATE, Vector3(50.1, 0, 0), seq), MovementValidator.Result.ACCEPT, "then walks on")
	assert_eq(v.corrections, 0)


func test_teleport_ack_elsewhere_is_not_free() -> void:
	v.validate(0.0, Vector3.ZERO, 0)
	var seq: int = v.authorize(Vector3(50, 0, 0), 10.0)
	assert_eq(v.validate(2.0, Vector3(80, 0, 0), seq), MovementValidator.Result.STALE, "lagging + wrong spot ignored")
	assert_eq(
		v.validate(10.2, Vector3(80, 0, 0), seq), MovementValidator.Result.CORRECT, "far from the snap: corrected"
	)
