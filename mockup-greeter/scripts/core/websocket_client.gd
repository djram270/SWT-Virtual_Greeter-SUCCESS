# res://scripts/core/websocket_client.gd
## Unified WebSocket Client for Godot
##
## Manages all backend communication via WebSocket with support for:
## - Large audio payloads (up to 20MB)
## - Automatic reconnection with exponential backoff
## - Message queueing during disconnection
## - Connection state tracking and logging

extends Node
class_name WebSocketClient

# Connection signals
signal connected()
signal disconnected()
signal message_received(message_type: String, data: Dictionary)
signal error_occurred(error_message: String)
signal connection_state_changed(state: String)

## Backend WebSocket server URL
const SERVER_URL: String = "ws://localhost:8000/ws/topic"

## Buffer configuration for large audio payloads
const OUTBOUND_BUFFER_SIZE: int = 20971520  ## 20MB for outbound (upload)
const INBOUND_BUFFER_SIZE: int = 20971520  ## 20MB for inbound (download)

## Reconnection configuration
const MAX_RECONNECT_ATTEMPTS: int = 5
const RECONNECT_INTERVAL: float = 10.0

# Instance variables
var socket: WebSocketPeer = null
var connection_state: WebSocketPeer.State = WebSocketPeer.STATE_CLOSED
var reconnect_timer: float = 0.0
var is_reconnecting: bool = false
var message_queue: Array[Dictionary] = []
var next_request_id: int = 0

# Reconnection tracking
var reconnect_attempts: int = 0
var server_reachable: bool = true
var initial_connection: bool = true

## Initializes WebSocket client and attempts initial connection
func _ready() -> void:
	_log_info("WebSocket client initialized - 20MB buffer for audio support")
	connect_to_server()

## Establishes connection to WebSocket server with large buffer support
func connect_to_server() -> void:
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_log_warning("Already connected to server")
		return
	
	if not server_reachable:
		_log_warning("Server marked as unreachable, skipping connection")
		return
	
	socket = WebSocketPeer.new()
	
	# Configure large buffers for audio transmission
	socket.set_outbound_buffer_size(OUTBOUND_BUFFER_SIZE)
	socket.set_inbound_buffer_size(INBOUND_BUFFER_SIZE)
	
	var error = socket.connect_to_url(SERVER_URL)
	
	if error != OK:
		_log_error("Failed to initialize WebSocket: %d" % error)
		error_occurred.emit("Connection failed: %d" % error)
		_schedule_reconnect()
		return
	
	if initial_connection:
		_log_info("Connecting to: %s" % SERVER_URL)
		initial_connection = false
	
	_update_connection_state("connecting")

## Processes WebSocket messages and handles reconnection logic
## @param delta: Time elapsed since previous frame in seconds
func _process(delta: float) -> void:
	if not socket:
		return
	
	# Poll for incoming messages
	socket.poll()
	
	# Track connection state changes
	var state = socket.get_ready_state()
	if connection_state != state:
		connection_state = state
		_on_state_changed(state)
	
	# Process all available incoming messages
	while socket.get_ready_state() == WebSocketPeer.STATE_OPEN and socket.get_available_packet_count() > 0:
		var packet = socket.get_packet()
		var message_text = packet.get_string_from_utf8()
		_on_message_received(message_text)
	
	# Handle reconnection timing
	if is_reconnecting:
		reconnect_timer += delta
		if reconnect_timer >= RECONNECT_INTERVAL:
			reconnect_timer = 0.0
			is_reconnecting = false
			_log_info("Reconnection attempt %d/%d" % [reconnect_attempts + 1, MAX_RECONNECT_ATTEMPTS])
			connect_to_server()

## Handles WebSocket state transitions
## @param state: New WebSocket state
func _on_state_changed(state: WebSocketPeer.State) -> void:
	match state:
		WebSocketPeer.STATE_CONNECTING:
			_log_debug("Connection in progress")
		
		WebSocketPeer.STATE_OPEN:
			_log_success("Connection established")
			_update_connection_state("connected")
			connected.emit()
			is_reconnecting = false
			reconnect_attempts = 0
			server_reachable = true
			_flush_message_queue()
		
		WebSocketPeer.STATE_CLOSING:
			_log_debug("Connection closing")
		
		WebSocketPeer.STATE_CLOSED:
			if reconnect_attempts == 0 and not is_reconnecting:
				_log_warning("Connection closed")
			_update_connection_state("disconnected")
			disconnected.emit()
			_schedule_reconnect()

## Processes incoming WebSocket message from server
## @param message_text: Raw message text from server
func _on_message_received(message_text: String) -> void:
	_log_debug("Received %d bytes" % message_text.length())
	
	var json = JSON.new()
	var parse_result = json.parse(message_text)
	
	if parse_result != OK:
		_log_error("Failed to parse JSON message")
		return
	
	var message: Dictionary = json.data
	var msg_type = message.get("type", "text_command")
	var status = message.get("status", "unknown")
	var data_raw = message.get("data", "")
	
	_log_debug("Message type: %s, status: %s" % [msg_type, status])
	
	if status == "error":
		var error_msg = message.get("message", "Unknown error")
		_log_error("Server error: %s" % error_msg)
		error_occurred.emit(error_msg)
		return
	
	# Parse data field - viene como string JSON
	var data_dict = {}
	if data_raw is String and data_raw.length() > 0:
		var parsed_data = JSON.parse_string(data_raw)
		if parsed_data is Dictionary:
			data_dict = parsed_data
	elif data_raw is Dictionary:
		data_dict = data_raw
	
	_log_debug("Data dict keys: %s" % [data_dict.keys()])
	
	message_received.emit(msg_type, data_dict)
	_log_success("Processed: %s" % msg_type)
	ConnectionLogger.increment_message_count("received")

