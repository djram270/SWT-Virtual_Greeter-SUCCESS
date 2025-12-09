extends CanvasLayer

class_name LoadingOverlay

var pending := {} # Dictionary
var _root: Control
var _label: Label

func _ready() -> void:
	_root = Control.new()
	_root.name = "LoadingOverlayRoot"
	_root.anchor_left = 0
	_root.anchor_top = 0
	_root.anchor_right = 1
	_root.anchor_bottom = 1
	_root.visible = false
	add_child(_root)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	_root.add_child(bg)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.anchor_left = 0
	_label.anchor_top = 0
	_label.anchor_right = 1
	_label.anchor_bottom = 1
	_label.text = ""
	_label.add_theme_font_size_override("font_size", 24)
	_root.add_child(_label)

func add_pending(entity_id: String) -> void:
	if entity_id == "":
		return
	if not pending.has(entity_id):
		pending[entity_id] = true
	_update_visibility()

func remove_pending(entity_id: String) -> void:
	if pending.has(entity_id):
		pending.erase(entity_id)
	_update_visibility()

func clear_all() -> void:
	pending.clear()
	_update_visibility()

func _update_visibility() -> void:
	var count = pending.size()
	_root.visible = count > 0
	if count > 0:
		_label.text = "Connecting devices... (" + str(count) + ")"
	else:
		_label.text = ""
