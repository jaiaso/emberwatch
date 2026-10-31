extends Node
## RPCs live at /root/Session on every peer. Never accept client state snapshots.

signal changed
signal message(text: String)
signal pinged(pos: Vector2)

const Simulation = preload("res://scripts/simulation.gd")
const PORT = 27840
const VERSION = "1.0.0"
const SAVE_PATH = "user://emberwatch-v1.save"
const SAVE_MAGIC = "EMBERWATCH_SAVE_1"
var sim = Simulation.new()
var mode = "menu"
var status = ""
var local_id = 1
var snapshot_time = 0.0
var connect_time = 0.0
var command_windows: Dictionary = {}
var send_serial = 0
var receive_serial = -1
var assemblies: Dictionary = {}
var welcomed = false
var allow_autosave = true
var saved_wave = 0

func _ready() -> void:
	sim.reset()
	sim.add_player(1)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_server_left)

func _physics_process(delta: float) -> void:
	if mode in ["solo", "host"]:
		sim.step(delta)
		if mode == "solo" and allow_autosave and sim.cleared_wave > saved_wave and sim.running:
			saved_wave = sim.cleared_wave
			save_game(false)
		if mode == "host":
			snapshot_time += delta
			if snapshot_time >= 0.1:
				snapshot_time = 0.0
				_send_state()
	elif mode == "connecting" or (mode == "client" and not welcomed):
		connect_time += delta
		if connect_time > 9.0:
			_failed()

func _close() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	command_windows.clear()
	assemblies.clear()
	send_serial = 0
	receive_serial = -1
	welcomed = false

func back_to_menu() -> void:
	_close()
	mode = "menu"
	local_id = 1
	sim.reset()
	sim.add_player(1)
	status = ""
	changed.emit()

func solo(level: int = -1) -> void:
	back_to_menu()
	if level >= 0:
		sim.difficulty = clampi(level, 0, 2)
	sim.next_wave = [85.0, 70.0, 60.0][sim.difficulty]
	saved_wave = 0
	mode = "solo"
	sim.running = true
	changed.emit()

func host(level: int = -1) -> void:
	back_to_menu()
	if level >= 0:
		sim.difficulty = clampi(level, 0, 2)
	sim.next_wave = [85.0, 70.0, 60.0][sim.difficulty]
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3)
	if error != OK:
		status = "部屋を作れませんでした（UDP %d / エラー %d）。" % [PORT, error]
		changed.emit()
		return
	multiplayer.multiplayer_peer = peer
	mode = "host"
	status = "盟友を待っています。1人でも出陣できます。"
	changed.emit()

func join(address: String) -> void:
	back_to_menu()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address.strip_edges(), PORT)
	if error != OK:
		status = "接続を開始できません（エラー %d）。" % error
		changed.emit()
		return
	multiplayer.multiplayer_peer = peer
	mode = "connecting"
	connect_time = 0.0
	status = "砦に接続中…"
	changed.emit()

func start() -> void:
	if mode == "host" and sim.result == "":
		sim.running = true
		status = ""
		_welcome.rpc(_snapshot())
		changed.emit()

func _peer_connected(id: int) -> void:
	if mode != "host":
		return
	if sim.result != "":
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	get_tree().create_timer(7.0).timeout.connect(func():
		if mode == "host" and id in multiplayer.get_peers() and not sim.players.has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id))

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(version: String) -> void:
	if mode != "host":
		return
	var sender = multiplayer.get_remote_sender_id()
	if sim.players.has(sender):
		return
	if version != VERSION:
		_reject.rpc_id(sender)
		return
	sim.add_player(sender)
	_welcome.rpc_id(sender, _snapshot())
	changed.emit()

@rpc("authority", "call_remote", "reliable", 0)
func _reject() -> void:
	back_to_menu()
	status = "バージョンが違います。全員 v%s を使用してください。" % VERSION
	changed.emit()

func _peer_disconnected(id: int) -> void:
	if mode == "host":
		if sim.players.has(id):
			sim.remove_player(id)
		command_windows.erase(id)
		changed.emit()

func _connected() -> void:
	mode = "client"
	local_id = multiplayer.get_unique_id()
	status = "ホストの出陣を待っています。"
	_hello.rpc_id(1, VERSION)
	changed.emit()

func _failed() -> void:
	back_to_menu()
	status = "接続できません。IP・ホスト・全員のバージョンを確認してください。"
	changed.emit()

func _server_left() -> void:
	back_to_menu()
	status = "ホストとの接続が切れました。"
	changed.emit()

@rpc("authority", "call_remote", "reliable", 0)
func _welcome(state: Dictionary) -> void:
	if state.get("protocol", "") != VERSION:
		_reject()
		return
	sim.apply_snapshot(state)
	welcomed = true
	changed.emit()

func _snapshot() -> Dictionary:
	var state: Dictionary = sim.snapshot()
	state.protocol = VERSION
	return state

func _send_state() -> void:
	if multiplayer.get_peers().is_empty():
		return
	send_serial += 1
	var bytes = var_to_bytes(_snapshot()).compress(FileAccess.COMPRESSION_GZIP)
	var count = int(ceil(float(bytes.size()) / 900.0))
	for index in range(count):
		_state_part.rpc(send_serial, index, count, bytes.slice(index * 900, mini((index + 1) * 900, bytes.size())))

