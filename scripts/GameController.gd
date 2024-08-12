extends Node

@export var char_icon: Texture2D

signal message_received(char_name: String, msg: String)
signal request_sent(char_name: String)
signal text_stream_received(msg: String)
signal text_stream_started()
signal text_stream_finished()

var messages: Array
var endpoint: Dictionary
var client: HTTPClient

func _ready() -> void:
	endpoint = setup_endpoint("OpenAI")
	client = await setup_client()
	# load_system_prompt("character.txt")

func setup_client() -> HTTPClient:
	var new_client := HTTPClient.new()
	var error_code := new_client.connect_to_host(endpoint["base_url"])

	assert(error_code == OK)
	print("Conectando-se a '%s'..." % endpoint["base_url"])

	while (new_client.get_status() == HTTPClient.STATUS_CONNECTING
	or new_client.get_status() == HTTPClient.STATUS_RESOLVING):
		new_client.poll()
		await get_tree().process_frame

	assert(new_client.get_status() == HTTPClient.STATUS_CONNECTED)
	print("Conectado")

	return new_client

func load_system_prompt(file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	messages.append({"role": "system", "content": file.get_as_text()})

func setup_endpoint(service: String) -> Dictionary:
	print("Configurando endpoint para '%s'..." % service)
	var new_endpoint: Dictionary = JSON.parse_string(FileAccess.open("config/endpoints.json", FileAccess.READ).get_as_text())[service]
	new_endpoint["headers"] += [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % get_api_key(service)
	]

	print("Endpoint configurado")
	return new_endpoint

func get_api_key(service: String) -> String:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("config/environment.cfg")
	return cfg.get_value("", "%s_API_KEY" % service)

func send_request_stream(role: String, content: String, model: String) -> void:
	messages.append({"role": role, "content": content})
	endpoint["params"]["messages"] = messages
	endpoint["params"]["model"] = model
	endpoint["params"]["stream"] = true

	var approx_token_count := str(messages).length() / 4.0
	print("Enviando requisição. Contexto (~%d tokens):\n%s" % [approx_token_count, "\n".join(messages)])

	var error_code := client.request(
		HTTPClient.METHOD_POST,
		endpoint["chat_endpoint"],
		endpoint["headers"],
		str(endpoint["params"])
	)

	assert(error_code == OK)
	print("Requisição enviada. Aguardando resposta...")
	request_sent.emit("ChatGPT")
	handle_server_response()

func handle_server_response() -> void:
	while (client.get_status() == HTTPClient.STATUS_REQUESTING):
		client.poll()
		await get_tree().process_frame

	assert(client.get_status() == HTTPClient.STATUS_BODY
		or client.get_status() == HTTPClient.STATUS_CONNECTED)

	if !client.has_response():
		print("Não foi possível obter uma resposta.")
		return

	print("Resposta recebida. Aguardando dados...")
	stream_server_response()

func stream_server_response() -> void:
	var read_buffer := PackedByteArray()
	var has_started := false
	var content := ""

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			await get_tree().process_frame
			continue

		if !has_started:
			has_started = true
			text_stream_started.emit()
			print("Iniciando streaming de dados...")

		read_buffer += chunk
		var chunk_text := chunk.get_string_from_utf8()
		content += parse_chunk(chunk_text)
		text_stream_received.emit(parse_chunk(chunk_text))
		# print(chunk_text) #


	messages.append({"role": "assistant", "content": content})
	print("Mensagem recebida:\n%s" % messages[-1])
	print("Bytes recebidos: ", read_buffer.size())
	text_stream_finished.emit()

# Extrai o conteúdo de um chunk, que pode ter mais de um conjunto de dados (separados por \n)
func parse_chunk(chunk_text: String) -> String:
	var output := ""
	var lines := chunk_text.split("\n")
	for line in lines:
		if !line.begins_with("data: "):
			continue

		line = line.replace("data: ", "")
		if line == "[DONE]":
			break

		var json: Dictionary = JSON.parse_string(line)
		if !json["choices"][0]["delta"].has("content"):
			continue

		output += json["choices"][0]["delta"]["content"]


	return output

func _on_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var json: Dictionary = JSON.parse_string(body.get_string_from_utf8())
	print("\n%s" % json)
	emit_signal("message_received", "ChatGPT", json["choices"][0]["message"]["content"], char_icon)

func _on_message_submitted(message: String) -> void:
	send_request_stream("user", message, "gpt-4o-mini")
	pass


func _on_clear_pressed() -> void:
	messages.clear()
	# load_system_prompt("character.txt")
