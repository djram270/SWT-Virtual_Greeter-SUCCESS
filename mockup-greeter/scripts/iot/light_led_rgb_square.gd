# res://scripts/iot/light_led_rgb_square.gd
"""
Light rgb square Display Controller
- Handles only visual representation (no control logic)
- Real device control is managed by VirtualGreeter through WebSocket
"""
extends Node3D
# --- Configuration ---
@export var entity_id: String = "light.led_rgb_square"
@export var object_node_path: NodePath = "OmniLight3D"
@export var mesh_node_path: NodePath = "MeshInstance3D"

# --- State ---
var current_state: String = "unknown"
var object_node: Light3D = null
var mesh_node: MeshInstance3D = null
var emissive_material: StandardMaterial3D = null
var friendly_name: String = entity_id

# --- Lifecycle ---
func _ready() -> void:
	# Initialize references and WebSocket listeners
	setup_nodes()
	connect_signals()

# --- Node Setup ---
func setup_nodes() -> void:
	"""Locate and configure light and mesh nodes"""
	if has_node(object_node_path):
		object_node = get_node(object_node_path)
	
	if has_node(mesh_node_path):
		mesh_node = get_node(mesh_node_path)
		setup_emissive_material()

func setup_emissive_material() -> void:
	"""Create and assign emissive material for light glow effect"""
	if not mesh_node:
		return
	
	emissive_material = StandardMaterial3D.new()
	emissive_material.emission_enabled = true
	emissive_material.emission = Color(1.0, 0.9, 0.7)
	emissive_material.emission_energy_multiplier = 0.0
	mesh_node.set_surface_override_material(0, emissive_material)

# --- WebSocket Setup ---
func connect_signals() -> void:
	"""Subscribe to WebSocket events for state updates"""
	if not WebsocketClient:
		return
			
	WebsocketClient.message_received.connect(_on_websocket_message)
	
	if WebsocketClient.connection_state == WebSocketPeer.STATE_OPEN:
		request_device_state()
	else:
		WebsocketClient.connected.connect(_on_websocket_connected)

func _on_websocket_connected() -> void:
	"""Triggered once the WebSocket is connected"""
	await get_tree().create_timer(0.5).timeout
	request_device_state()

func request_device_state() -> void:
	"""Request current device state from backend"""
	if not WebsocketClient:
		return
	
	WebsocketClient.send_message("get_device_state", {
		"entity_id": entity_id
	})

# --- WebSocket Message Handling ---
func _on_websocket_message(message_type: String, data: Dictionary) -> void:
	# Save the friendly name
	if data.has("attributes") and data["attributes"].has("friendly_name") and data.get("entity_id") == entity_id:
		var name_value: Variant = data["attributes"]["friendly_name"]
		friendly_name = str(name_value).strip_edges()
			
	"""Handle incoming messages that update object visual state"""
	if message_type == "device_state" and data.get("entity_id") == entity_id:
		update_state(data.get("state", "unknown"))
		
	elif message_type == "iot_state_changed" and data.get("entity_id") == entity_id:
		update_state(data.get("new_state", "unknown"))

func update_state(new_state: String) -> void:
	"""Apply visual change when device state updates (CONFIRMATION from server)"""
	if current_state == new_state:
		return
	
	current_state = new_state
	var is_on = (new_state == "on")
	
	if object_node:
		object_node.visible = is_on
	
	if emissive_material:
		var target_emission = 2.0 if is_on else 0.0
		emissive_material.emission_energy_multiplier = target_emission
		
	
	# **Confirmation log on the terminal**
	ConnectionLogger.log_success(friendly_name, "State CONFIRMED from backend: " + new_state)

# --- Public API ---
func get_entity_id() -> String:
	"""Return Home Assistant entity ID"""
	return entity_id

func get_device_name() -> String:
	"""Return user-friendly device name"""
	return friendly_name

func get_current_state() -> String:
	"""Return current stored state"""
	return current_state

# -------------------------------------------------------------------------
# Manual Toggle
# -------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	"""Detect manual toggle key (O)"""
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_0:
		ConnectionLogger.log_info(friendly_name, "Changing state")
		toggle_light()

func toggle_light() -> void:
	"""Send toggle command and apply visual change ONLY upon server confirmation"""
	if not WebsocketClient:
		return
	
	# Determine the status to request
	var new_state = "off" if current_state == "on" else "on"
	# Send the control command
	var sent = WebsocketClient.send_iot_command(entity_id, new_state)
	
	if sent:
		ConnectionLogger.log_info(friendly_name, "Comando de toggle ENVIADO: " + new_state + ". Esperando confirmación del backend...")
	else:
		ConnectionLogger.log_error(friendly_name, "Fallo al ENVIAR el comando de toggle. Mensaje en cola.")


#descrption label 
@export var description := "This is a programmable RGB lighting system that enhances the room’s atmosphere. You can turn off and turn on this lamp with key [0]."

func is_interactable() -> bool:
	return true
