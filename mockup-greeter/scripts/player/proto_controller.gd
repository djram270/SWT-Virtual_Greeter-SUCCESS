# res://scripts/proto_controller.gd
## ProtoController v1.0 - Simplified Movement & Interaction System
##
## Features:
## - Movement: Arrow keys
## - Look: Mouse (click to capture)
## - Interactions: E key (configurable via ControllerConfig)
## - Global Interaction: G key (robot approach)
## - Escape to release mouse

extends CharacterBody3D

## Movement configuration
@export var base_speed: float = 7.0
@export var look_speed: float = 0.002

## Input actions
@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_forward: String = "ui_up"
@export var input_back: String = "ui_down"

var mouse_captured: bool = false
var look_rotation: Vector2
var controller_config: ControllerConfig = null

## Component references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

## Reference to greeter robot
var greeter_robot: Node = null

## Initialize controller
func _ready() -> void:
	# Load interaction config
	controller_config = ControllerConfig.new()
	
	# Find greeter robot
	greeter_robot = get_tree().root.find_child("GreeterRobot", true, false)
	if not greeter_robot:
		push_warning("GreeterRobot not found in scene")
	
	print("ProtoController initialized")
	print("Enabled interactions: ", controller_config.get_enabled_interactions())
	
	# Check input mappings
	_check_input_mappings()
	
	# Initialize look rotation
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

## Handle input (mouse capture and interactions)
func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Look around with mouse
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
	
	# Check interactions
	if controller_config:
		for interaction in controller_config.get_enabled_interactions():
			if Input.is_action_just_pressed(controller_config.get_interaction_input(interaction)):
				_handle_interaction(interaction)

## Physics processing - movement and gravity
func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Apply movement
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if move_dir:
		velocity.x = move_dir.x * base_speed
		velocity.z = move_dir.z * base_speed
	else:
		velocity.x = move_toward(velocity.x, 0, base_speed)
		velocity.z = move_toward(velocity.z, 0, base_speed)
	
	# Apply movement
	move_and_slide()

## Rotate view based on mouse movement
func rotate_look(rot_input: Vector2) -> void:
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

## Handle interaction based on type
## @param interaction: Interaction enum value
func _handle_interaction(interaction: int) -> void:
	match interaction:
		controller_config.Interactions.INTERACT:
			_perform_interact()
		controller_config.Interactions.INTERACT_GLOBAL:
			_perform_global_interaction()

## Perform interact raycast for object interaction
func _perform_interact() -> void:
	if not camera:
		push_error("Camera not found")
		return
	
	var config = controller_config.get_interaction_config(controller_config.Interactions.INTERACT)
	var distance = config.get("distance", 5.0)
	
	var space_state = get_world_3d().direct_space_state
	var viewport_center = get_viewport().get_visible_rect().size / 2
	
	var origin = camera.project_ray_origin(viewport_center)
	var end = origin + camera.project_ray_normal(viewport_center) * distance
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider_obj = result.get("collider")
		if collider_obj and collider_obj.has_method("on_interact"):
			print("Interacting with: %s" % collider_obj.name)
			collider_obj.on_interact()
		else:
			print("Object has no interaction: %s" % (collider_obj.name if collider_obj else "none"))
	else:
		print("No object in crosshair")

## Perform global interaction with robot
func _perform_global_interaction() -> void:
	if not greeter_robot:
		push_warning("GreeterRobot not found")
		return
	
	print("Global interaction triggered - Robot approaching player")
	
	# Call move_to_player on the robot if method exists
	if greeter_robot.has_method("move_to_player"):
		greeter_robot.move_to_player()
	else:
		push_warning("GreeterRobot does not have move_to_player method")

## Capture mouse for camera control
func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

## Release mouse
func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

## Check if all required input actions exist
func _check_input_mappings() -> void:
	var actions_to_check = [input_left, input_right, input_forward, input_back]
	
	# Add interaction inputs
	if controller_config:
		for interaction in controller_config.get_enabled_interactions():
			var input_action = controller_config.get_interaction_input(interaction)
			if input_action:
				actions_to_check.append(input_action)
	
	# Check all actions
	for action in actions_to_check:
		if not InputMap.has_action(action):
			push_error("Missing input action: %s" % action)
