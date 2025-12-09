# Handles the speech bubble that appears when the robot reaches an object
extends Node

# This must be the Control/Panel that contains the entire speech bubble
# (background + text + tail)
@onready var bubble: Control = $"../CanvasLayer/SpeechBubble"
@onready var desc_label: Label = $"../CanvasLayer/SpeechBubble/Description"

var speaker: Node3D = null
var height_offset: float = 1.4   # height above the robot's head

# --- typewriter state ---
var full_text: String = ""
var typing_speed: float = 20.0    # characters per second
var typing_timer: float = 0.0
var typed_chars: int = 0
var auto_hide_delay: float = 4.0  # seconds to wait after finishing typing
var auto_hide_timer: float = 0.0


func _ready() -> void:
	if not bubble:
		push_error("InteractionManager: SpeechBubble not found")
	if not desc_label:
		push_error("InteractionManager: Description Label not found")

	if bubble:
		bubble.visible = false
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if desc_label:
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_process(false)


func show_interaction(obj: Node3D, speaker_node: Node3D = null) -> void:
	if not bubble or not desc_label:
		push_error("InteractionManager: Missing UI elements in show_interaction")
		return

	speaker = speaker_node

	# read object description
	full_text = str(_get_property_or_default(obj, "description", ""))
	typing_timer = 0.0
	typed_chars = 0
	auto_hide_timer = 0.0        # IMPORTANT: reset auto-hide here
	desc_label.text = ""         # start empty

	bubble.visible = true
	set_process(true)


func hide() -> void:
	if bubble:
		bubble.visible = false

	# reset state
	set_process(false)
	speaker = null
	full_text = ""
	typing_timer = 0.0
	typed_chars = 0
	auto_hide_timer = 0.0
	if desc_label:
		desc_label.text = ""


func _process(delta: float) -> void:
	if not bubble or not bubble.visible:
		return
	if speaker == null:
		return

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var viewport_rect := get_viewport().get_visible_rect()

	# --- World position near the robot ---
	var base_pos: Vector3 = speaker.global_position + Vector3(0, height_offset, 0)
	var cam_right: Vector3 = cam.global_transform.basis.x.normalized()
	var world_pos: Vector3 = base_pos + cam_right * 0.9

	var screen_pos: Vector2 = cam.unproject_position(world_pos)
	var offscreen := false

	if cam.is_position_behind(world_pos):
		offscreen = true
	else:
		if screen_pos.x < 0.0 or screen_pos.x > viewport_rect.size.x:
			offscreen = true
		if screen_pos.y < 0.0 or screen_pos.y > viewport_rect.size.y:
			offscreen = true

	var bsize: Vector2 = bubble.size
	if offscreen:
		var margin: float = 24.0
		bubble.position = Vector2(
			viewport_rect.size.x - bsize.x - margin,
			margin
		)
	else:
		bubble.position = screen_pos + Vector2(-bsize.x * 0.5, -bsize.y * 0.5)

	# --- Typewriter + auto-hide ---
	if full_text.is_empty():
		return

	typing_timer += delta
	var target_chars := int(typing_timer * typing_speed)
	typed_chars = clamp(target_chars, 0, full_text.length())
	desc_label.text = full_text.substr(0, typed_chars)

	if typed_chars >= full_text.length():
		auto_hide_timer += delta
		if auto_hide_timer >= auto_hide_delay:
			hide()
	else:
		auto_hide_timer = 0.0

func _get_property_or_default(obj: Object, property_name: String, default_value) -> Variant:
	for prop in obj.get_property_list():
		if prop.name == property_name:
			return obj.get(property_name)
	return default_value
