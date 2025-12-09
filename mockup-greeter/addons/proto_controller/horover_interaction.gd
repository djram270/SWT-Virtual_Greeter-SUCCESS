extends Node3D

# Reference to the Camera3D this node is attached to
@onready var cam: Camera3D = get_parent() as Camera3D

# Maximum ray distance, input action, and collision mask
@export var max_distance: float = 3.0
@export var interact_action: String = "interact"
@export var collision_mask: int = 0xFFFFFFFF

# UI references (Crosshair CanvasLayer)
@onready var crosshair_label: Label = get_tree().root.get_node("Main/CrossHair/CrossLabel")
@onready var name_label: Label = get_tree().root.get_node("Main/CrossHair/NameLabel")

# Node currently under the crosshair that can be interacted with
var current_target: Node = null


func _ready() -> void:
	# Hide the object name at start
	if name_label:
		name_label.visible = false


func _physics_process(_dt: float) -> void:
	# If camera reference is missing, do nothing
	if not cam:
		return

	# Get viewport center (crosshair position)
	var size := get_viewport().get_visible_rect().size
	var center := size / 2.0

	# Build ray origin and direction based on camera projection
	var from := cam.project_ray_origin(center)
	var to := from + cam.project_ray_normal(center) * max_distance

	# Configure ray parameters
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collision_mask = collision_mask

	# Perform raycast
	var hit: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(params)

	# If nothing was hit → clear current target
	if hit.is_empty():
		_set_target(null)
		return

	# Identify collider and resolve interactable parent
	var collider: Node = hit.get("collider", null)
	_set_target(_find_interactable(collider))


func _input(event: InputEvent) -> void:
	# Reserved for future “press to interact” functionality
	if event.is_action_pressed(interact_action) and current_target:
		if current_target.has_method("on_interact"):
			current_target.on_interact()


func _find_interactable(node: Node) -> Node:
	# Walk upward through parents to find the first interactable candidate
	var n := node
	while n:
		# New interaction model: exported is_interactable() function
		if n.has_method("is_interactable") and n.is_interactable():
			return n

		# Optional: support for group-based interactables
		if n.is_in_group("interactable"):
			return n

		# Compatibility with very old system
		if n.has_method("on_interact"):
			return n

		n = n.get_parent()
	return null


func _set_target(target: Node) -> void:
	# Avoid redundant updates
	if target == current_target:
		return

	current_target = target

	# --- Crosshair visual feedback ---
	if crosshair_label:
		var c := Color(1, 1, 1)  # Default: white
		if current_target:
			c = Color(0, 1, 0)   # Green when aiming at interactable
		crosshair_label.add_theme_color_override("font_color", c)

	# If UI label does not exist → stop
	if not name_label:
		return

	# No target → clear label
	if not current_target:
		name_label.visible = false
		name_label.text = ""
		return

	# Try reading exported “interactable_name”, fallback to node name
	var display_name := _get_property_or_default(
		current_target,
		"interactable_name",
		current_target.name.capitalize()
	)

	name_label.text = str(display_name)
	name_label.visible = true


func _get_property_or_default(obj: Object, property_name: String, default_value) -> Variant:
	# Safely checks exported property existence
	for prop in obj.get_property_list():
		if prop.name == property_name:
			return obj.get(property_name)
	return default_value
