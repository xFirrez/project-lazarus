# DebugOverlay — FPS / frame time and live net stats (RTT, bytes in/out per second, loss).
# Toggled with F3 (action toggle_net_overlay) or the `overlay` console command. Local only.
class_name DebugOverlay
extends Label

var _accum: float = 0.0
var _frames: int = 0
var _worst_ms: float = 0.0
var _fps: float = 0.0
var _avg_ms: float = 0.0
var _shown_worst: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -460.0
	offset_right = -12.0
	offset_top = 10.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override(&"font_size", 14)
	add_theme_color_override(&"font_outline_color", Color.BLACK)
	add_theme_constant_override(&"outline_size", 4)
	visible = CommandLine.has_flag("overlay")


func _process(delta: float) -> void:
	_accum += delta
	_frames += 1
	_worst_ms = maxf(_worst_ms, delta * 1000.0)
	if _accum >= 0.5:
		_fps = _frames / _accum
		_avg_ms = _accum * 1000.0 / _frames
		_shown_worst = _worst_ms
		_accum = 0.0
		_frames = 0
		_worst_ms = 0.0
	if not visible:
		return
	var role: String = "offline"
	if Net.is_active():
		role = "host" if Net.is_host() else "client"
	text = (
		"%.0f FPS  %.2f ms avg  %.1f ms max\n%s  peers %d  RTT %.0f ms\nout %.1f KB/s  in %.1f KB/s  loss %.1f%%\nnetsim %s"
		% [
			_fps,
			_avg_ms,
			_shown_worst,
			role,
			Net.peers.size(),
			Net.rtt_ms(),
			Net.bytes_out_per_sec / 1024.0,
			Net.bytes_in_per_sec / 1024.0,
			Net.loss_estimate * 100.0,
			Net.sim.describe()
		]
	)
