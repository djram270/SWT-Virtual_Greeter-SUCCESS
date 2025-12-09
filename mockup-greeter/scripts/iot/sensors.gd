extends Node

# --- CONFIG ---
@export var target_entity_id: String = "sensor.humidity_11"

# Estado anterior (para detectar cambios)
var last_state := ""


func _ready() -> void:
	if not WebsocketClient:
		push_error("[HumiditySensor] WebsocketClient no está inicializado.")
		return
	
	# Conectar señales del WebSocket
	WebsocketClient.message_received.connect(_on_websocket_message)
	
	# Si ya está conectado → pedir estado inmediatamente
	if WebsocketClient.connection_state == WebSocketPeer.STATE_OPEN:
		request_state()
	else:
		# Si no está conectado, esperar que conecte
		WebsocketClient.connected.connect(_on_websocket_connected)


func _on_websocket_connected() -> void:
	# Esperar un poco para que el backend esté listo
	await get_tree().create_timer(0.4).timeout
	request_state()


func request_state() -> void:
	print("[HumiditySensor] Pidiendo estado inicial de ", target_entity_id)
	WebsocketClient.send_message("get_device_state", {
		"entity_id": target_entity_id
	})


func _on_websocket_message(message_type: String, data: Dictionary) -> void:
	# Ignorar mensajes que no son del sensor objetivo
	if data.get("entity_id", "") != target_entity_id:
		return

	# ----------------------
	# Mensaje de estado normal
	# ----------------------
	if message_type == "device_state":
		var state = data.get("state")
		if state != null:
			update_state(state)

	# ----------------------
	# Mensaje de estado cambiado en HA
	# ----------------------
	elif message_type == "iot_state_changed":
		var new_state = data.get("new_state")
		if new_state != null:
			update_state(new_state)


func update_state(new_state: Variant) -> void:
	if last_state == new_state:
		return  # No imprimir si no cambió

	last_state = new_state

	# ------------------------------
	# ✔ IMPRIMIR EN CONSOLA
	# ------------------------------
	print("\n====================================")
	print("🔥 Estado actualizado de ", target_entity_id)
	print("Nuevo estado → ", new_state)
	print("====================================\n")
