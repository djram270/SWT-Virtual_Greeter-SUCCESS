# res://scripts/ui/interface.gd
## Chat Interface Controller with Audio Recording and IoT Device Selection
##
## Features:
## - Audio recording and playback with visual feedback
## - Text message input with Enter key support
## - WebSocket communication with backend
## - Conversation history tracking for context
## - IoT device selection with automatic timeout (2 minutes)
## - Dynamic positioning based on ConnectionLogger visibility
## - Distance-based visibility (appears when near robot within 3 meters)
## - Automatic transcription flow: Audio -> Backend -> Transcription -> Text Command -> Response

extends PanelContainer

## Emitted when audio playback state changes
signal is_audio_playing(a_value: bool)

# UI Visual Constants
const ALPHA_DISABLED: float = 0.7
const PATH_ICONS: String = "res://assets/icons/%s"

# Icon Resources
const ICON_RECORDING: Texture2D = preload(PATH_ICONS % "recording.svg")
const ICON_NOT_RECORDING: Texture2D = preload(PATH_ICONS % "not_recording.svg")
const ICON_PAUSE: Texture2D = preload(PATH_ICONS % "pause.svg")
const ICON_PLAY: Texture2D = preload(PATH_ICONS % "play.svg")

# UI Node References
var button_record: TextureButton
var button_play: TextureButton
var button_send: TextureButton
var message_input: LineEdit
var panel_spectrum: PanelContainer
var audio_playback: AudioStreamPlayer
var messages_list: VBoxContainer
var scroll_container: ScrollContainer

# Audio Recording System
var effect: AudioEffectRecord
var recording: AudioStreamWAV
var has_recording: bool = false

# System References
var websocket_client: Node = null
var greeter: Node = null
var player: Node3D = null
var greeter_robot: Node = null
var connection_logger: CanvasLayer = null

# Distance-based visibility control
const INTERACTION_DISTANCE: float = 3.0
var is_near_robot: bool = false

# Dynamic positioning constants
const STATUS_BAR_HEIGHT: float = 35.0
const LOG_PANEL_HEIGHT: float = 250.0
const INTERFACE_HEIGHT: float = 100.0
const MARGIN_BOTTOM: float = 5.0

# Conversation history system
var conversation_history: Array[Dictionary] = []

# Audio flow control
var waiting_for_transcription: bool = false

# IoT device selection system
var hover_interaction: Node = null
var last_valid_entity: String = ""
var entity_selection_time: float = 0.0
const ENTITY_TIMEOUT: float = 120.0  # Seconds before auto-deselect (2 minutes)

## Initialize interface components and establish connections
func _ready() -> void:
	_setup_ui_nodes()
	_setup_audio_system()
	_connect_websocket()
	_find_system_references()
	_setup_anchors()
	
	# Start hidden
	visible = false
	
	print("[Interface] System initialized")
	print("[Interface] History system active")
	print("[Interface] Object detection: %s" % ("Active" if hover_interaction else "Inactive"))

## Locate and configure UI node references
func _setup_ui_nodes() -> void:
	button_record = $VBox/HBox/HFlowContainer/RecordButton
	button_play = $VBox/HBox/HFlowContainer/PlayButton
	button_send = $VBox/HBox/SendButton
	message_input = $VBox/HBox/MessageInput
	panel_spectrum = $VBox/BottomHBox/SpectrumPanel
	audio_playback = $RecordingPlayback
	messages_list = $VBox/BottomHBox/ConversationArea/MessagesList
	scroll_container = $VBox/BottomHBox/ConversationArea
	
	if message_input:
		message_input.placeholder_text = "Type your message..."
		message_input.text_submitted.connect(_on_message_input_submitted)

## Configure audio recording effect and initial UI state
func _setup_audio_system() -> void:
	effect = AudioServer.get_bus_effect(1, 0)
	
	if panel_spectrum:
		panel_spectrum.modulate.a = ALPHA_DISABLED
	
	if button_play:
		button_play.modulate.a = ALPHA_DISABLED
		button_play.disabled = true
	
	if button_send:
		button_send.disabled = false

## Connect to WebSocket autoload and disconnect VirtualGreeter to prevent duplicate responses
func _connect_websocket() -> void:
	websocket_client = get_tree().root.get_node_or_null("WebsocketClient")
	
	if not websocket_client:
		push_error("WebSocketClient autoload not found")
		return
	
	# Disconnect VirtualGreeter from WebSocket to prevent duplicate responses
	if greeter and greeter.has_signal("message_received"):
		var connections = websocket_client.message_received.get_connections()
		for connection in connections:
			if connection["callable"].get_object() == greeter:
				websocket_client.message_received.disconnect(connection["callable"])
				print("[Interface] VirtualGreeter disconnected from WebSocket")
	
	# Connect WebSocket signals
	if websocket_client.has_signal("connected"):
		websocket_client.connected.connect(_on_websocket_connected)
	if websocket_client.has_signal("disconnected"):
		websocket_client.disconnected.connect(_on_websocket_disconnected)
	if websocket_client.has_signal("message_received"):
		websocket_client.message_received.connect(_on_websocket_message)

