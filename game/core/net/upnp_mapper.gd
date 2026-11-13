# UpnpMapper — best-effort UPnP port mapping for direct-IP hosting (D-045 fallback plan): runs
# gateway discovery + UDP port mapping on a worker thread (discovery blocks for ~2 s), exposes a
# status line for the lobby, and removes the mapping when the session closes. Failure is normal
# (no UPnP router, CGNAT): the lobby then points players at the VPN guide (docs/NETWORKING.md).
# Authority: host machine only (local network configuration).
class_name UpnpMapper
extends RefCounted

enum Status { IDLE, WORKING, MAPPED, FAILED }

const DISCOVER_TIMEOUT_MS: int = 2000
const DESCRIPTION: String = "Project Lazarus co-op"

var status: Status = Status.IDLE
var port: int = 0
var external_ip: String = ""
var error_text: String = ""

var _thread: Thread = null
var _upnp: UPNP = null
var _mutex: Mutex = Mutex.new()


func start(p_port: int) -> void:
	port = p_port
	status = Status.WORKING
	_thread = Thread.new()
	_thread.start(_worker)


func _worker() -> void:
	var u: UPNP = UPNP.new()
	var err: int = u.discover(DISCOVER_TIMEOUT_MS, 2, "InternetGatewayDevice")
	var gateway: UPNPDevice = u.get_gateway() if err == UPNP.UPNP_RESULT_SUCCESS else null
	_mutex.lock()
	if gateway == null or not gateway.is_valid_gateway():
		status = Status.FAILED
		error_text = "no UPnP gateway found"
	else:
		var map_err: int = u.add_port_mapping(port, port, DESCRIPTION, "UDP", 0)
		if map_err == UPNP.UPNP_RESULT_SUCCESS:
			status = Status.MAPPED
			external_ip = u.query_external_address()
			_upnp = u
		else:
			status = Status.FAILED
			error_text = "port mapping refused (%d)" % map_err
	_mutex.unlock()


func status_text() -> String:
	_mutex.lock()
	var t: String = ""
	match status:
		Status.WORKING:
			t = "UPnP: opening port %d ..." % port
		Status.MAPPED:
			t = "UPnP: port %d open — friends join %s:%d" % [port, external_ip, port]
		Status.FAILED:
			t = "UPnP: %s — use LAN, a VPN (Tailscale) or forward UDP %d" % [error_text, port]
	_mutex.unlock()
	return t


func stop() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _upnp != null:
		_upnp.delete_port_mapping(port, "UDP")
		_upnp = null
	status = Status.IDLE
