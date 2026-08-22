extends Button

@export_custom(PROPERTY_HINT_FILE, "*.tscn") var levelScene: String
@export var levelIndex: String

func _ready() -> void:
	get_node("Label").text = levelIndex

func buttonDown() -> void:
	Global.fadeToNextLevel(get_tree().current_scene, levelScene)
