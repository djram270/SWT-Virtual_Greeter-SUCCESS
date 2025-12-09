# res://scripts/greeter/tts_manager.gd
## Text-to-Speech Manager
##
## Manages system text-to-speech functionality with voice selection
## and language configuration.

extends Node
class_name TTSManager

# Text-to-speech event signals
signal speech_started
signal speech_finished

var voices: Array = []
var selected_voice_index: int = 0
var current_language: String = "en"

## Initializes TTS system and loads available voices
func _ready() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		push_warning("Text-to-speech not available on this platform")
		return
	
	print("Text-to-speech system initialized")
	load_voices()

## Loads available system voices for current language
func load_voices() -> void:
	voices = DisplayServer.tts_get_voices_for_language(current_language)
	
	if voices.size() == 0:
		print("No voices found for language: %s, using system voices" % current_language)
		voices = DisplayServer.tts_get_voices()
	
	if voices.size() > 0:
		print("Voices loaded: %d for language: %s" % [voices.size(), current_language])
		selected_voice_index = 0
	else:
		push_warning("No text-to-speech voices available on this system")

## Sets the language for text-to-speech output
## @param lang_code: Language code (e.g., "en", "es", "fr")
func set_language(lang_code: String) -> void:
	current_language = lang_code
	load_voices()

## Synthesizes and plays text as speech
## @param text: Text to convert to speech
## @param rate: Speech rate multiplier (default 1.0)
## @param pitch: Speech pitch multiplier (default 1.0)
## @param volume: Volume level in decibels (default 50.0)
func speak(text: String, rate: float = 1.0, pitch: float = 1.0, volume: float = 50.0) -> void:
	if text.is_empty():
		return
	
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		print("Text-to-speech unavailable, text: %s" % text)
		return
	
	speech_started.emit()
	
	var voice_id = ""
	if voices.size() > 0:
		voice_id = voices[selected_voice_index]
	
	DisplayServer.tts_speak(text, voice_id, volume, pitch, rate, 0, true)
	
	# Wait for speech to complete
	var duration = text.length() * 0.05 / rate
	await get_tree().create_timer(duration).timeout
	speech_finished.emit()

## Stops ongoing text-to-speech playback
func stop() -> void:
	DisplayServer.tts_stop()
	speech_finished.emit()
