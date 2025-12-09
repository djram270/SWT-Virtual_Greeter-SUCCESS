# res://scripts/greeter/audio_recorder.gd
## Audio Recorder with Microphone Input Capture
##
## Records microphone input using AudioEffectCapture bus effect
## - Captures real microphone audio
## - Maximum 5-minute recording duration
## - Real-time progress updates
## - Warning system in final 30 seconds
## - 16kHz mono audio for optimal compression
## - Automatic stop at time limit

extends Node
class_name AudioRecorder

# Signals
signal recording_finished(audio_data: PackedByteArray)
signal recording_time_updated(seconds_remaining: float)
signal recording_warning()

# Configuration constants
const MAX_RECORDING_TIME: float = 300.0
const WARNING_THRESHOLD: float = 30.0
const SAMPLE_RATE: int = 16000
const MONO: bool = true
const RECORD_BUS_NAME: String = "Record"

# Instance variables
var recording: AudioStreamWAV = null
var is_recording: bool = false
var recording_timer: float = 0.0
var record_bus_index: int = -1

## Initializes audio recording system
func _ready() -> void:
	print("Audio recorder initialized")
	print("Maximum recording time: %.0f seconds" % MAX_RECORDING_TIME)
	@warning_ignore("integer_division")
	print("Audio configuration: %dkHz %s" % [int(SAMPLE_RATE / 1000), "Mono" if MONO else "Stereo"])
	
	_setup_audio_bus()

## Sets up recording bus with AudioEffectCapture
func _setup_audio_bus() -> void:
	# Get or create recording bus
	record_bus_index = AudioServer.get_bus_index(RECORD_BUS_NAME)
	
	if record_bus_index == -1:
		print("Creating audio bus: %s" % RECORD_BUS_NAME)
		AudioServer.add_bus()
		record_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(record_bus_index, RECORD_BUS_NAME)
	
	# Check if AudioEffectCapture already exists on bus
	var has_capture = false
	for i in range(AudioServer.get_bus_effect_count(record_bus_index)):
		var effect = AudioServer.get_bus_effect(record_bus_index, i)
		if effect is AudioEffectCapture:
			has_capture = true
			break
	
	# Add AudioEffectCapture if not present
	if not has_capture:
		var capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(record_bus_index, capture_effect)
		print("AudioEffectCapture added to bus: %s" % RECORD_BUS_NAME)
	else:
		print("AudioEffectCapture already on bus: %s" % RECORD_BUS_NAME)
	
	print("Microphone recording ready")

## Starts microphone audio recording
func start_recording() -> void:
	if is_recording:
		push_warning("Recording already in progress")
		return
	
	if record_bus_index == -1:
		push_error("Recording bus not initialized")
		return
	
	is_recording = true
	recording_timer = 0.0
	
	# Create WAV stream
	recording = AudioStreamWAV.new()
	recording.mix_rate = SAMPLE_RATE
	recording.stereo = not MONO
	
	# Clear capture buffer
	var capture_effect = _get_capture_effect()
	if capture_effect:
		capture_effect.clear_buffer()
	
	print("Recording started")

## Processes recording with timeout
## @param delta: Time elapsed since previous frame
func _process(delta: float) -> void:
	if not is_recording:
		return
	
	recording_timer += delta
	
	# Emit time update every second
	if fmod(recording_timer, 1.0) < delta:
		var time_remaining = MAX_RECORDING_TIME - recording_timer
		recording_time_updated.emit(time_remaining)
		
		# Warning at 30 seconds
		if time_remaining <= WARNING_THRESHOLD and time_remaining > (WARNING_THRESHOLD - delta):
			print("WARNING: Recording will stop in 30 seconds")
			recording_warning.emit()
	
	# Auto-stop at time limit
	if recording_timer >= MAX_RECORDING_TIME:
		print("Recording time limit reached")
		stop_recording()

