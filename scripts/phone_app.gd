extends CanvasLayer

# ============================================================
# SMARTPHONE INTERFACE — Fears to Fathom Style
# Celular realista com WhatsApp, contatos reais e mensagem do Stalker
# ============================================================

signal phone_closed
signal stalker_message_read

@onready var phone_panel = $PhoneContainer
@onready var contacts_list = $PhoneContainer/PhoneBody/ContactsList
@onready var chat_view = $PhoneContainer/PhoneBody/ChatView
@onready var chat_title = $PhoneContainer/PhoneBody/ChatView/Header/ChatContactName
@onready var messages_container = $PhoneContainer/PhoneBody/ChatView/Scroll/MessagesVBox
@onready var back_btn = $PhoneContainer/PhoneBody/ChatView/Header/BackBtn
@onready var close_btn = $PhoneContainer/PhoneBody/TopBar/ClosePhoneBtn
@onready var notification_banner = $NotificationBanner
@onready var notif_text = $NotificationBanner/NotifText
@onready var time_label = $PhoneContainer/PhoneBody/TopBar/TimeLabel

var current_contact_id: String = ""
var stalker_sms_arrived: bool = false

# Dados dos contatos reais da Alice
var contacts_data = {
	"mae": {
		"name": "Mãe ❤️",
		"preview": "Filha, a orquestra da polícia...",
		"messages": [
			{"from_me": false, "text": "Oi meu amor! Chegou bem no CEFET?"},
			{"from_me": true, "text": "Cheguei sim mãe! Tô na fila do auditório agora."},
			{"from_me": false, "text": "Que bom! Seu pai tá super orgulhoso. Ele falou que mês que vem na orquestra da PM ele vai tocar trompete em homenagem à sua matrícula! kkkk"},
			{"from_me": true, "text": "Kkkkk meu Deus, avisa ele pra não passar vergonha"},
			{"from_me": false, "text": "Ele manda um beijo! Cuidado com essa chuva, vem direto pra casa depois."}
		]
	},
	"pai": {
		"name": "Pai 👮",
		"preview": "Fica esperta com gente estranha",
		"messages": [
			{"from_me": false, "text": "Alice, tá tudo certo aí no CEFET?"},
			{"from_me": true, "text": "Tudo certo pai, só fila grande."},
			{"from_me": false, "text": "Ótimo. Não fica moscando com o celular na rua na saída não. Olho vivo em volta sempre, BH tá perigosa."},
			{"from_me": true, "text": "Pode deixar pai, tô esperta!"}
		]
	},
	"miguel": {
		"name": "Miguel (Uberaba) ✨",
		"preview": "Vou pegar um busão pra ir aí te ver",
		"messages": [
			{"from_me": false, "text": "E aí caloura do CEFET!! Preparada pro primeiro dia?"},
			{"from_me": true, "text": "Mano tô nervosa kkkk muita gente"},
			{"from_me": false, "text": "Kkkkk se você quiser eu pego um cometa aqui de Uberaba agora só pra ir segurar sua mão no primeiro dia 😂"},
			{"from_me": true, "text": "Cê é doido miguel kkkk 8 horas de viagem"},
			{"from_me": false, "text": "Vale a pena ué haha. Boa sorte na matrícula, você vai mandar super bem!"}
		]
	},
	"serena": {
		"name": "Serena 🍄🧚",
		"preview": "As vacas com nome dão mais leite!!",
		"messages": [
			{"from_me": false, "text": "ALICEEEE sabia que se você der um nome carinhoso pra uma vaca ela produz 20% mais leite? É a energia do amor"},
			{"from_me": true, "text": "Serena do céu de onde você tirou isso kkkk"},
			{"from_me": false, "text": "Li num artigo sobre fungos e micélios mágicos! Boa matrícula miga, que as fadas te protejam da chuva!"}
		]
	},
	"bob": {
		"name": "Bob 🚌",
		"preview": "[Foto] Terminei o ônibus 1502 de LEGO!",
		"messages": [
			{"from_me": false, "text": "Alice olha isso aqui que eu passei a noite montando: o 1502 Vista Alegre / Caetano Furquim inteirinho de LEGO!"},
			{"from_me": true, "text": "Mano ficou idêntico até com os adesivos da BHTrans kkkk você não existe"},
			{"from_me": false, "text": "Arte pura parça. Depois te mostro pessoalmente!"}
		]
	},
	"eu": {
		"name": "Eu (Anotações)",
		"preview": "[Encaminhado] Como socializar em escola nova",
		"messages": [
			{"from_me": true, "text": "Lembrar de comprar caderno quadriculado e caneta preta"},
			{"from_me": true, "text": "[Link Encaminhado] 10 dicas de psicologia para fazer amigos sem parecer esquisita no 1º dia"}
		]
	},
	"stalker": {
		"name": "+55 (31) 98744-XXXX",
		"preview": "Te vejo na Sala 305.",
		"messages": [
			{"from_me": false, "text": "Parabéns pela matrícula no CEFET hoje, Alice..."},
			{"from_me": false, "text": "Você fica bonita de jaqueta preta. Chuva boa em BH né?"},
			{"from_me": false, "text": "Te vejo na Sala 305. 😊"}
		]
	}
}

func _ready() -> void:
	phone_panel.hide()
	notification_banner.hide()
	chat_view.hide()
	back_btn.pressed.connect(_on_back_pressed)
	close_btn.pressed.connect(close_phone)

func open_phone() -> void:
	phone_panel.show()
	contacts_list.show()
	chat_view.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_contacts_list()

func close_phone() -> void:
	phone_panel.hide()
	notification_banner.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	phone_closed.emit()

func _build_contacts_list() -> void:
	for child in contacts_list.get_node("Scroll/VBox").get_children():
		child.queue_free()

	for contact_id in contacts_data.keys():
		# Não mostrar o stalker na lista até a notificação chegar
		if contact_id == "stalker" and not stalker_sms_arrived:
			continue

		var contact = contacts_data[contact_id]
		var btn = Button.new()
		btn.text = contact["name"] + "\n" + contact["preview"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 13)

		var cid = contact_id
		btn.pressed.connect(func(): _open_chat(cid))
		contacts_list.get_node("Scroll/VBox").add_child(btn)

func _open_chat(contact_id: String) -> void:
	current_contact_id = contact_id
	var contact = contacts_data[contact_id]
	chat_title.text = contact["name"]
	contacts_list.hide()
	chat_view.show()

	for child in messages_container.get_children():
		child.queue_free()

	for msg in contact["messages"]:
		var label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(240, 0)
		if msg["from_me"]:
			label.text = "Eu: " + msg["text"]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7, 1))
		else:
			label.text = msg["text"]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
		messages_container.add_child(label)

	if contact_id == "stalker":
		stalker_message_read.emit()

func _on_back_pressed() -> void:
	chat_view.hide()
	contacts_list.show()
	_build_contacts_list()

func trigger_stalker_sms() -> void:
	stalker_sms_arrived = true
	notif_text.text = "💬 Nova Mensagem de Número Desconhecido:\n'Parabéns pela matrícula no CEFET hoje, Alice...'"
	notification_banner.show()

	var tw = create_tween()
	tw.tween_property(notification_banner, "position:y", 20.0, 0.4)

	# Clicar na notificação abre o chat do stalker direto
	var notif_btn = notification_banner.get_node_or_null("NotifBtn")
	if notif_btn:
		notif_btn.pressed.connect(func():
			notification_banner.hide()
			_open_chat("stalker")
		)
