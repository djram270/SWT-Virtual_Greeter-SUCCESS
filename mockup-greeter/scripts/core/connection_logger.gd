# res://scripts/core/connection_logger.gd
## Connection Logger System
##
## Provides real-time logging interface with status bar and expandable log panel
## Compact status display at bottom of screen with detailed log viewer
## Press F1 to toggle log visibility

extends CanvasLayer

## Log severity levels enumeration
enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	SUCCESS
}

## Maximum number of log entries to retain in memory
@export var max_log_entries: int = 50
## Automatically scroll to latest log entry
@export var auto_scroll: bool = true
## Display timestamp for each log entry
@export var show_timestamps: bool = true
## Write logs to external file
@export var log_to_file: bool = true

## Status bar panel component reference
var status_bar: Panel = null
## Log panel component reference
var log_panel: Panel = null
## Container for log entry items
var log_container: VBoxContainer = null
## Scrollable container for log entries
var scroll_container: ScrollContainer = null
## Connection status display label
var connection_status_label: RichTextLabel = null
## Network statistics display label
var stats_label: Label = null

## Current visibility state of log panel
var log_panel_visible: bool = false

## Array of log entry dictionaries containing all logged messages
var log_entries: Array[Dictionary] = []
## Current connection state string
var connection_state: String = "disconnected"
## Network statistics tracking dictionary
var network_stats: Dictionary = {
	"messages_sent": 0,
	"messages_received": 0,
	"errors": 0
}

## Color mapping for each log severity level
const LOG_COLORS = {
	LogLevel.DEBUG: Color(0.7, 0.7, 0.7),
	LogLevel.INFO: Color(0.3, 0.7, 1.0),
	LogLevel.WARNING: Color(1.0, 0.8, 0.0),
	LogLevel.ERROR: Color(1.0, 0.3, 0.3),
	LogLevel.SUCCESS: Color(0.3, 1.0, 0.3)
}

## Initialize logger system on scene ready
func _ready() -> void:
	setup_ui()
	log_info("ConnectionLogger", "System initialized. Press F1 to toggle logs")

## Create and configure all UI components for logger display
func setup_ui() -> void:
	# Status bar (always visible at bottom of screen)
	status_bar = Panel.new()
	status_bar.anchor_top = 1.0
	status_bar.anchor_bottom = 1.0
	status_bar.anchor_left = 0.0
	status_bar.anchor_right = 1.0
	status_bar.offset_top = -35
	status_bar.offset_bottom = 0
	add_child(status_bar)
	
	var status_margin = MarginContainer.new()
	status_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_margin.add_theme_constant_override("margin_left", 10)
	status_margin.add_theme_constant_override("margin_right", 10)
	status_margin.add_theme_constant_override("margin_top", 5)
	status_margin.add_theme_constant_override("margin_bottom", 5)
	status_bar.add_child(status_margin)
	
	var status_hbox = HBoxContainer.new()
	status_margin.add_child(status_hbox)
	
	# Connection status label
	connection_status_label = RichTextLabel.new()
	connection_status_label.bbcode_enabled = true
	connection_status_label.fit_content = true
	connection_status_label.scroll_active = false
	connection_status_label.custom_minimum_size = Vector2(150, 25)
	connection_status_label.add_theme_font_size_override("normal_font_size", 11)
	status_hbox.add_child(connection_status_label)
	
	# Spacer between status and stats
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	status_hbox.add_child(spacer)
	
	# Network statistics label
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hbox.add_child(stats_label)
	
	# Log panel (collapsible detailed view)
	log_panel = Panel.new()
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.anchor_left = 0.0
	log_panel.anchor_right = 1.0
	log_panel.offset_top = -250
	log_panel.offset_bottom = -35
	log_panel.visible = false
	add_child(log_panel)
	
	var log_margin = MarginContainer.new()
	log_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_margin.add_theme_constant_override("margin_left", 10)
	log_margin.add_theme_constant_override("margin_right", 10)
	log_margin.add_theme_constant_override("margin_top", 10)
	log_margin.add_theme_constant_override("margin_bottom", 10)
	log_panel.add_child(log_margin)
	
	var vbox = VBoxContainer.new()
	log_margin.add_child(vbox)
	
	# Log panel title
	var title_label = Label.new()
	title_label.text = "Connection Logs (Press F1 to hide)"
	title_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title_label)
	
	# Separator line
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Scroll container for logs
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)
	
	# Log container for entries
	log_container = VBoxContainer.new()
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(log_container)
	
	update_status_display()