## Find references to player, robot, logger and hover system in scene tree
func _find_system_references() -> void:
	# Find player and robot
	player = get_tree().root.find_child("ProtoController", true, false) as Node3D
	greeter_robot = get_tree().root.find_child("GreeterRobot", true, false)
	
	if greeter_robot:
		greeter = greeter_robot.get_node_or_null("VirtualGreeter")
	
	if not greeter:
		greeter = get_tree().root.find_child("VirtualGreeter", true, false)
	
	# Find ConnectionLogger
	connection_logger = get_tree().root.get_node_or_null("ConnectionLogger")
	
	if not connection_logger:
		push_warning("ConnectionLogger not found")
	
	# Find hover interaction system - try global search first
	hover_interaction = get_tree().root.find_child("HoroverInteraction", true, false)
	
	# Search inside camera if not found globally
	if not hover_interaction and player:
		var head = player.get_node_or_null("Head")
		if head:
			var camera = head.get_node_or_null("Camera3D")
			if camera:
				for child in camera.get_children():
					if child.name.to_lower().contains("hover") or child.name.to_lower().contains("interaction"):
						hover_interaction = child
						break
	
	if not hover_interaction:
		push_warning("HoroverInteraction not found - commands will use empty entity_id")
		print("[Interface] IoT object detection disabled")
	else:
		print("[Interface] Hover system found: %s" % hover_interaction.get_path())
		print("[Interface] IoT object detection active")
	
	if not player:
		push_warning("ProtoController not found")
	if not greeter_robot:
		push_warning("GreeterRobot not found")
	if not greeter:
		push_warning("VirtualGreeter not found")

## Configure interface anchoring to bottom of screen
func _setup_anchors() -> void:
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	_update_position()

## Update interface position based on ConnectionLogger visibility state
func _update_position() -> void:
	if not connection_logger:
		# Default position if no logger exists
		offset_top = -(INTERFACE_HEIGHT + STATUS_BAR_HEIGHT + MARGIN_BOTTOM)
		offset_bottom = -STATUS_BAR_HEIGHT
		return
	
	# Check if log panel is currently visible
	var log_visible = false
	if "log_panel_visible" in connection_logger:
		log_visible = connection_logger.log_panel_visible
	elif connection_logger.log_panel:
		log_visible = connection_logger.log_panel.visible
	
	if log_visible:
		# Log panel visible: move interface up to avoid overlap
		offset_top = -(INTERFACE_HEIGHT + STATUS_BAR_HEIGHT + LOG_PANEL_HEIGHT + MARGIN_BOTTOM)
		offset_bottom = -(STATUS_BAR_HEIGHT + LOG_PANEL_HEIGHT)
	else:
		# Log panel hidden: stick interface to status bar
		offset_top = -(INTERFACE_HEIGHT + STATUS_BAR_HEIGHT + MARGIN_BOTTOM)
		offset_bottom = -STATUS_BAR_HEIGHT

## Main process loop - handles distance check, position update, entity selection, and timeout
func _process(_delta: float) -> void:
	_check_distance_to_robot()
	_update_position()
	_update_selected_entity()
	_check_entity_timeout()

## Show/hide interface based on distance to robot
func _check_distance_to_robot() -> void:
	if not player or not greeter_robot:
		return
	
	var distance = player.global_position.distance_to(greeter_robot.global_position)
	var was_near = is_near_robot
	is_near_robot = distance <= INTERACTION_DISTANCE
	
	# Show when approaching robot
	if is_near_robot and not was_near:
		visible = true
		print("[Interface] Robot nearby - showing UI (distance: %.2f)" % distance)
	# Hide when moving away (only if not actively using interface)
	elif not is_near_robot and was_near:
		if not _is_ui_interacting():
			visible = false
			print("[Interface] Robot far - hiding UI")

