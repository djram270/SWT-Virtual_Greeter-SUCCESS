extends CharacterBody3D

@export var move_speed: float = 6.0
@export var look_speed: float = 0.002
@export var gravity: float = 9.8

@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_forward: String = "ui_up"
@export var input_back: String = "ui_down"

var mouse_captured: bool = false
var look_rotation: Vector2
var velocity_y: float = 0.0

@onready var head: Node3D = $Head
@onready var ray := $Head/Camera3D/ClickRay
@onready var name_label := $"../CrossHair/NameLabel"
@onready var robot: Node3D = $"../GreeterRobot"


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x


func _unhandled_input(event: InputEvent) -> void:
	# ESC -> release mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
		return

	# Left click -> recapture mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true
			return

	# Mouse look
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)

	# Object click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click()


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	if not is_on_floor():
		velocity_y -= gravity * delta
	else:
		velocity_y = 0.0

	velocity.y = velocity_y

	move_and_slide()

	update_name_label()


func handle_click():
	ray.force_raycast_update()

	if ray.is_colliding():
		var obj = ray.get_collider()
		if obj and obj.has_method("is_interactable") and obj.is_interactable():
			print("[PLAYER] Sending robot to:", obj.name)
			robot.set_target(obj)


func update_name_label():
	ray.force_raycast_update()

	if ray.is_colliding():
		var obj = ray.get_collider()
		name_label.text = "HIT: " + obj.name
	else:
		name_label.text = ""


func rotate_look(rot_input: Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed

	transform.basis = Basis()
	rotate_y(look_rotation.y)

	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)
