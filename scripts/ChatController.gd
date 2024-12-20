extends Node

@export var player: Character
@export var characters: Array[Character]
@export var chars_per_second: int
@export var default_placeholder_text: String
@export var awaiting_response_placeholder_text: String
@export_multiline var intro_message: String
@export_multiline var link_template: String
@export_multiline var prev_interactions_instructions: String

@export var message_template: PackedScene
@export var system_message_template: PackedScene
@export var chat_container: VBoxContainer
@export var input: LineEdit
@export var scroll_container: ScrollContainer
@export var audio_player: AudioStreamPlayer
@export var response_length_display: Label
@export var token_count_display: Label
@export var background_image: TextureRect
@export var char_info_box: CanvasItem

@onready var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()

# Mensagens armazenadas no formato usado pela API
var messages: Array
# Node do chat que irá receber a mensagem via text streaming da API
var text_stream_chat_msg: Node
# Personagem com o qual o jogador está interagindo
var current_character: Character

signal player_message_submitted(msg: String, to: Character)
signal typing_started
signal typing_char_added
signal typing_finished

func _ready() -> void:
	scrollbar.changed.connect(_on_scrollbar_changed)
	audio_player.finished.connect(_on_audio_player_finished)
	input.text_submitted.connect(_on_input_text_submitted)
	
	input.placeholder_text = default_placeholder_text
	input.grab_focus()
	toggle_input(false, "Selecione uma ação acima")
	var intro_msg := load_intro_message()
	add_chat_actions(intro_msg, [
		{
		"type": "chat",
		"target": "Lirian \"Chama Branda\"",
		"text": "【 IR ATÉ A TAVERNA 】"
		},
		{
		"type": "chat",
		"target": "Graldor Pedratorvo",
		"text": "【 IR ATÉ A FORJA 】"
		},
	])

# Retorna uma msg no formato que é usado pela maioria das APIs
func new_message(role: String, msg: String) -> Dictionary:
	return {"role": role, "content": msg}

func add_chat_message(from: Character, msg: String) -> Node:
	var role := get_role(from)
	messages.append(new_message(role, msg))

	var new_msg: Node
	if role == "system":
		new_msg = system_message_template.instantiate()
	else:
		new_msg = message_template.instantiate()
		var name_control := new_msg.get_node("VBoxContainer/CharacterName")
		var char_icon_control := new_msg.get_node("VBoxContainer/HBoxContainer/CharacterIcon")
		name_control.text = "%s (%s)" % [from.name.to_upper(), from.role]
		name_control.add_theme_color_override("font_color", from.name_color)
		char_icon_control.texture = from.icon

	new_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").text = msg
	chat_container.add_child(new_msg)
	format_char_thoughts(new_msg)
	return new_msg

# Define o papel com base no personagem
func get_role(character: Character) -> String:
	if character == player:
		return "user"
	if characters.has(character):
		return "assistant"
	return "system"

# Habilitar impede que o jogador envie novas msgs antes de receber uma resposta
func toggle_input(enabled: bool, placeholder_text: String = "") -> void:
	input.editable = enabled

	if placeholder_text != "":
		input.placeholder_text = placeholder_text
		return

	input.placeholder_text = default_placeholder_text if enabled else awaiting_response_placeholder_text

# Anima o texto, exibindo um caractere de cada vez
func animate_text(chat_msg: Node) -> void:
	toggle_input(false)
	typing_started.emit()

	var text_field: RichTextLabel = chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage")
	while text_field.visible_characters < text_field.text.length():
		text_field.visible_characters += 1
		typing_char_added.emit()
		await get_tree().create_timer(1.0 / chars_per_second).timeout

	typing_finished.emit()


# Formata o texto entre asteriscos (*) para destacar o pensamento do personagem
func format_char_thoughts(chat_msg: Node, color: String = "dark_gray") -> void:
	var regex := RegEx.new()
	# Regex para encontrar pares de asteriscos (*) e o texto entre eles
	regex.compile(r"\*(.*?)\*")
	
	var input_string: String = chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").text
	var matches := regex.search_all(input_string)
	if not matches:
		return
	
	# Constrói a string de resultado iterando pelos matches
	var result_string := ""
	var last_pos := 0
	
	for match in matches:
		# Acrescenta o texto antes do match
		result_string += input_string.substr(last_pos, match.get_start(0) - last_pos)
		
		var matched_text := match.get_string(1)
		result_string += "[color=%s][i]%s[/i][/color]" % [color, matched_text]
		
		# Atualiza a posição para depois do match
		last_pos = match.get_end(0)
	
	# Acrescenta o texto restante
	result_string += input_string.substr(last_pos)
	chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").text = result_string


func update_response_length_display() -> void:
	if text_stream_chat_msg == null:
		response_length_display.text = "-/-"
		return

	var chat_msg := text_stream_chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage")
	var visible_chars: int = chat_msg.visible_characters
	var total_chars: int = chat_msg.text.length()

	response_length_display.text = "%s/%s" % [visible_chars, total_chars]

