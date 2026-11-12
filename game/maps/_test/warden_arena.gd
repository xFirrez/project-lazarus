# Warden test arena (DEVELOPMENT_PLAN Step 12B scope 5): a 44 x 44 m walled yard with four pillars
# (cover to break a charge on), a coolant vent marker and player / zombie spawns, navmesh baked at
# load. `godot --path game -- --solo --map=warden_arena` then `spawn_warden 20`, `warden slam` ...;
# tests/integration/test_warden.gd and the kill-time measurement use it headless.
# Markers: Mark_Warden (spawn), Mark_Team (players), Mark_Coolant, PlayerSpawn0..3, Spawn_* .
# Authority: static map.
extends "res://maps/_test/nav_torture.gd"


func _ready() -> void:
	_environment()
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	nav.navigation_mesh = make_navmesh()
	add_child(nav)
	box("Ground", Vector3(0, -0.5, 0), Vector3(46, 1, 46), &"concrete")
	for s: Array in [
		["WallN", Vector3(0, 2.5, 22.2), Vector3(44.8, 5, 0.4)],
		["WallS", Vector3(0, 2.5, -22.2), Vector3(44.8, 5, 0.4)],
		["WallE", Vector3(22.2, 2.5, 0), Vector3(0.4, 5, 44.8)],
		["WallW", Vector3(-22.2, 2.5, 0), Vector3(0.4, 5, 44.8)],
	]:
		box(s[0], s[1], s[2], &"metal")
	for p: Vector3 in [Vector3(-9, 2, -9), Vector3(9, 2, -9), Vector3(-9, 2, 9), Vector3(9, 2, 9)]:
		box("Pillar_%d_%d" % [int(p.x), int(p.z)], p, Vector3(2, 4, 2), &"concrete")
	marker("Mark_Warden", Vector3(0, 0, -14))
	marker("Mark_Team", Vector3(0, 0, 10))
	marker("Mark_Coolant", Vector3(0, 0, 0))
	for i: int in 4:
		var m: Marker3D = marker("PlayerSpawn%d" % i, Vector3(-1.5 + 1.0 * i, 0.05, 12.0))
		m.add_to_group(&"player_spawn")
	for i: int in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		spawner("Spawn_%d" % i, Vector3(cos(a) * 18.0, 0, sin(a) * 18.0), ZombieSpawner.Kind.RISER, &"")
	_shot("ShotA_Arena", Vector3(0, 6, 18), Vector3(0, 1.5, -8))
	nav.bake_navigation_mesh(false)
	Log.info(&"map", "warden_arena navmesh: %d polygons" % nav.navigation_mesh.get_polygon_count())
