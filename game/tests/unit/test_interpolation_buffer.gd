extends GutTest


func test_interpolates_between_samples() -> void:
	var b: InterpolationBuffer = InterpolationBuffer.new()
	b.push(1.0, Vector3(0, 0, 0), 0.0, 0.0)
	b.push(1.1, Vector3(1, 0, 0), 0.0, 0.1)
	assert_almost_eq(b.sample_position(1.05).x, 0.5, 0.0001)
	assert_almost_eq(b.sample_position(0.5).x, 0.0, 0.0001)


func test_limited_extrapolation() -> void:
	var b: InterpolationBuffer = InterpolationBuffer.new()
	b.push(0.0, Vector3(0, 0, 0), 0.0, 0.0)
	b.push(0.1, Vector3(1, 0, 0), 0.0, 0.1)
	assert_almost_eq(b.sample_position(0.15).x, 1.5, 0.0001)
	assert_almost_eq(b.sample_position(5.0).x, 1.0 + 10.0 * InterpolationBuffer.MAX_EXTRAPOLATION, 0.0001)


func test_stale_samples_ignored() -> void:
	var b: InterpolationBuffer = InterpolationBuffer.new()
	b.push(1.0, Vector3(1, 0, 0), 0.0, 0.0)
	b.push(0.5, Vector3(9, 0, 0), 0.0, 0.01)
	assert_almost_eq(b.sample_position(1.0).x, 1.0, 0.0001)


func test_playback_tracks_arrival_minus_delay() -> void:
	var b: InterpolationBuffer = InterpolationBuffer.new()
	# Remote clock runs 100 s ahead of local; constant 80 ms transit.
	for i: int in 20:
		var stamp: float = 100.0 + i * 0.05
		b.push(stamp, Vector3(i, 0, 0), 0.0, stamp - 100.0 + 0.08)
	var local_now: float = 19 * 0.05 + 0.08
	var t: float = b.playback_time(local_now)
	assert_almost_eq(t, 100.0 + 19 * 0.05 - b.delay, 0.001)
	assert_almost_eq(b.delay, b.base_delay, 0.01)


func test_yaw_wraps() -> void:
	var b: InterpolationBuffer = InterpolationBuffer.new()
	b.push(0.0, Vector3.ZERO, PI - 0.1, 0.0)
	b.push(1.0, Vector3.ZERO, -PI + 0.1, 1.0)
	assert_almost_eq(absf(b.sample_yaw(0.5)), PI, 0.001)
