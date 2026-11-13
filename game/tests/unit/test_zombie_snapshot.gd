# ZombieSnapshot encoding: round trip within quantization, 15 bytes per zombie, action tick
# reconstruction across the 16-bit wrap, and the 32-zombie bandwidth budget at 20 Hz.
extends GutTest


func _entry(id: int, pos: Vector3, yaw: float, action_time: float) -> ZombieSnapshot.Entry:
	var e: ZombieSnapshot.Entry = ZombieSnapshot.Entry.new()
	e.id = id
	e.position = pos
	e.yaw = yaw
	e.tier = ZombieArchetype.Tier.SPRINT
	e.action = ZombieActor.Action.ATTACK
	e.action_time = action_time
	e.health_bucket = 77
	e.flags = ZombieActor.Flag.CRAWLER | ZombieActor.Flag.AGGRO
	return e


func test_round_trip() -> void:
	var stamp: float = 1234.5
	var src: Array[ZombieSnapshot.Entry] = [
		_entry(1, Vector3(12.345, 4.21, -300.5), 2.5, stamp - 0.3),
		_entry(65535, Vector3(-600.0, -10.0, 0.01), -3.0, stamp),
	]
	var bytes: PackedByteArray = ZombieSnapshot.encode(stamp, src)
	assert_eq(bytes.size(), ZombieSnapshot.HEADER_BYTES + 2 * ZombieSnapshot.ENTRY_BYTES)
	var d: Array = ZombieSnapshot.decode(bytes)
	assert_almost_eq(float(d[0]), stamp, 0.0001)
	var out: Array = d[1]
	assert_eq(out.size(), 2)
	for i: int in 2:
		var a: ZombieSnapshot.Entry = src[i]
		var b: ZombieSnapshot.Entry = out[i]
		assert_eq(b.id, a.id)
		assert_true(
			b.position.distance_to(a.position) <= 0.02, "position within 2 cm (%s vs %s)" % [b.position, a.position]
		)
		assert_almost_eq(angle_difference(a.yaw, b.yaw), 0.0, 0.001)
		assert_eq(b.tier, a.tier)
		assert_eq(b.action, a.action)
		assert_almost_eq(b.action_time, a.action_time, 1.0 / 60.0)
		assert_eq(b.health_bucket, 77)
		assert_eq(b.flags, a.flags)


func test_action_tick_wraps() -> void:
	var start: float = 65535.0 / 60.0 - 0.05  # just before the 16-bit tick wrap
	var stamp: float = start + 0.2
	var t: float = ZombieSnapshot.tick_to_time(ZombieSnapshot.time_to_tick(start), stamp)
	assert_almost_eq(t, start, 1.0 / 60.0)


func test_truncated_packet_is_ignored() -> void:
	var bytes: PackedByteArray = ZombieSnapshot.encode(
		1.0, [_entry(3, Vector3.ONE, 0.0, 1.0)] as Array[ZombieSnapshot.Entry]
	)
	var d: Array = ZombieSnapshot.decode(bytes.slice(0, bytes.size() - 4))
	assert_eq((d[1] as Array).size(), 0)


func test_32_zombie_budget() -> void:
	var list: Array[ZombieSnapshot.Entry] = []
	for i: int in 32:
		list.append(_entry(i + 1, Vector3(i, 0, -i), 0.0, 0.0))
	var bytes: int = ZombieSnapshot.encode(10.0, list).size() + 1 + 28  # stream id + UDP/IP-ish overhead
	var kbps: float = bytes * 20.0 / 1024.0
	assert_lt(kbps, 15.0, "32 zombies at 20 Hz = %.1f KB/s" % kbps)
