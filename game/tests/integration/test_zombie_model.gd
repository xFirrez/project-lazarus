# AC-4.2: the orderly zombie is a retargeted humanoid (SkeletonProfileHumanoid bone names via the
# shared BoneMap), plays >= 5 clips from the shared animation library, and its bone-attached
# hitboxes follow the animated pose. Also checks the 3 skin variants and the triangle budget.
extends GutTest

const VARIANTS: Array[String] = ["orderly", "orderly_pallid", "orderly_frostbitten"]
const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"attack_swipe", &"hit_react_head", &"death_back", &"crawl"]


func _spawn(variant: String) -> ZombieModel:
	var target: HitTarget = HitTarget.new()
	target.max_health = 150.0
	add_child_autofree(target)
	var z: ZombieModel = (load("res://content/enemies/zombie/zombie_%s.tscn" % variant) as PackedScene).instantiate()
	target.add_child(z)
	return z


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func test_retargeted_skeleton_and_library() -> void:
	var z: ZombieModel = _spawn("orderly")
	await _frames(2)
	assert_not_null(z.skeleton, "skeleton found (unique %GeneralSkeleton from the BoneMap import)")
	assert_eq(z.skeleton.name, &"GeneralSkeleton")
	var profile: SkeletonProfileHumanoid = SkeletonProfileHumanoid.new()
	for i: int in z.skeleton.get_bone_count():
		assert_true(
			profile.find_bone(z.skeleton.get_bone_name(i)) >= 0,
			"%s is a humanoid profile bone" % z.skeleton.get_bone_name(i)
		)
	assert_eq(z.skeleton.get_bone_count(), 22)
	var clips: PackedStringArray = z.clips()
	assert_true(clips.size() >= 5, "library has >= 5 clips (%d)" % clips.size())
	for c: StringName in CLIPS:
		assert_true(z.has_clip(c), "clip %s" % c)
	for c: StringName in [&"idle", &"walk", &"run", &"crawl"] as Array[StringName]:
		assert_eq(z.anim.get_animation(StringName("zombie/%s" % c)).loop_mode, Animation.LOOP_LINEAR, "%s loops" % c)
	var tris: int = z.triangle_count()
	assert_between(tris, 5000, 12000, "zombie LOD0 triangles within budget (%d)" % tris)


func test_hitboxes_follow_bones_during_animation() -> void:
	var z: ZombieModel = _spawn("orderly")
	await _frames(2)
	assert_eq(z.hurtboxes.size(), 14, "14 hitboxes")
	assert_eq(z.target.hurtboxes.size(), 14, "registered with the HitTarget")
	var head: Hurtbox = z.hurtbox_for_bone(&"Head")
	assert_eq(head.zone, WeaponDefinition.Hitzone.HEAD)
	assert_eq(head.collision_layer, Hurtbox.LAYER)
	var bone: int = z.skeleton.find_bone(&"Head")
	var played: int = 0
	for clip: StringName in CLIPS:
		z.play(clip, 0.0)
		var a: Animation = z.anim.get_animation(StringName("zombie/%s" % clip))
		var positions: Array[Vector3] = []
		for t: float in [0.0, a.length * 0.35, a.length * 0.7]:
			z.anim.seek(t, true)
			await _frames(2)
			var expected: Vector3 = z.skeleton.global_transform * z.skeleton.get_bone_global_pose(bone) * head.position
			assert_true(
				head.global_position.distance_to(expected) < 0.002,
				(
					"%s t=%.2f head hitbox on the head bone (%.4f m)"
					% [clip, t, head.global_position.distance_to(expected)]
				)
			)
			positions.append(head.global_position)
		var moved: float = maxf(positions[0].distance_to(positions[1]), positions[0].distance_to(positions[2]))
		if clip != &"idle":
			assert_true(moved > 0.02, "%s moves the head hitbox (%.3f m)" % [clip, moved])
		played += 1
	assert_true(played >= 5)
	z.play(&"death_back", 0.0)
	z.anim.seek(1.4, true)
	await _frames(2)
	assert_true(
		head.global_position.y < 0.7, "death ends with the head near the ground (%.2f)" % head.global_position.y
	)
	z.play(&"crawl", 0.0)
	z.anim.seek(0.3, true)
	await _frames(2)
	assert_true(head.global_position.y < 1.0, "crawler head is low (%.2f)" % head.global_position.y)


func test_skin_variants() -> void:
	for v: String in VARIANTS:
		var z: ZombieModel = _spawn(v)
		await _frames(1)
		var mi: MeshInstance3D = z.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var found: bool = false
		for s: int in mi.mesh.get_surface_count():
			var o: Material = mi.get_surface_override_material(s)
			if o != null:
				found = true
				assert_eq(o, z.skin_material, "%s skin override" % v)
		assert_true(found, "%s has a skin override" % v)