## Update selected IoT device entity_id from hover system
func _update_selected_entity() -> void:
	if not hover_interaction:
		return
	
	if not "current_target" in hover_interaction:
		return
	
	var target = hover_interaction.current_target
	
	# No target - maintain previous selection
	if target == null:
		return
	
	# Attempt to get entity_id from target object using multiple methods
	var found_entity = ""
	
	# Method 1: Direct exported property
	if "entity_id" in target:
		found_entity = target.entity_id
	
	# Method 2: get_entity_id() function
	if found_entity == "" and target.has_method("get_entity_id"):
		found_entity = target.get_entity_id()
	
	# Method 3: Search in script properties
	if found_entity == "" and target.get_script() != null:
		var script_properties = target.get_property_list()
		for prop in script_properties:
			if prop.name == "entity_id":
				found_entity = target.get(prop.name)
				break
	
	# Update if valid entity_id found and different from current
	if found_entity != "" and found_entity != last_valid_entity:
		last_valid_entity = found_entity
		entity_selection_time = Time.get_ticks_msec() / 1000.0
		print("[Interface] Object selected: %s (entity: %s)" % [target.name, found_entity])
		print("[Interface] Selection valid for %.0f seconds" % ENTITY_TIMEOUT)

## Check if entity selection has timed out and clear if expired
func _check_entity_timeout() -> void:
	if last_valid_entity == "":
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed_time = current_time - entity_selection_time
	
	# Clear selection after timeout period
	if elapsed_time >= ENTITY_TIMEOUT:
		print("[Interface] Timeout: Deselecting '%s' (%.1f seconds elapsed)" % [last_valid_entity, elapsed_time])
		last_valid_entity = ""
		entity_selection_time = 0.0

## Check if UI is currently in use (recording or has audio ready to send)
func _is_ui_interacting() -> bool:
	return (effect and effect.is_recording_active()) or has_recording

## Handle WebSocket connection established event
func _on_websocket_connected() -> void:
	print("[Interface] Connected to WebSocket")

## Handle WebSocket disconnection event
func _on_websocket_disconnected() -> void:
	print("[Interface] Disconnected from WebSocket")

## Process incoming WebSocket messages - handles both transcriptions and assistant responses
func _on_websocket_message(message_type: String, data: Dictionary) -> void:
	print("[Interface] Message received: %s" % message_type)
	
	if message_type != "text_command":
		return
	
	# CASE 1: Audio transcription from Whisper
	if data.has("transcription"):
		var transcription = data["transcription"].strip_edges()
		print("[Interface] Transcription received: %s" % transcription)
		
		# Display transcription in chat
		_add_message_to_chat("You", transcription)
		
		# Add to conversation history
		conversation_history.append({
			"role": "user",
			"content": transcription
		})
		
		# Resend as text_command for processing
		waiting_for_transcription = false
		_send_text_command_with_history(transcription)
		return
	
	# CASE 2: Assistant response
	var response_text = ""
	
	if data.has("comment"):
		response_text = data["comment"]
	elif data.has("suggest"):
		response_text = data["suggest"]
	elif data.has("text"):
		response_text = data["text"]
	elif data.has("response"):
		response_text = data["response"]
	
	if response_text == "":
		print("[Interface] Warning: No response from backend")
		return
	
	print("[Interface] Rob says: %s" % response_text)
	
	# Display response in chat
	_add_message_to_chat("Rob", response_text)
	
	# Add to conversation history
	conversation_history.append({
		"role": "assistant",
		"content": response_text
	})
	
	# Make robot speak using TTS
	_make_robot_speak(response_text)

## Trigger robot TTS to speak the assistant's response
func _make_robot_speak(text: String) -> void:
	if greeter and greeter.has_node("TTSManager"):
		var tts = greeter.get_node("TTSManager")
		if tts.has_method("speak"):
			tts.speak(text)
			print("[Interface] Robot speaking...")

## Handle send button press - sends audio if available, otherwise sends text
func _on_send_button_pressed() -> void:
	print("[Interface] Send button pressed")
	
	if has_recording and recording != null:
		print("[Interface] Sending recorded audio...")
		_on_send_audio()
		has_recording = false
		return
	
	_send_text_message()

## Handle Enter key press in message input field
func _on_message_input_submitted(_text: String) -> void:
	print("[Interface] Enter pressed")
	_send_text_message()

## Send text message from input field with history
func _send_text_message() -> void:
	if not message_input:
		print("[WARNING] Message input not found")
		return
	
	var text: String = message_input.text.strip_edges()
	
	if text.is_empty():
		print("[INFO] Empty text")
		return
	
	if not websocket_client:
		print("[ERROR] WebSocket not available")
		return
	
	# Display in chat
	_add_message_to_chat("You", text)
	
	# Add to conversation history
	conversation_history.append({
		"role": "user",
		"content": text
	})
	
	# Clear input field
	message_input.text = ""
	
	# Send with full conversation history
	_send_text_command_with_history(text)

