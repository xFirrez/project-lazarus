# FootstepComponent — plays surface-dependent footsteps from distance travelled on the ground:
# walk / sprint stride lengths, land on touchdown. Surface comes from a short ray down to the
# collider's tag (SurfaceTags). The local player hears 2D steps; remote players' steps are
# spatialized at their puppet position (driven by replicated grounded/sprint flags).
# Authority: local presentation on every peer.
class_name FootstepComponent
extends Node

const WALK_STRIDE: float = 1.7
const SPRINT_STRIDE: float = 2.3
const CROUCH_STRIDE: float = 1.2

var body: Node3D = null
var spatial: bool = false
var steps_played: int = 0
var last_surface: StringName = SurfaceTags.DEFAULT

var _distance: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _has_last: bool = false


func setup(p_body: Node3D, p_spatial: bool) -> void:
	body = p_body
	spatial = p_spatial
	FootstepLibrary.ensure_registered()


# grounded/sprinting/crouched describe the current frame; returns true if a step played.
func update(grounded: bool, sprinting: bool, crouched: bool) -> bool:
	var pos: Vector3 = body.global_position
	if not _has_last:
		_last_pos = pos
		_has_last = true
		return false
	var moved: Vector3 = pos - _last_pos
	_last_pos = pos
	moved.y = 0.0
	if not grounded or moved.length() > 3.0:  # airborne or teleported
		return false
	_distance += moved.length()
	var stride: float = SPRINT_STRIDE if sprinting else (CROUCH_STRIDE if crouched else WALK_STRIDE)
	if _distance >= stride:
		_distance = 0.0
		play(&"sprint" if sprinting else &"walk")
		return true
	return false


# 0..1 progress towards the next footstep (viewmodel bob is synced to it); `steps_played`
# parity gives the foot side.
func stride_phase(sprinting: bool, crouched: bool) -> float:
	var stride: float = SPRINT_STRIDE if sprinting else (CROUCH_STRIDE if crouched else WALK_STRIDE)
	return clampf(_distance / stride, 0.0, 1.0)


func play(kind: StringName) -> void:
	last_surface = _surface_below()
	steps_played += 1
	var ev: StringName = FootstepLibrary.event_name(last_surface, String(kind))
	if spatial:
		Audio.play_event_3d(ev, body.global_position)
	else:
		Audio.play_event(ev)


func _surface_below() -> StringName:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var from: Vector3 = body.global_position + Vector3.UP * 0.2
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.6, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return SurfaceTags.DEFAULT
	return SurfaceTags.of(hit["collider"])