## Log a message with timestamp and severity level
## @param source: Origin of the log message
## @param message: Log message content
## @param level: Severity level of the message
func log_message(source: String, message: String, level: LogLevel = LogLevel.INFO) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	var entry = {
		"timestamp": timestamp,
		"source": source,
		"message": message,
		"level": level
	}
	
	log_entries.append(entry)
	
	# Maintain maximum log entries limit
	if log_entries.size() > max_log_entries:
		log_entries.pop_front()
		if log_container and log_container.get_child_count() > 0:
			log_container.get_child(0).queue_free()
	
	# Add entry to UI display
	add_log_entry_to_ui(entry)
	
	# Write to file if enabled
	if log_to_file:
		write_to_log_file(entry)
	
	# Print to console
	var level_str = LogLevel.keys()[level]
	print("[%s] [%s] %s: %s" % [timestamp, level_str, source, message])

## Add formatted log entry to UI display
## @param entry: Log entry dictionary to display
func add_log_entry_to_ui(entry: Dictionary) -> void:
	if not log_container:
		return
	
	var label = Label.new()
	var timestamp_str = entry.timestamp.split("T")[1] if show_timestamps else ""
	var level_str = LogLevel.keys()[entry.level]
	var text = "[%s] [%s] %s: %s" % [timestamp_str, level_str, entry.source, entry.message]
	
	label.text = text
	label.add_theme_color_override("font_color", LOG_COLORS[entry.level])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	log_container.add_child(label)
	
	# Auto scroll to latest entry
	if auto_scroll and scroll_container:
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

## Log debug level message
## @param source: Source component name
## @param message: Log message text
func log_debug(source: String, message: String) -> void:
	log_message(source, message, LogLevel.DEBUG)

## Log info level message
## @param source: Source component name
## @param message: Log message text
func log_info(source: String, message: String) -> void:
	log_message(source, message, LogLevel.INFO)

## Log warning level message
## @param source: Source component name
## @param message: Log message text
func log_warning(source: String, message: String) -> void:
	log_message(source, message, LogLevel.WARNING)

## Log error level message
## @param source: Source component name
## @param message: Log message text
func log_error(source: String, message: String) -> void:
	log_message(source, message, LogLevel.ERROR)
	network_stats.errors += 1
	update_stats_display()

## Log success level message
## @param source: Source component name
## @param message: Log message text
func log_success(source: String, message: String) -> void:
	log_message(source, message, LogLevel.SUCCESS)

## Update connection state and log state change
## @param connection_type: Type of connection (websocket)
## @param state: New state (connected, disconnected, connecting, error)
func update_connection_state(connection_type: String, state: String) -> void:
	# Only process websocket state changes
	if connection_type != "websocket":
		return
	
	# Avoid logging duplicate state changes
	if connection_state == state:
		return
	
	var _old_state = connection_state
	connection_state = state
	
	var message = "Connection %s" % state
	var level = LogLevel.SUCCESS if state == "connected" else LogLevel.WARNING
	
	log_message("WebSocket", message, level)
	update_status_display()

## Increment message counter for sent or received messages
## @param message_type: Type of message ("sent" or "received")
func increment_message_count(message_type: String) -> void:
	if message_type == "sent":
		network_stats.messages_sent += 1
	elif message_type == "received":
		network_stats.messages_received += 1
	update_stats_display()

## Update connection status display in status bar
func update_status_display() -> void:
	if not connection_status_label:
		return
	
	var color_code = "[color=green]" if connection_state == "connected" else "[color=red]"
	var status_text = "WebSocket: %s%s[/color]" % [color_code, connection_state.capitalize()]
	
	connection_status_label.text = status_text
	update_stats_display()

## Update network statistics display in status bar
func update_stats_display() -> void:
	if not stats_label:
		return
	
	stats_label.text = "Sent: %d | Received: %d | Errors: %d" % [
		network_stats.messages_sent,
		network_stats.messages_received,
		network_stats.errors
	]

## Write log entry to file
## @param entry: Log entry dictionary to write
func write_to_log_file(entry: Dictionary) -> void:
	var log_file_path = "user://connection_log.txt"
	var file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	
	if file:
		file.seek_end()
		var level_str = LogLevel.keys()[entry.level]
		var line = "[%s] [%s] %s: %s\n" % [
			entry.timestamp,
			level_str,
			entry.source,
			entry.message
		]
		file.store_string(line)
		file.close()

## Clear all log entries from display and memory
func clear_logs() -> void:
	log_entries.clear()
	if log_container:
		for child in log_container.get_children():
			child.queue_free()
	log_info("ConnectionLogger", "Logs cleared")

## Toggle visibility of log panel
func toggle_log_panel() -> void:
	log_panel_visible = not log_panel_visible
	if log_panel:
		log_panel.visible = log_panel_visible

## Handle input events for controlling logger
## @param event: Input event to process
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F1:
			toggle_log_panel()
