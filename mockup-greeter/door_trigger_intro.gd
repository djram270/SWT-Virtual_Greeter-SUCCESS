extends Area3D

@export var robot_path: NodePath
@export var intro_anchor_path: NodePath

@onready var robot: Node3D = get_node(robot_path)
@onready var intro_anchor: Node3D = get_node(intro_anchor_path)

var triggered: bool = false

func _ready() -> void:
	if not robot:
		push_error("DoorTrigger: robot_path is not set")
	if not intro_anchor:
		push_error("DoorTrigger: intro_anchor_path is not set")

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if triggered:
		return
	if not body.is_in_group("player"):
		return

	triggered = true
	print("[DOOR] Player entered — robot moving to intro anchor")

	if robot.has_method("set_target"):
		robot.set_target(intro_anchor)
