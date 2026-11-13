extends GutTest

const N: int = 4000


func _sim(latency: float, jitter: float, loss: float) -> NetSim:
	var sim: NetSim = NetSim.new()
	sim.rng.seed = 12345
	sim.configure(latency, jitter, loss)
	return sim


func test_parse_spec() -> void:
	var v: PackedFloat64Array = NetSim.parse_spec("100,20,0.02")
	assert_almost_eq(v[0], 100.0, 0.001)
	assert_almost_eq(v[1], 20.0, 0.001)
	assert_almost_eq(v[2], 0.02, 0.0001)
	assert_eq(NetSim.parse_spec("50")[1], 0.0)


func test_disabled_when_zero() -> void:
	assert_false(_sim(0, 0, 0).enabled)
	assert_true(_sim(1, 0, 0).enabled)


func test_loss_rate_within_10_percent() -> void:
	var sim: NetSim = _sim(0.0, 0.0, 0.2)
	var delivered: int = 0
	for i: int in N:
		if sim.push(i, 0.0, false):
			delivered += 1
	var measured: float = 1.0 - float(delivered) / N
	assert_almost_eq(measured, 0.2, 0.2 * 0.1, "loss %.4f" % measured)
	assert_eq(sim.dropped, N - delivered)


func test_reliable_never_dropped() -> void:
	var sim: NetSim = _sim(10.0, 0.0, 0.5)
	for i: int in 500:
		assert_true(sim.push(i, 0.0, true))
	assert_eq(sim.pop_ready(1.0).size(), 500)


func test_mean_delay_within_10_percent() -> void:
	var sim: NetSim = _sim(100.0, 20.0, 0.0)
	var t: float = 0.0
	var total_delay: float = 0.0
	var count: int = 0
	var min_d: float = 1e9
	var max_d: float = 0.0
	for i: int in N:
		sim.push(t, t, false)
		t += 0.001
	# Step time in 1 ms increments and measure delivery delay per packet.
	var now: float = 0.0
	while count < N and now < 10.0:
		for sent_at: Variant in sim.pop_ready(now):
			var d: float = now - float(sent_at)
			total_delay += d
			min_d = minf(min_d, d)
			max_d = maxf(max_d, d)
			count += 1
		now += 0.001
	assert_eq(count, N)
	var mean_ms: float = total_delay / count * 1000.0
	assert_almost_eq(mean_ms, 100.0, 10.0, "mean delay %.2f ms" % mean_ms)
	assert_true(min_d * 1000.0 >= 79.0, "min delay %.1f ms" % (min_d * 1000.0))
	assert_true(max_d * 1000.0 <= 122.0, "max delay %.1f ms" % (max_d * 1000.0))


func test_reliable_keeps_order_under_jitter() -> void:
	var sim: NetSim = _sim(50.0, 40.0, 0.0)
	for i: int in 300:
		sim.push(i, i * 0.001, true)
	var got: Array = sim.pop_ready(10.0)
	assert_eq(got.size(), 300)
	for i: int in got.size():
		assert_eq(int(got[i]), i)


func test_not_delivered_before_due() -> void:
	var sim: NetSim = _sim(100.0, 0.0, 0.0)
	sim.push("x", 0.0, false)
	assert_eq(sim.pop_ready(0.05).size(), 0)
	assert_eq(sim.pop_ready(0.1).size(), 1)
