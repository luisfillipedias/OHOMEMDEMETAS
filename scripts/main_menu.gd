extends Control

@onready var btn_jogar    = $VBox/BtnJogar
@onready var btn_continuar = $VBox/BtnContinuar
@onready var btn_opcoes   = $VBox/BtnOpcoes
@onready var btn_creditos = $VBox/BtnCreditos
@onready var btn_sair     = $VBox/BtnSair
@onready var logo         = $Logo

# Painel de opcoes
@onready var painel_opcoes    = $PainelOpcoes
@onready var slider_brilho    = $PainelOpcoes/VBox/HBoxBrilho/SliderBrilho
@onready var label_brilho_val = $PainelOpcoes/VBox/HBoxBrilho/LabelValor
@onready var btn_fechar_opcoes = $PainelOpcoes/VBox/BtnFechar

func _ready() -> void:
	btn_jogar.pressed.connect(_jogar)
	btn_continuar.pressed.connect(_continuar)
	btn_opcoes.pressed.connect(_abrir_opcoes)
	btn_sair.pressed.connect(get_tree().quit)
	btn_fechar_opcoes.pressed.connect(_fechar_opcoes)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Animacao de pulse no logo
	var tw = create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.2)
	tw.tween_property(logo, "scale", Vector2(1.0, 1.0), 1.2)

	# Inicializa slider com valor salvo
	painel_opcoes.hide()
	slider_brilho.min_value = 0.5
	slider_brilho.max_value = 2.0
	slider_brilho.step = 0.05
	slider_brilho.value = GameManager.brightness
	_atualizar_label_brilho(GameManager.brightness)
	slider_brilho.value_changed.connect(_on_brilho_changed)

func _jogar() -> void:
	GameManager.change_scene("res://scenes/chapter_01.tscn")

func _continuar() -> void:
	if GameManager.get_flag("chapter_1_completed"):
		GameManager.change_scene("res://scenes/chapter_01.tscn")

func _abrir_opcoes() -> void:
	painel_opcoes.show()

func _fechar_opcoes() -> void:
	painel_opcoes.hide()
	GameManager.save_settings()

func _on_brilho_changed(valor: float) -> void:
	GameManager.brightness = valor
	_atualizar_label_brilho(valor)

func _atualizar_label_brilho(valor: float) -> void:
	var pct := int(round((valor - 0.5) / 1.5 * 100.0))
	label_brilho_val.text = str(pct) + "%"
