class_name Character extends Resource

@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export_multiline var instructions: String

func get_prompt() -> String:
	var output := """
	**NOME DO PERSONAGEM**
	%s

	**DESCRICÃO DO PERSONAGEM**
	%s

	**INSTRUÇÕES**
	%s
	""" % [name, description, instructions]

	return output
