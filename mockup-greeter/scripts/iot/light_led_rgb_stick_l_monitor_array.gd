extends Node

@export var entity_id: String = "sensor.temperature_12"

var current_value: String = "unknown"
var friendly_name: String = entity_id

func _ready() -> void:
	# Conectarse al websocket exactamente igual al ejemplo tuyo
	WebsocketClient.message_received.connect(_debug_ws)
	connect_signals()


func connect_signals() -> void:
	if not WebsocketClient:
		push_error("[SensorReader] WebsocketClient NO existe.")
		return
	
	# Escuchar mensajes
	WebsocketClient.message_received.connect(_on_ws_message)
	
	# Si ya está conectado → pedir estado inicial
	if WebsocketClient.connection_state == WebSocketPeer.STATE_OPEN:
		request_state()
	else:
		# Si aún no, esperar a conexión
		WebsocketClient.connected.connect(_on_ws_connected)


func _on_ws_connected() -> void:
	# Esperar un poco por Home Assistant backend
	await get_tree().create_timer(0.5).timeout
	request_state()


func request_state() -> void:
	if not WebsocketClient:
		return
	
	print("\n[SensorReader] Solicitando estado inicial de ", entity_id, "\n")
	WebsocketClient.send_message("get_device_state", {
		"entity_id": entity_id
	})


func _on_ws_message(message_type: String, data: Dictionary) -> void:
	# Filtrar mensajes que no son del sensor especificado
	if data.get("entity_id", "") != entity_id:
		return
	
	# Extraer friendly_name si viene
	if data.has("attributes") and data["attributes"].has("friendly_name"):
		friendly_name = str(data["attributes"]["friendly_name"]).strip_edges()
	
	# -------------------------
	# Recibir estado inicial
	# -------------------------
	if message_type == "device_state":
		update_value(data.get("state", "unknown"))
	
	# -------------------------
	# Cambios reportados por HA
	# -------------------------
	elif message_type == "iot_state_changed":
		update_value(data.get("new_state", "unknown"))


func update_value(new_value: String) -> void:
	if new_value == current_value:
		return  # No imprimir si no cambió
	
	current_value = new_value
	
	print("===============================")
	print("📡 Sensor actualizado:", friendly_name)
	print("🆔 ID:", entity_id)
	print("📊 Nuevo valor:", new_value)
	print("===============================\n")

func _debug_ws(message_type: String, data: Dictionary):
	print("\n\n================================")
	print("📥 MENSAJE COMPLETO DEL WEBSOCKET")
	print("Tipo:", message_type)
	print("Datos (Dictionary):")
	print(data)
	print("Claves:", data.keys())
	
	# Imprimir campos individuales sin confiar en nada
	for key in data.keys():
		print(" -", key, "=", data[key])

	print("================================\n\n")