## Send text command with full conversation history and selected entity_id
## Omits entity_id field entirely if no object selected (general smart room conversation)
func _send_text_command_with_history(text: String) -> void:
	if not websocket_client:
		return
	
	# Prepare message data
	var message_data = {
		"text": text,
		"history": conversation_history
	}
	
	# Only include entity_id if a specific object is selected
	if last_valid_entity != "":
		message_data["entity_id"] = last_valid_entity
		print("[Interface] Sending command with entity: %s" % last_valid_entity)
	else:
		print("[Interface] Sending command without entity (general smart room conversation)")
	
	print("[Interface] History: %d messages" % conversation_history.size())
	
	# Send message with or without entity_id
	var success = websocket_client.send_message("text_command", message_data)
	
	if success:
		print("[Interface] Text sent with history")
	else:
		print("[ERROR] Failed to send text")

## Send recorded audio to backend for transcription via Whisper
func _on_send_audio() -> void:
	if not websocket_client or recording == null:
		print("[ERROR] Cannot send audio")
		return
	
	# Save recording to temporary WAV file
	var temp_path: String = "user://temp_audio.wav"
	var err: Error = recording.save_to_wav(temp_path)
	if err != OK:
		print("[ERROR] Could not save temporary WAV")
		return
	
	# Read WAV file as binary data
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.READ)
	if file == null:
		print("[ERROR] Could not open temporary file")
		return
	
	var wav_data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	DirAccess.remove_absolute(temp_path)
	
	# Encode to base64 for transmission
	var audio_b64: String = Marshalls.raw_to_base64(wav_data)
	
	# Mark that we're waiting for transcription response
	waiting_for_transcription = true
	
	# Send audio to backend for Whisper processing
	var success = websocket_client.send_message("audio_command", {
		"audio": audio_b64,
		"format": "wav"
	})
	
	if success:
		print("[Interface] Audio sent (%d bytes) - Waiting for transcription..." % wav_data.size())
	else:
		print("[ERROR] Failed to send audio")
		waiting_for_transcription = false

## Handle play button press - toggle audio playback state
func _on_play_button_pressed() -> void:
	if not audio_playback:
		return
	
	if audio_playback.stream_paused or !audio_playback.playing:
		if button_play:
			button_play.texture_normal = ICON_PAUSE
		audio_playback.stream_paused = false
		if !audio_playback.playing:
			audio_playback.play()
		is_audio_playing.emit(true)
	else:
		if button_play:
			button_play.texture_normal = ICON_PLAY
		audio_playback.stream_paused = true
		is_audio_playing.emit(false)

## Handle audio playback completion
func _on_recording_playback_finished() -> void:
	if button_play:
		button_play.texture_normal = ICON_PLAY
	is_audio_playing.emit(false)

## Handle record button press - toggle recording state
func _on_record_button_pressed() -> void:
	if not effect:
		return
	
	if effect.is_recording_active():
		# Stop recording and prepare audio for sending
		recording = effect.get_recording()
		effect.set_recording_active(false)
		has_recording = true
		
		if button_record:
			button_record.texture_normal = ICON_NOT_RECORDING
		if audio_playback:
			audio_playback.stream = recording
		if panel_spectrum:
			panel_spectrum.modulate.a = ALPHA_DISABLED
		if button_play:
			button_play.modulate.a = 1.0
			button_play.disabled = false
		
		print("[Interface] Recording stopped - Press Send")
	else:
		# Start recording
		effect.set_recording_active(true)
		has_recording = false
		
		if button_record:
			button_record.texture_normal = ICON_RECORDING
		if audio_playback:
			audio_playback.stop()
		is_audio_playing.emit(false)
		if panel_spectrum:
			panel_spectrum.modulate.a = 1.0
		if button_play:
			button_play.modulate.a = ALPHA_DISABLED
			button_play.disabled = true
		
		print("[Interface] Recording...")

## Add message to chat display (only user-robot conversation, no system messages)
func _add_message_to_chat(sender: String, content: String) -> void:
	if not messages_list:
		print("[%s]: %s" % [sender, content])
		return
	
	var message_label: Label = Label.new()
	message_label.text = "[%s]: %s" % [sender, content]
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Color coding: blue for user, green for assistant
	if sender == "You":
		message_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	elif sender == "Rob":
		message_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.6))
	
	messages_list.add_child(message_label)
	
	# Auto-scroll to latest message
	if scroll_container:
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

## Clear conversation history (useful for starting fresh conversation)
func clear_history() -> void:
	conversation_history.clear()
	print("[Interface] History cleared")

## Manually reset object selection (clears selected entity_id)
func clear_selected_entity() -> void:
	last_valid_entity = ""
	entity_selection_time = 0.0
	print("[Interface] Object selection cleared")
