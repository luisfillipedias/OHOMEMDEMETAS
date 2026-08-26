extends CanvasLayer

# ============================================================
# HUD CONTROLLER – Fears to Fathom Style
# ============================================================

@onready var timecard_label = $Timecard/TimecardLabel
@onready var timecard_container = $Timecard
@onready var objective_panel = $ObjectivePanel
@onready var objective_label = find_child("ObjectiveLabel", true, false)
@onready var interact_hint = $InteractHint
@onready var consequence_panel = $ConsequencePopup
@onready var consequence_label = $ConsequencePopup/ConsequenceLabel
@onready var item_indicator = $ItemIndicator
@onready var item_label = $ItemIndicator/ItemLabel
@onready var fade_rect = $FadeRect
@onready var fade_label = $FadeRect/FadeLabel
@onready var flash_rect = $FlashRect
@onready var progress_bar = $ProgressBarContainer/ProgressBar
@onready var progress_container = $ProgressBarContainer

var _pickup_popup: CanvasLayer = null

func _ready() -> void:
	interact_hint.hide()
	consequence_panel.hide()
	progress_container.hide()
	fade_rect.color = Color(0, 0, 0, 1)
	flash_rect.color = Color(1, 1, 1, 0)
	
	GameState.consequence_triggered.connect(show_consequence)
	GameState.item_changed.connect(_on_item_changed)
	
	# Conectar ao Inventario para mostrar popup ao pegar item
	var inv = get_node_or_null("/root/Inventario")
	if inv and inv.has_signal("item_adicionado"):
		inv.item_adicionado.connect(_on_item_adicionado)
	
	_fade_in()

# Timecard que aparece no início e some após alguns segundos
func show_timecard(location_text: String, time_text: String) -> void:
	timecard_label.text = location_text + "
" + time_text
	timecard_container.modulate.a = 0.0
	timecard_container.show()
	
	var tw = create_tween()
	tw.tween_property(timecard_container, "modulate:a", 1.0, 0.8)
	tw.tween_interval(5.0)
	tw.tween_property(timecard_container, "modulate:a", 0.0, 1.2)
	await tw.finished
	timecard_container.hide()

func set_objective(text: String) -> void:
	var formatted: String = text.to_upper().strip_edges()
	if not formatted.begins_with("OBJETIVO:"):
		formatted = "OBJETIVO:
" + formatted
	objective_label.text = formatted
	objective_panel.modulate.a = 0.0
	objective_panel.show()
	var tw = create_tween()
	tw.tween_property(objective_panel, "modulate:a", 1.0, 0.8)

func hide_objective() -> void:
	objective_panel.hide()

func show_interact_prompt(text: String = "INTERAGIR") -> void:
	interact_hint.text = "E - " + text.to_upper()
	interact_hint.show()

func hide_interact_prompt() -> void:
	interact_hint.hide()

func show_consequence(text: String = "Ele vai se lembrar disso...") -> void:
	consequence_label.text = "[" + text + "]"
	consequence_panel.modulate.a = 0.0
	consequence_panel.show()
	
	var tw = create_tween()
	tw.tween_property(consequence_panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(consequence_panel, "modulate:a", 0.0, 0.8)
	await tw.finished
	consequence_panel.hide()

func start_hold_progress(duration: float) -> void:
	progress_container.show()
	progress_bar.value = 0.0
	var tw = create_tween()
	tw.tween_property(progress_bar, "value", 100.0, duration)
	await tw.finished
	progress_container.hide()

func cancel_hold_progress() -> void:
	progress_container.hide()
	progress_bar.value = 0.0

func _on_item_changed(new_item: String) -> void:
	if new_item != "":
		item_label.text = "ITEM: " + new_item.to_upper()
		item_indicator.show()
	else:
		item_indicator.hide()

func _on_item_adicionado(dados: Dictionary) -> void:
	if not is_instance_valid(_pickup_popup):
		var popup_scene: PackedScene = load("res://scenes/ui/item_pickup_popup.tscn")
		if popup_scene:
			_pickup_popup = popup_scene.instantiate()
			get_tree().root.add_child(_pickup_popup)
	if is_instance_valid(_pickup_popup) and _pickup_popup.has_method("mostrar"):
		_pickup_popup.mostrar(dados)

func flash_screen(color: Color = Color(1, 1, 1, 1), duration: float = 0.3) -> void:
	flash_rect.color = color
	var tw = create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, duration)

func _fade_in(duration: float = 1.5) -> void:
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, duration)
	await tw.finished
	fade_label.text = ""

func fade_out(msg: String = "", duration: float = 1.2) -> void:
	fade_label.text = msg
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, duration)
	await tw.finished
