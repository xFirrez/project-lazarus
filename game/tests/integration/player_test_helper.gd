# Shared setup for player integration tests: spawns a local PlayerCharacter (no network) into a
# scene and steps physics frames with a scripted input driver.
extends RefCounted

const PLAYER_SCENE: PackedScene = preload("res://core/player/player_character.tscn")
const COURSE_SCENE: PackedScene = preload("res://maps/_test/movement_course.tscn")
# Known-benign engine warning: Jolt's job pool briefly fills when headless --fixed-fps runs
# physics far faster than real time; Jolt waits for free jobs and continues. Never a game bug.
const BENIGN_ENGINE_WARNINGS: PackedStringArray = ["Jolt Physics job system exceeded the maximum number of jobs"]


static func spawn_player(parent: Node, pos: Vector3, yaw: float = 0.0) -> PlayerCharacter:
	var p: PlayerCharacter = PLAYER_SCENE.instantiate() as PlayerCharacter
	p.is_local = true
	p.peer_id = 1
	p.position = pos
	p.rotation.y = yaw
	parent.add_child(p)
	return p


static func flat_floor(parent: Node, size: float = 400.0) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(0, -0.5, -size * 0.4)
	var col: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(size, 1.0, size)
	col.shape = bs
	body.add_child(col)
	parent.add_child(body)
	return body


# Constant input driver; `mutate` (optional) may edit the frame each tick: func(f, frame_index).
static func const_driver(move: Vector2, sprint: bool = false, crouch: bool = false) -> Callable:
	return func(_p: PlayerCharacter, _d: float) -> PlayerInputFrame:
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.move = move
		f.sprint = sprint
		f.crouch = crouch
		return f


static func step(test: GutTest, frames: int) -> void:
	var tree: SceneTree = test.get_tree()
	for i: int in frames:
		await tree.physics_frame
	for err: Variant in test.gut.error_tracker.get_current_test_errors():
		var text: String = "%s %s" % [err.code, err.rationale]
		for benign: String in BENIGN_ENGINE_WARNINGS:
			if text.contains(benign):
				err.handled = true


static func find_marker(root: Node, marker_name: String) -> Node3D:
	return root.find_child(marker_name, true, false) as Node3D
