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

func _ready() -> void:
	scrollbar.changed.connect(_on_scrollbar_changed)
	input.placeholder_text = default_placeholder_text
	input.grab_focus()

func display_message(char_name: String, msg: String, icon: Texture2D = default_char_icon) -> void:
	var new_msg: Node = message_template.instantiate()
	new_msg.get_node("TextContainer/CharacterMessage").text = msg
	new_msg.get_node("CharacterInfoContainer/CharacterName").text = char_name
	new_msg.get_node("CharacterInfoContainer/CharacterIconContainer/CharacterIcon").texture = icon
	chat_container.add_child(new_msg)

# Usado quando uma msg é enviada, impedindo novas msgs de serem enviadas antes de receber uma resposta
func toggle_input(enabled: bool) -> void:
	input.editable = enabled
	input.placeholder_text = default_placeholder_text if enabled else awaiting_response_placeholder_text

func _on_message_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return

	display_message(player_name, text)
	input.clear()
	toggle_input(false)

func _on_clear_pressed() -> void:
	toggle_input(true)
	for msg in chat_container.get_children():
		msg.queue_free()

func _on_message_received(char_name: String, msg: String, icon: Texture2D = default_char_icon) -> void:
	await get_tree().create_timer(0.001).timeout # Evita erros na ordem dos sinais
	display_message(char_name, msg, icon)
	toggle_input(true)

# Move a barra de rolagem para o final sempre que novas mensagens forem adicionadas
func _on_scrollbar_changed() -> void:
	scroll_container.scroll_vertical = int(scrollbar.max_value)
