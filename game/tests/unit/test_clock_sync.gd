extends GutTest


func test_offset_estimate_symmetric_latency() -> void:
	var c: ClockSync = ClockSync.new()
	var true_offset: float = 42.5
	for i: int in 10:
		var send: float = i * 0.5
		var host_t: float = send + 0.05 + true_offset
		c.add_sample(send, host_t, send + 0.1)
	assert_true(c.synced)
	assert_almost_eq(c.offset, true_offset, 0.001)
	assert_almost_eq(c.rtt, 0.1, 0.001)
	assert_almost_eq(c.host_time(10.0), 10.0 + true_offset, 0.001)


func test_prefers_low_rtt_sample() -> void:
	var c: ClockSync = ClockSync.new()
	c.add_sample(0.0, 10.05, 0.1)  # good sample, offset 10
	c.add_sample(1.0, 11.4, 1.5)  # queued sample with skew
	assert_almost_eq(c.offset, 10.0, 0.001)