## Stops recording and emits audio data
func stop_recording() -> void:
	if not is_recording:
		push_warning("No recording in progress")
		return
	
	is_recording = false
	
	# Get capture effect
	var capture_effect = _get_capture_effect()
	if not capture_effect:
		push_error("AudioEffectCapture not found")
		return
	
	# Get audio frames
	var audio_frames = capture_effect.get_frames_available()
	
	if audio_frames == 0:
		push_error("No audio frames captured")
		return
	
	print("Audio frames captured: %d" % audio_frames)
	
	# Get audio data
	var audio_buffer = capture_effect.get_buffer(audio_frames)
	
	# Convert to WAV
	var audio_data = _convert_to_wav(audio_buffer)
	
	var duration_seconds = recording_timer
	var size_mb = float(audio_data.size()) / 1048576.0
	
	print("Recording stopped")
	print("Duration: %.1f seconds, Size: %.2f MB" % [duration_seconds, size_mb])
	
	if audio_data.size() == 0:
		push_error("Failed to convert audio to WAV")
		return
	
	recording_finished.emit(audio_data)

## Gets the AudioEffectCapture from recording bus
## @return AudioEffectCapture or null if not found
func _get_capture_effect() -> AudioEffectCapture:
	if record_bus_index == -1:
		return null
	
	for i in range(AudioServer.get_bus_effect_count(record_bus_index)):
		var effect = AudioServer.get_bus_effect(record_bus_index, i)
		if effect is AudioEffectCapture:
			return effect as AudioEffectCapture
	
	return null

## Converts AudioFrame array to WAV format
## @param audio_frames: Array of AudioFrames from microphone
## @return PackedByteArray with WAV data
func _convert_to_wav(audio_frames: PackedVector2Array) -> PackedByteArray:
	var wav_data = PackedByteArray()
	var channels = 1 if MONO else 2
	var bits_per_sample = 16
	@warning_ignore("integer_division")
	var byte_rate = SAMPLE_RATE * channels * bits_per_sample / 8
	@warning_ignore("integer_division")
	var block_align = channels * bits_per_sample / 8
	var data_size = audio_frames.size() * block_align
	
	# WAV Header
	wav_data.append_array("RIFF".to_ascii_buffer())
	wav_data.append_array(_int_to_bytes(int(36 + data_size), 4))
	wav_data.append_array("WAVE".to_ascii_buffer())
	
	# fmt chunk
	wav_data.append_array("fmt ".to_ascii_buffer())
	wav_data.append_array(_int_to_bytes(16, 4))
	wav_data.append_array(_int_to_bytes(1, 2))
	wav_data.append_array(_int_to_bytes(channels, 2))
	wav_data.append_array(_int_to_bytes(SAMPLE_RATE, 4))
	wav_data.append_array(_int_to_bytes(byte_rate, 4))
	wav_data.append_array(_int_to_bytes(block_align, 2))
	wav_data.append_array(_int_to_bytes(bits_per_sample, 2))
	
	# data chunk
	wav_data.append_array("data".to_ascii_buffer())
	wav_data.append_array(_int_to_bytes(data_size, 4))
	
	# Audio samples - convert float to 16-bit
	for frame in audio_frames:
		var left = int(clamp(frame.x, -1.0, 1.0) * 32767.0)
		wav_data.append(int(left & 0xFF))
		wav_data.append(int((left >> 8) & 0xFF))
		
		if not MONO:
			var right = int(clamp(frame.y, -1.0, 1.0) * 32767.0)
			wav_data.append(int(right & 0xFF))
			wav_data.append(int((right >> 8) & 0xFF))
	
	return wav_data

## Converts integer to little-endian bytes
## @param value: Integer to convert
## @param num_bytes: Number of bytes
## @return PackedByteArray with bytes
func _int_to_bytes(value: int, num_bytes: int) -> PackedByteArray:
	var result = PackedByteArray()
	for i in range(num_bytes):
		result.append(int((value >> (i * 8)) & 0xFF))
	return result
