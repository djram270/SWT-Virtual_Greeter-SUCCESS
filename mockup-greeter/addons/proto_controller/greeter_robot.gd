# res://scripts/player/greeter_robot.gd
# Robot that moves to a selected object, faces the player,
# shows a speech bubble, and triggers TTS.

extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var greeter: VirtualGreeter = $VirtualGreeter
@onready var ui_manager: Node = get_tree().root.get_node("Main/InteractionManager")
@onready var tts: TTSManager = get_tree().root.find_child("TTSManager", true, false)

enum State { WANDERING, INTERACTING, IDLE, MOVING_TO_OBJECT }
var current_state: State = State.IDLE

var move_speed: float = 1.5
var rotation_speed: float = 5.0
var interact_distance: float = 3.5

var player: Node3D = null
var target_node: Node3D = null
var last_interaction_time: float = 0.0


func _ready() -> void:
	print("Greeter Robot initialized")

	player = get_tree().root.find_child("ProtoController", true, false)

	if greeter:
		greeter.interaction_started.connect(_on_interaction_started)
		greeter.interaction_ended.connect(_on_interaction_ended)

	navigation_agent_3d.velocity_computed.connect(_on_velocity_computed)

	change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	match current_state:
		State.MOVING_TO_OBJECT:
			process_move_to_object(delta)
		State.INTERACTING:
			process_interacting(delta)
		State.IDLE:
			process_idle(delta)

	move_and_slide()


# ---------------------------------------------------------
# MOVEMENT TOWARD TARGET
# ---------------------------------------------------------
func process_move_to_object(delta: float) -> void:
	if not target_node:
		change_state(State.IDLE)
		return

	var dist := global_position.distance_to(target_node.global_position)

	# When close enough → interact
	if dist <= interact_distance:
		_face_player()

		# --- Show bubble and TTS ---
		if ui_manager:
			ui_manager.show_interaction(target_node, self)

			var desc: String = ""
			if "description" in target_node:
				desc = str(target_node.description)

			if tts and not desc.is_empty():
				tts.speak(desc)
		else:
			push_error("[ROBOT] ui_manager is NULL")

		# Stop movement
		navigation_agent_3d.target_position = global_position
		velocity = Vector3.ZERO

		target_node = null
		change_state(State.INTERACTING)
		return

	# If not close yet, follow the navmesh path
	if navigation_agent_3d.is_navigation_finished():
		velocity = Vector3.ZERO
		change_state(State.IDLE)
		return

	var next_pos := navigation_agent_3d.get_next_path_position()
	var direction := (next_pos - global_position).normalized()

	if direction.length() > 0.01:
		var target_rot := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)

	velocity = direction * move_speed


# ---------------------------------------------------------
# INTERACTION STATE
# ---------------------------------------------------------
func process_interacting(_delta: float) -> void:
	velocity = Vector3.ZERO


func process_idle(_delta: float) -> void:
	velocity = Vector3.ZERO

	if player:
		var dist := global_position.distance_to(player.global_position)
		if dist <= 10.0:
			_look_at_target_flat(player.global_position)


# ---------------------------------------------------------
# STATE SWITCHING
# ---------------------------------------------------------
func change_state(new_state: State) -> void:
	if current_state != new_state:
		print("State change: ", State.keys()[current_state], " → ", State.keys()[new_state])
	current_state = new_state


# ---------------------------------------------------------
# LOOK / ROTATION HELPERS
# ---------------------------------------------------------
func _look_at_target_flat(target: Vector3) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = atan2(dir.x, dir.z)


func _face_player() -> void:
	if not player:
		return
	_look_at_target_flat(player.global_position)


# ---------------------------------------------------------
# PLAYER COMMANDS
# ---------------------------------------------------------
func set_target(obj: Node3D) -> void:
	target_node = obj
	navigation_agent_3d.target_position = obj.global_position
	change_state(State.MOVING_TO_OBJECT)


func move_to_player() -> void:
	if not player:
		return
	var dist := 2.5
	var target_pos := player.global_position - (player.global_transform.basis.z * dist)
	navigation_agent_3d.target_position = target_pos
	change_state(State.MOVING_TO_OBJECT)


# ---------------------------------------------------------
# SIGNAL HANDLERS
# ---------------------------------------------------------
func _on_interaction_started() -> void:
	last_interaction_time = Time.get_ticks_msec() / 1000.0
	change_state(State.INTERACTING)


func _on_interaction_ended() -> void:
	last_interaction_time = Time.get_ticks_msec() / 1000.0


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity
