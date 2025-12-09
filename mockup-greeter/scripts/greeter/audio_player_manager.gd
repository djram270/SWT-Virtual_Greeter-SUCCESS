# res://scripts/greeter/audio_player_manager.gd
## Audio Player Manager
##
## Plays MP3 audio received from backend
## Handles MP3 validation and stream configuration
## Manages audio playback state and control

extends Node
class_name AudioPlayerManager

## AudioStreamPlayer instance for playback
var audio_stream_player: AudioStreamPlayer = null

## Initialize audio player on scene ready
func _ready() -> void:
	# Create AudioStreamPlayer
	audio_stream_player = AudioStreamPlayer.new()
	add_child(audio_stream_player)
	
	print("Audio player ready")

## Play MP3 audio from byte array data
## Validates MP3 format before playback
## @param audio_data: PackedByteArray containing MP3 audio data
func play_mp3_from_bytes(audio_data: PackedByteArray) -> void:
	if audio_data.size() == 0:
		push_warning("Empty audio data, cannot play")
		return
	
	# Validate minimum MP3 size (at least 100 bytes)
	if audio_data.size() < 100:
		push_error("Audio data too small (" + str(audio_data.size()) + " bytes), probably invalid")
		return
	
	# Check if it is actually MP3 data (MP3 starts with 0xFF 0xFB or ID3)
	var is_mp3 := false
	if audio_data.size() >= 3:
		# Check for MP3 sync word (0xFF 0xFB, 0xFF 0xFA, 0xFF 0xF3, 0xFF 0xF2)
		if audio_data[0] == 0xFF and (audio_data[1] & 0xE0) == 0xE0:
			is_mp3 = true
		# Check for ID3 tag
		elif audio_data[0] == 0x49 and audio_data[1] == 0x44 and audio_data[2] == 0x33:
			is_mp3 = true
	
	if not is_mp3:
		push_error("Data does not look like valid MP3")
		push_error("   First bytes: [%02X %02X %02X]" % [audio_data[0], audio_data[1], audio_data[2]])
		return
	
	print("Received audio: ", audio_data.size(), " bytes")
	
	# Create MP3 stream
	var audio_stream := AudioStreamMP3.new()
	audio_stream.data = audio_data
	
	# Validate the stream was created successfully
	if not audio_stream or audio_stream.data.size() == 0:
		push_error("Failed to create AudioStreamMP3")
		return
	
	# Configure and play
	audio_stream_player.stream = audio_stream
	
	# Try to play
	audio_stream_player.play()
	
	if audio_stream_player.playing:
		print("Playing backend response")
	else:
		push_error("Failed to start playback")

## Stop audio playback
func stop() -> void:
	if audio_stream_player:
		audio_stream_player.stop()

## Check if audio is currently playing
## @return True if audio playback is active
func is_playing() -> bool:
	return audio_stream_player != null and audio_stream_player.playing
