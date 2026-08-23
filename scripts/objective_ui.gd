extends CanvasLayer

# ============================================================
# OBJECTIVE UI — Homem De Metas
# Exibe o objetivo atual no canto superior esquerdo (estilo FtF)
# ============================================================

@onready var objective_label: Label = $ObjectivePanel/ObjectiveText
@onready var objective_panel: Panel = $ObjectivePanel

func _ready() -> void:
	hide_objective()

func set_objective(text: String) -> void:
	objective_label.text = "OBJETIVO: " + text
	objective_panel.show()
	show()

	# Efeito sutil de piscar no novo objetivo
	var tw = create_tween()
	tw.tween_property(objective_label, "modulate", Color(1, 0.4, 0.3, 1), 0.2)
	tw.tween_property(objective_label, "modulate", Color(0.95, 0.9, 0.8, 1), 0.3)

func hide_objective() -> void:
	objective_panel.hide()
	hide()
