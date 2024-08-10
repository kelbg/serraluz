extends Node

@export var message_template: PackedScene
@export var default_placeholder_text: String
@export var awaiting_response_placeholder_text: String
@export var player_name: String
@export var default_char_icon: Texture2D
@export var chat_container: VBoxContainer
@export var input: LineEdit
@export var scroll_container: ScrollContainer

@onready var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()

# Referência ao node do chat que irá receber a mensagem via text streaming da API
var text_stream_chat_msg: Node

signal typing_started
signal typing_char_added
signal typing_finished

func _ready() -> void:
	scrollbar.changed.connect(_on_scrollbar_changed)
	input.placeholder_text = default_placeholder_text
	input.grab_focus()

func add_chat_message(char_name: String, msg: String, icon: Texture2D = default_char_icon) -> Node:
	var new_msg: Node = message_template.instantiate()
	# TODO: NodePath?
	new_msg.get_node("TextContainer/CharacterMessage").text = msg
	new_msg.get_node("CharacterInfoContainer/CharacterName").text = char_name
	new_msg.get_node("CharacterInfoContainer/CharacterIconContainer/CharacterIcon").texture = icon
	chat_container.add_child(new_msg)
	return new_msg

# Usado quando uma msg é enviada, impedindo novas msgs de serem enviadas antes de receber uma resposta
func toggle_input(enabled: bool) -> void:
	input.editable = enabled
	input.placeholder_text = default_placeholder_text if enabled else awaiting_response_placeholder_text

# Anima o texto, inserindo um caracter de cada vez
func animate_text(chat_msg: Node) -> void:
	toggle_input(false)
	emit_signal("typing_started")

	var text_field: RichTextLabel = chat_msg.get_node("TextContainer/CharacterMessage")
	while text_field.visible_characters < text_field.text.length():
		text_field.visible_characters += 1
		emit_signal("typing_char_added")
		await get_tree().create_timer(0.025).timeout
	

	emit_signal("typing_finished")

func _on_message_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return

	add_chat_message(player_name, text)
	input.clear()
	toggle_input(false)

func _on_clear_pressed() -> void:
	toggle_input(true)
	for msg in chat_container.get_children():
		msg.queue_free()

func _on_message_received(char_name: String, msg: String, icon: Texture2D = default_char_icon) -> void:
	await get_tree().process_frame # Evita erros na ordem dos sinais
	add_chat_message(char_name, msg, icon)
	toggle_input(true)

# TODO: Planner - Char scene
func _on_request_sent(char_name: String, icon: Texture2D = default_char_icon) -> void:
	await get_tree().process_frame # Evita que a resposta seja exibida antes da msg do jogador
	text_stream_chat_msg = add_chat_message(char_name, "", icon)
	text_stream_chat_msg.get_node("TextContainer/CharacterMessage").visible_characters = 0
	toggle_input(false)

func _on_text_stream_started() -> void:
	# Aguardar até que seja transmitida uma quantidade suficiente de texto para ser exibido
	await get_tree().create_timer(0.2).timeout
	animate_text(text_stream_chat_msg)

func _on_text_stream_received(msg: String) -> void:
	await get_tree().create_timer(0.1).timeout
	text_stream_chat_msg.get_node("TextContainer/CharacterMessage").text += msg

func _on_text_stream_finished() -> void:
	pass

func _on_typing_finished() -> void:
	text_stream_chat_msg = null
	toggle_input(true)	

# Move a barra de rolagem para o final sempre que novas mensagens forem adicionadas
func _on_scrollbar_changed() -> void:
	scroll_container.scroll_vertical = int(scrollbar.max_value)
