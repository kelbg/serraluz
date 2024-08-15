class_name BaseCharacter

@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export_multiline var instructions: String

func _init(name: String, description: String, instructions: String, icon: Texture2D = null) -> void:
	self.name = name
	self.description = description
	self.instructions = instructions

	if icon == null:
		self.icon = load("res://icon.svg") as Texture2D
	else:
		self.icon = icon
		
