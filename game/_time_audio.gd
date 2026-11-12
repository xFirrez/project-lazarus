extends SceneTree
func _init() -> void:
	await process_frame
	var t: int = Time.get_ticks_msec()
	PerkAudio.ensure()
	var t2: int = Time.get_ticks_msec()
	PowerUpAudio.ensure()
	var t3: int = Time.get_ticks_msec()
	var pm := PerkMachine.new()
	pm.perk_id = &"ironhide"
	print("perk audio ms ", t2 - t, " powerup audio ms ", t3 - t2)
	quit()