@rpc("authority", "call_remote", "unreliable", 1)
func _state_part(serial: int, index: int, count: int, data: PackedByteArray) -> void:
	# Keep each RPC below the UDP MTU; incomplete snapshots are superseded, never queued.
	if mode != "client" or serial <= receive_serial or count < 1 or count > 128 or index < 0 or index >= count or data.size() > 900:
		return
	for old in assemblies.keys():
		if int(old) < serial - 3:
			assemblies.erase(old)
	if not assemblies.has(serial):
		assemblies[serial] = {"count": count, "parts": {}}
	var assembly: Dictionary = assemblies[serial]
	if assembly.count != count:
		return
	assembly.parts[index] = data
	if assembly.parts.size() != count:
		return
	var compressed = PackedByteArray()
	for i in range(count):
		compressed.append_array(assembly.parts[i])
	assemblies.erase(serial)
	var decoded = bytes_to_var(compressed.decompress_dynamic(4000000, FileAccess.COMPRESSION_GZIP))
	if decoded is Dictionary:
		receive_serial = serial
		_receive_state(decoded)

func _receive_state(state: Dictionary) -> void:
	if mode != "client" or int(state.tick) < sim.tick or state.get("match_id", -1) != sim.match_id:
		return
	var was_running: bool = sim.running
	var old_result: String = sim.result
	sim.apply_snapshot(state)
	if sim.running != was_running or sim.result != old_result:
		changed.emit()

func issue(action: String, ids: Array = [], pos: Vector2 = Vector2.ZERO, extra: String = "") -> void:
	if action == "pause":
		if mode == "solo" and sim.running:
			sim.paused = not sim.paused
		return
	if action == "save":
		save_game()
		return
	if mode == "client":
		_request.rpc_id(1, action, ids, pos, extra)
	elif mode in ["solo", "host"]:
		_execute(local_id, action, ids, pos, extra)

@rpc("any_peer", "call_remote", "reliable", 0)
func _request(action: String, ids: Array, pos: Vector2, extra: String) -> void:
	if mode != "host":
		return
	var sender = multiplayer.get_remote_sender_id()
	var now = Time.get_ticks_msec()
	var window: Dictionary = command_windows.get(sender, {"start": now, "count": 0})
	if now - int(window.start) >= 1000:
		window = {"start": now, "count": 0}
	window.count += 1
	command_windows[sender] = window
	if window.count > 18 or extra.length() > 32 or ids.size() > 120:
		return
	_execute(sender, action, ids, pos, extra)

func _execute(sender: int, action: String, ids: Array, pos: Vector2, extra: String) -> void:
	var error: String = sim.command(sender, action, ids, pos, extra)
	if error != "":
		if sender == local_id:
			message.emit(error)
		else:
			_feedback.rpc_id(sender, error)
	elif action == "ping":
		pinged.emit(pos)
		if mode == "host":
			_ping.rpc(pos)

@rpc("authority", "call_remote", "reliable", 0)
func _feedback(text: String) -> void:
	message.emit(text)

@rpc("authority", "call_remote", "reliable", 0)
func _ping(pos: Vector2) -> void:
	pinged.emit(pos)

func rematch() -> void:
	if mode not in ["solo", "host"]:
		return
	var peers = sim.players.keys()
	sim.reset()
	for id in peers:
		sim.add_player(id)
	sim.next_wave = [85.0, 70.0, 60.0][sim.difficulty]
	saved_wave = 0
	sim.running = true
	if mode == "host":
		_welcome.rpc(_snapshot())
	changed.emit()

func save_game(notify: bool = true) -> bool:
	if mode != "solo" or not sim.running:
		if notify:
			message.emit("セーブはソロプレイ中に利用できます。")
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		message.emit("セーブできませんでした。")
		return false
	var payload = var_to_bytes({"version": VERSION, "state": sim.snapshot()})
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	file.store_line(SAVE_MAGIC)
	file.store_32(payload.size())
	file.store_buffer(hash.finish())
	file.store_buffer(payload)
	file.close()
	if notify:
		message.emit("進行状況をセーブしました。")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func continue_game() -> bool:
	if mode != "menu" or not has_save():
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 4000000:
		return false
	if file.get_line() != SAVE_MAGIC or file.get_length() - file.get_position() < 36:
		file.close()
		return false
	var size = file.get_32()
	var expected = file.get_buffer(32)
	if size != file.get_length() - file.get_position():
		file.close()
		return false
	var payload = file.get_buffer(size)
	file.close()
	var hash = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	if hash.finish() != expected:
		return false
	var data = bytes_to_var(payload)
	if not data is Dictionary or data.get("version", "") != VERSION or not data.get("state", {}) is Dictionary:
		status = "セーブデータを読み込めませんでした。"
		changed.emit()
		return false
	var state: Dictionary = data.state
	for key in ["units", "buildings", "resources", "players", "stock", "elapsed", "wave", "next_wave", "running", "result", "event_text", "event_serial", "tick"]:
		if not state.has(key):
			return false
	back_to_menu()
	sim.apply_snapshot(state)
	sim.paused = false
	saved_wave = sim.cleared_wave
	mode = "solo"
	changed.emit()
	return true
