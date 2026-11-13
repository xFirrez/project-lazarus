# Journal persistence (AC-14.5 / AC-14.4): unlocks and badges survive a "relaunch" (reload from disk).
extends GutTest


func before_each() -> void:
	Journal.path_override = "user://journal_unit_test.cfg"
	Journal.clear()


func after_all() -> void:
	Journal.clear()
	Journal.path_override = ""
	Journal.forget_cache()


func test_unlock_persists_across_reload() -> void:
	assert_true(Journal.unlock(&"L01"))
	assert_false(Journal.unlock(&"L01"), "second unlock is not new")
	Journal.unlock(&"R02")
	Journal.forget_cache()
	assert_true(Journal.is_unlocked(&"L01"))
	assert_true(Journal.is_unlocked(&"R02"))
	assert_false(Journal.is_unlocked(&"R09"))
	assert_eq(Journal.unlocked_ids().size(), 2)


func test_badges_per_player_count() -> void:
	Journal.award_badge(&"vesper_peak", &"requiem", 1)
	Journal.award_badge(&"vesper_peak", &"requiem", 4)
	Journal.award_badge(&"vesper_peak", &"requiem", 1)
	Journal.forget_cache()
	assert_eq(Journal.badges(&"vesper_peak"), {&"requiem": [1, 4]})
	assert_eq(Journal.badges(&"other_map"), {})
	assert_string_contains(MapSelectScreen.badge_text(&"vesper_peak"), "Requiem (1p, 4p)")
