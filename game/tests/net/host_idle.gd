# Host that just plays (bot-driven) until killed by the test driver. Used by host-loss tests.
extends "res://tests/net/autotest_base.gd"


func _ready() -> void:
	timeout = 30.0


func _physics_process(_delta: float) -> void:
	var s: PlayerSync = sync()
	if s != null and s.local_avatar() != null and not s.local_avatar().bot_driver.is_valid():
		s.local_avatar().bot_driver = circle_driver(0.0)
		Log.info(&"autotest", "AUTOTEST READY host")
