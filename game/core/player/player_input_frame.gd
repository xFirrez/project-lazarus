# PlayerInputFrame — one frame of resolved player intent, consumed by MotorComponent in
# _physics_process. Produced by PlayerInputSource (human) or a bot driver (tests), which makes
# bots and replays trivial (ARCHITECTURE §6.1). Hold/toggle settings are already resolved here.
# Authority: local (owning peer only).
class_name PlayerInputFrame
extends RefCounted

var move: Vector2 = Vector2.ZERO  # x = right, y = back (Input.get_vector convention); length <= 1
var look_delta: Vector2 = Vector2.ZERO  # radians this frame: x = yaw (+left), y = pitch (+up)
var jump_pressed: bool = false
var jump_held: bool = false
var sprint: bool = false  # wants to sprint (hold or toggle resolved)
var crouch: bool = false  # wants to be crouched (hold or toggle resolved)
var crouch_pressed: bool = false  # edge, starts a slide while sprinting
var fire: bool = false
var aim: bool = false


func duplicate_frame() -> PlayerInputFrame:
	var f: PlayerInputFrame = PlayerInputFrame.new()
	f.move = move
	f.look_delta = look_delta
	f.jump_pressed = jump_pressed
	f.jump_held = jump_held
	f.sprint = sprint
	f.crouch = crouch
	f.crouch_pressed = crouch_pressed
	f.fire = fire
	f.aim = aim
	return f