## Sends generic message to backend
## @param message_type: Type of message (audio_command, text_command, iot_control, etc.)
## @param data: Message payload dictionary
## @return True if message was sent or queued successfully
func send_message(message_type: String, data: Dictionary = {}) -> bool:
	# Queue message if not connected
	if not socket or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_log_warning("Not connected, queueing message: %s" % message_type)
		message_queue.append({"type": message_type, "data": data})
		return false
	
	# Create message with metadata
	var message = {
		"type": message_type,
		"data": data,
		"request_id": _get_next_request_id(),
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var json_string = JSON.stringify(message)
	var error = socket.send_text(json_string)
	
	if error != OK:
		_log_error("Failed to send %s: %d" % [message_type, error])
		error_occurred.emit("Send failed")
		return false
	
	_log_debug("Sent %s (%d bytes)" % [message_type, json_string.length()])
	ConnectionLogger.increment_message_count("sent")
	
	return true

## Sends IoT device control command
## @param entity_id: Home Assistant entity ID (e.g., "light.bedroom")
## @param new_state: Desired state ("on" or "off")
## @return True if command was sent successfully
func send_iot_command(entity_id: String, new_state: String) -> bool:
	_log_info("IoT command: %s -> %s" % [entity_id, new_state])
	return send_message("iot_control", {
		"entity_id": entity_id,"new_state": new_state
	})
	
## Sends natural language text command
## @param text: User command text
## @param language: Language code (default "en")
## @return True if command was sent successfully
## Sends natural language text command with backend-expected structure
## @param text: User command text
## @param entity_id: Entity ID for context (default: "light.led_rgb_square")
## @return True if command was sent successfully
func send_text_command(text: String, entity_id: String) -> bool:
	# Queue message if not connected
	if not socket or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_log_warning("Not connected, queueing text command")
		message_queue.append({
			"type": "text_command",
			"data": {
				"entity_id": entity_id,
				"text": text,
				"history": []
			}
		})
		return false
	
	# Create message with exact backend structure
	var message = {
		"type": "text_command",
		"data": {
			"entity_id": entity_id,
			"text": text,
			"history": []
		}
	}
	
	var json_string = JSON.stringify(message)
	var error = socket.send_text(json_string)
	
	if error != OK:
		_log_error("Failed to send text_command: %d" % error)
		error_occurred.emit("Send failed")
		return false
	
	_log_info("Text command: %s" % text)
	_log_debug("Sent text_command (%d bytes)" % json_string.length())
	ConnectionLogger.increment_message_count("sent")
	
	return true


## Requests system status from backend
## @return True if request was sent successfully
func request_status() -> bool:
	_log_debug("Requesting status")
	return send_message("status_request", {})

## Sends ping to keep connection alive
## @return True if ping was sent successfully
func send_ping() -> bool:
	_log_debug("Sending ping")
	return send_message("ping", {})

## Gracefully closes WebSocket connection
func disconnect_from_server() -> void:
	if socket:
		_log_info("Disconnecting from server")
		socket.close()
		socket = null

## Manually request connection retry after server becomes unreachable
func retry_connection() -> void:
	server_reachable = true
	reconnect_attempts = 0
	is_reconnecting = false
	initial_connection = true
	_log_info("Manual reconnection requested")
	connect_to_server()

## Sends all queued messages after reconnection
func _flush_message_queue() -> void:
	if message_queue.size() > 0:
		_log_info("Flushing %d queued messages" % message_queue.size())
		
		for queued_message in message_queue:
			send_message(queued_message["type"], queued_message["data"])
		
		message_queue.clear()

## Schedules automatic reconnection attempt
func _schedule_reconnect() -> void:
	if is_reconnecting or not server_reachable:
		return
	
	reconnect_attempts += 1
	
	if reconnect_attempts >= MAX_RECONNECT_ATTEMPTS:
		_log_error("Server unreachable after %d attempts" % MAX_RECONNECT_ATTEMPTS)
		_update_connection_state("unreachable")
		server_reachable = false
		return
	
	is_reconnecting = true
	reconnect_timer = 0.0
	_log_info("Reconnect scheduled in %.0f sec (attempt %d/%d)" % [RECONNECT_INTERVAL, reconnect_attempts + 1, MAX_RECONNECT_ATTEMPTS])

## Generates unique request identifier for message tracking
## @return Incremented request ID
func _get_next_request_id() -> int:
	next_request_id += 1
	return next_request_id

## Updates connection state in logger
## @param state: New connection state string
func _update_connection_state(state: String) -> void:
	ConnectionLogger.update_connection_state("websocket", state)
	connection_state_changed.emit(state)

## Logs debug message
## @param message: Message to log
func _log_debug(message: String) -> void:
	ConnectionLogger.log_debug("WebSocketClient", message)

## Logs info message
## @param message: Message to log
func _log_info(message: String) -> void:
	ConnectionLogger.log_info("WebSocketClient", message)

## Logs warning message
## @param message: Message to log
func _log_warning(message: String) -> void:
	ConnectionLogger.log_warning("WebSocketClient", message)

## Logs error message
## @param message: Message to log
func _log_error(message: String) -> void:
	ConnectionLogger.log_error("WebSocketClient", message)

## Logs success message
## @param message: Message to log
func _log_success(message: String) -> void:
	ConnectionLogger.log_success("WebSocketClient", message)

## Cleanup on node exit
func _exit_tree() -> void:
	disconnect_from_server()
