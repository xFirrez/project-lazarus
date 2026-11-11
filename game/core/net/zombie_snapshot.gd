# ZombieSnapshot — compact binary encoding of zombie state for the 20 Hz snapshot stream
# (ARCHITECTURE §5.2). Per zombie 15 bytes:
#   u16 net id | 3 x s16 position (2 cm, +-655 m) | u16 yaw | u8 tier(3 bit) + action(5 bit)
#   | u16 action start tick (host clock, 60 Hz, wraps) | u8 health bucket | u8 flags
# Packet: f64 host time stamp | u8 count | entries.
# Authority: pure functions (host encodes, clients decode).
class_name ZombieSnapshot
extends RefCounted

const POS_SCALE: float = 50.0  # 1 / 0.02 m
const TICK_RATE: float = 60.0
const ENTRY_BYTES: int = 15
const HEADER_BYTES: int = 9
const MAX_PER_PACKET: int = 80


class Entry:
	extends RefCounted
	var id: int = 0
	var position: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var tier: int = 0
	var action: int = 0
	var action_time: float = 0.0
	var health_bucket: int = 255
	var flags: int = 0


static func time_to_tick(t: float) -> int:
	return int(roundf(t * TICK_RATE)) & 0xFFFF


# Latest host time <= stamp whose tick matches (actions start before the snapshot that carries them).
static func tick_to_time(tick: int, stamp: float) -> float:
	var stamp_tick: int = time_to_tick(stamp)
	var back: int = (stamp_tick - tick) & 0xFFFF
	return stamp - back / TICK_RATE


static func put_entry(buf: StreamPeerBuffer, e: Entry) -> void:
	buf.put_u16(e.id & 0xFFFF)
	buf.put_16(clampi(int(roundf(e.position.x * POS_SCALE)), -32768, 32767))
	buf.put_16(clampi(int(roundf(e.position.y * POS_SCALE)), -32768, 32767))
	buf.put_16(clampi(int(roundf(e.position.z * POS_SCALE)), -32768, 32767))
	buf.put_u16(int(roundf(fposmod(e.yaw, TAU) / TAU * 65536.0)) & 0xFFFF)
	buf.put_u8(((e.tier & 0x7) << 5) | (e.action & 0x1F))
	buf.put_u16(time_to_tick(e.action_time))
	buf.put_u8(clampi(e.health_bucket, 0, 255))
	buf.put_u8(e.flags & 0xFF)


static func get_entry(buf: StreamPeerBuffer, stamp: float) -> Entry:
	var e: Entry = Entry.new()
	e.id = buf.get_u16()
	var x: int = buf.get_16()
	var y: int = buf.get_16()
	var z: int = buf.get_16()
	e.position = Vector3(x, y, z) / POS_SCALE
	e.yaw = buf.get_u16() / 65536.0 * TAU
	if e.yaw > PI:
		e.yaw -= TAU
	var ta: int = buf.get_u8()
	e.tier = ta >> 5
	e.action = ta & 0x1F
	e.action_time = tick_to_time(buf.get_u16(), stamp)
	e.health_bucket = buf.get_u8()
	e.flags = buf.get_u8()
	return e


static func encode(stamp: float, entries: Array[Entry]) -> PackedByteArray:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.put_double(stamp)
	buf.put_u8(entries.size())
	for e: Entry in entries:
		put_entry(buf, e)
	return buf.data_array


static func decode(bytes: PackedByteArray) -> Array:
	var buf: StreamPeerBuffer = StreamPeerBuffer.new()
	buf.data_array = bytes
	if bytes.size() < HEADER_BYTES:
		return [0.0, []]
	var stamp: float = buf.get_double()
	var n: int = buf.get_u8()
	var out: Array[Entry] = []
	if bytes.size() < HEADER_BYTES + n * ENTRY_BYTES:
		return [stamp, out]
	for i: int in n:
		out.append(get_entry(buf, stamp))
	return [stamp, out]