func update_token_count_display() -> void:
	var approx_token_count := 0
	for msg: Dictionary in messages:
		approx_token_count += msg.content.length() / 4

	token_count_display.text = "Tokens: ~%s" % approx_token_count

func start_new_chat(character: Character) -> void:
	clear_chat()
	set_background_image(character.background)
	load_system_prompt(character)
	load_info_box(character)
	current_character = character

	toggle_input(true)
	print("Novo chat iniciado com '%s'. Carregando prompt." % character.name)

func clear_chat() -> void:
	toggle_input(true)
	for msg in chat_container.get_children():
		msg.queue_free()

	messages.clear()
	text_stream_chat_msg = null
	update_response_length_display()

func load_system_prompt(character: Character) -> void:
	messages.append(new_message("system", character.get_prompt()))

	if character.previous_interactions.size() > 0:
		messages.append(new_message(
			"system",
			prev_interactions_instructions +
			"\n\n".join(character.previous_interactions)
		))

func load_intro_message() -> Node:
	var msg := add_chat_message(null, intro_message)
	return msg

# Adiciona links que o jogador pode clicar para executar uma ação no chat
func add_chat_actions(chat_msg_container: Node, actions: Array) -> void:
	var msg := chat_msg_container.get_node("VBoxContainer/HBoxContainer/CharacterMessage")

	if !msg.is_connected("meta_clicked", _on_meta_clicked):
		msg.connect("meta_clicked", _on_meta_clicked)

	var urls := []
	for action: Dictionary in actions:
		urls.append("[url=%s]%s[/url]" % [action, action.text])

	var new_action := link_template.replace("{{action}}", "\t\t".join(urls))
	msg.text += "\n\n" + new_action

func get_char_by_name(char_name: String) -> Character:
	for character in characters:
		if character.name == char_name:
			return character
	return null

func set_background_image(image: Texture2D) -> void:
	background_image.texture = image

func load_info_box(character: Character) -> void:
	var portrait := char_info_box.get_node("PortraitContainer/Portrait")
	var description := char_info_box.get_node("CharDescriptionContainer/CharDescription")

	if character == null:
		portrait.texture = null
		description.text = ""
		char_info_box.visible = false
		return
		
	char_info_box.visible = true
	var new_text := "[color=gold]%s[/color] - %s\n\n%s" % [character.name.to_upper(), character.role, character.description]

	portrait.texture = character.icon
	description.text = new_text

func _on_audio_player_finished() -> void:
	# Altera levemente o pitch do som para criar um efeito mais dinâmico
	audio_player.pitch_scale = randf_range(0.9, 1.0)

	audio_player.play()
	await typing_char_added

# Valida a entrada do jogador, adiciona a mensagem no chat e sinaliza o evento
func _on_input_text_submitted(text: String) -> void:
	if text.strip_edges() == "":
		return

	add_chat_message(player, text)
	toggle_input(false)
	input.clear()
	player_message_submitted.emit(messages)

func _on_clear_pressed() -> void:
	if current_character == null:
		return

	start_new_chat(current_character)

func _on_send_pressed() -> void:
	_on_input_text_submitted(input.text)

# Move a barra de rolagem para o final sempre que novas mensagens forem adicionadas
func _on_scrollbar_changed() -> void:
	scroll_container.scroll_vertical = int(scrollbar.max_value)

func _on_request_sent() -> void:
	# Texto inicialmente vazio pois a msg ainda será transmitida aos poucos via text streaming
	text_stream_chat_msg = add_chat_message(current_character, "")
	text_stream_chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").visible_characters = 0
	toggle_input(false)

func _on_text_stream_started() -> void:
	# Aguarda até que seja transmitido texto suficiente para não finalizar a animação antes da hora
	await get_tree().create_timer(0.2).timeout
	animate_text(text_stream_chat_msg)
	update_token_count_display()

func _on_text_stream_data_received(chunk: String) -> void:
	text_stream_chat_msg.get_node("VBoxContainer/HBoxContainer/CharacterMessage").text += chunk
	messages[-1]["content"] += chunk

func _on_text_stream_finished(_full_response: String) -> void:
	update_token_count_display()

func _on_typing_started() -> void:
	audio_player.play()

func _on_typing_char_added() -> void:
	update_response_length_display()

func _on_typing_finished() -> void:
	toggle_input(true)
	format_char_thoughts(text_stream_chat_msg)
	await audio_player.finished
	audio_player.stop()

# Acionado quando o jogador clicar em algum link no chat
func _on_meta_clicked(meta: String) -> void:
	var action: Dictionary = JSON.parse_string(meta)
	if action.type == "chat":
		var character := get_char_by_name(action.target)
		if character != null:
			start_new_chat(character)
		else:
			print("Personagem '%s' não encontrado." % action.target)


# Acionado quando o botão de resetar o chat for pressionado
func _on_reset_button_pressed() -> void:
	get_tree().reload_current_scene()
