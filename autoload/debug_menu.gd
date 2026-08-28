extends CanvasLayer
## Godmode debug overlay for manual testing. Only builds its UI in debug builds; no-ops in exports.

var _panel: PanelContainer
var _toggle_button: Button
var _content: VBoxContainer
var _expanded := false

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	_toggle_button = Button.new()
	_toggle_button.text = "Godmode"
	_toggle_button.position = Vector2(8, 8)
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)

	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 44)
	_panel.visible = false
	add_child(_panel)

	_content = VBoxContainer.new()
	_panel.add_child(_content)

	var add_coins_button := Button.new()
	add_coins_button.text = "+100 Coins"
	add_coins_button.pressed.connect(_on_add_coins_pressed)
	_content.add_child(add_coins_button)

func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	_panel.visible = _expanded

func _on_add_coins_pressed() -> void:
	GameState.add_currency(100)
