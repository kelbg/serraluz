extends Node

@export var char_icon: Texture2D

signal message_received(char_name: String, msg: String)

var messages: Array
var current_endpoint: Dictionary

func _ready() -> void:
	$HTTPRequest.request_completed.connect(_on_request_completed)
	current_endpoint = setup_endpoint("OpenAI")
	load_system_prompt("character.txt")

func load_system_prompt(file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	messages.append({"role": "system", "content": file.get_as_text()})

func setup_endpoint(service: String) -> Dictionary:
	var new_endpoint: Dictionary = JSON.parse_string(FileAccess.open("endpoints.json", FileAccess.READ).get_as_text())[service]
	new_endpoint["headers"] += [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % get_api_key(service)
	]
	
	return new_endpoint

func get_api_key(service: String) -> String:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("environment.cfg")
	return cfg.get_value("", "%s_API_KEY" % service)

func send_request(role: String, content: String, model: String) -> void:
	messages.append({"role": role, "content": content})
	current_endpoint["params"]["model"] = model
	current_endpoint["params"]["messages"] = messages
	
	$HTTPRequest.request(
		current_endpoint["url"],
		current_endpoint["headers"],
		HTTPClient.METHOD_POST,
		str(current_endpoint["params"])
	)

func _on_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var json: Dictionary = JSON.parse_string(body.get_string_from_utf8())
	print("\n%s" % json)
	emit_signal("message_received", "ChatGPT", json["choices"][0]["message"]["content"], char_icon)

func _on_message_submitted(message: String) -> void:
	send_request("user", message, "gpt-4o-mini")


func _on_clear_pressed() -> void:
	messages.clear()
	load_system_prompt("character.txt")
