# res://scripts/greeter/virtual_greeter.gd
## Virtual Greeter System with Audio Support
##
## Manages voice interaction pipeline:
## - Audio recording and transmission
## - Text-to-speech synthesis
## - Backend communication via WebSocket
## - Response audio playback

extends Node
class_name VirtualGreeter

# Interaction lifecycle signals
signal interaction_started
signal interaction_ended

# Audio/transcription signals
signal transcription_received(text: String)
signal response_received(response_text: String, audio_data: PackedByteArray)

# Recording progress signals
signal recording_progress(time_remaining: float)
signal recording_warning()

# Component references
var tts_manager: TTSManager = null
var audio_recorder: AudioRecorder = null
var audio_player: AudioPlayerManager = null
var websocket_client: Node = null

# Audio configuration
const MAX_AUDIO_SIZE: int = 10485760  ## 10MB maximum (5+ minutes uncompressed)
const SAMPLE_RATE: int = 16000  ## 16kHz for speech

# System state
var is_listening: bool = false
var has_greeted: bool = false  # NUEVO: Control de saludo único

## Initializes all greeter subsystems and connects to backend
func _ready() -> void:
	setup_components()
	connect_signals()
	
	print("Virtual Greeter system initialized")
	
	# Get WebSocket client from autoload
	websocket_client = get_tree().root.get_node_or_null("WebsocketClient")
	
	if not websocket_client:
		push_error("WebSocketClient not found in scene")
		return
	
	# Wait for connection before completing initialization
	if websocket_client.connection_state != WebSocketPeer.STATE_OPEN:
		print("Waiting for backend connection...")
		await websocket_client.connected
	
	print("Connected to WebSocketClient")
	
	# Connect message signal
	if websocket_client.has_signal("message_received"):
		if not websocket_client.message_received.is_connected(_on_websocket_message):
			websocket_client.message_received.connect(_on_websocket_message)

## NUEVO: Saludo solo la primera vez que se presiona G 
func greet_user() -> void: if not has_greeted and tts_manager: 
	has_greeted = true 
	tts_manager.speak("Hello, I am your Smart Room virtual assistant")

## Creates and configures all required subsystems
func setup_components() -> void:
	# Text-to-Speech Manager - converts text to speech output
	tts_manager = TTSManager.new()
	tts_manager.name = "TTSManager"
	add_child(tts_manager)
	
	# Audio Recording System - captures microphone input
	audio_recorder = AudioRecorder.new()
	audio_recorder.name = "AudioRecorder"
	add_child(audio_recorder)
	
	# Audio Playback Manager - plays response audio
	audio_player = AudioPlayerManager.new()
	audio_player.name = "AudioPlayer"
	add_child(audio_player)

## Establishes signal connections between all components
func connect_signals() -> void:
	# Audio recorder signals
	audio_recorder.recording_finished.connect(_on_recording_finished)
	audio_recorder.recording_time_updated.connect(func(time): recording_progress.emit(time))
	audio_recorder.recording_warning.connect(func(): recording_warning.emit())
	
	# Text-to-speech signals
	tts_manager.speech_started.connect(_on_speech_started)
	tts_manager.speech_finished.connect(_on_speech_finished)

## Initiates audio recording from microphone
func start_listening() -> void:
	if is_listening:
		push_warning("Recording already in progress")
		return
	
	is_listening = true
	interaction_started.emit()
	audio_recorder.start_recording()
	print("Start speaking...")

## Terminates ongoing audio recording
func stop_listening() -> void:
	if not is_listening:
		return
	
	is_listening = false
	audio_recorder.stop_recording()
	print("Recording stopped by user")

## Sends text query to backend for processing
## @param text: User input text command
func send_text_query(text: String) -> void:
	if text.strip_edges().is_empty():
		push_warning("Cannot send empty text query")
		return
	
	if not websocket_client:
		push_error("WebSocket client not available")
		return
	
	print("Sending text query: %s" % text)
	interaction_started.emit()
	websocket_client.send_text_command(text)

## Handles completed audio recording - prepares and transmits to backend
## @param audio_data: Raw WAV audio data from recorder
func _on_recording_finished(audio_data: PackedByteArray) -> void:
	if not websocket_client:
		push_error("WebSocket client not available")
		return
	
	if audio_data.size() == 0:
		push_error("No audio data captured")
		return
	
	var size_mb = float(audio_data.size()) / 1048576
	print("Recording complete: %.2f MB" % size_mb)
	
	# Validate audio size
	if audio_data.size() > MAX_AUDIO_SIZE:
		push_error("Audio exceeds maximum size: %.2f MB > %.2f MB" % [
			size_mb,
			float(MAX_AUDIO_SIZE) / 1048576
		])
		return
	
	# Encode to base64 for transmission
	var audio_base64 = Marshalls.raw_to_base64(audio_data)
	
	print("Sending audio to backend (%d bytes base64)" % audio_base64.length())
	
	# Send to backend
	var success = websocket_client.send_message("audio_command", {
		"audio": audio_base64,
		"format": "wav"
	})
	
	if not success:
		push_error("Failed to send audio to backend")

## Processes incoming WebSocket messages from backend
## Handles transcriptions and responses
## @param message_type: Type of message received
## @param data: Message payload dictionary
func _on_websocket_message(message_type: String, data: Dictionary) -> void:
	if message_type != "text_command":
		return
	
	print("Response received: %s" % message_type)
	print("Data received: %s" % data)
	
	var response_text = ""
	
	# El backend devuelve: {"comment": "...", "suggest": "...", "status": "success", ...}
	if data.has("comment"):
		response_text = data["comment"]
	elif data.has("suggest"):
		response_text = data["suggest"]
	
	#if response_text == "":
		#response_text = "Understood"
		#print("Warning: No comment or suggest found in response")
	
	print("Bot says: %s" % response_text)
	tts_manager.speak(response_text)
	interaction_ended.emit()



## Processes backend response - plays audio or falls back to TTS
## @param response_text: Text response from backend
## @param audio_data: Optional MP3/WAV audio data
func _handle_response(response_text: String, audio_data: PackedByteArray) -> void:
	print("Response: %s" % response_text)
	
	# Prioritize audio playback over text-to-speech
	if audio_data.size() > 0:
		print("Playing audio response")
		audio_player.play_mp3_from_bytes(audio_data)
	else:
		print("Using text-to-speech")
		tts_manager.speak(response_text)

## Signal handler: Text-to-speech output started
func _on_speech_started() -> void:
	print("Speaking...")

## Signal handler: Text-to-speech output completed
## Emits interaction_ended to notify robot of completion
func _on_speech_finished() -> void:
	print("Speech complete")
	interaction_ended.emit()
