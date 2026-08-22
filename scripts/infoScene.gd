extends Node2D

@export_custom(PROPERTY_HINT_FILE, "*.tscn") var mainMenuScene: String

func homeButtonPressed() -> void:
	Global.fadeToNextLevel(self, mainMenuScene)
