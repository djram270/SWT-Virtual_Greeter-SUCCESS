extends Node

var target_scene = "res://main.tscn"
var loading_screen = "res://loadingScreen.tscn"

func _ready():
	call_deferred("_go_to_loading")


func _go_to_loading():
	get_tree().change_scene_to_file(loading_screen)


func load_game():
	# Start threaded load
	ResourceLoader.load_threaded_request(target_scene)

	# Wait until load completes
	while ResourceLoader.load_threaded_get_status(target_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	# Optional delay for video
	await get_tree().create_timer(30.0).timeout

	# Retrieve result
	var packed = ResourceLoader.load_threaded_get(target_scene)
	get_tree().change_scene_to_packed(packed)
