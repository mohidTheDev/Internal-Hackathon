extends Node2D

@export_custom(PROPERTY_HINT_FILE, "*.tscn") var startLevel: String
@export_custom(PROPERTY_HINT_FILE, "*.tscn") var levelSelectScreen: String
@export_custom(PROPERTY_HINT_FILE, "*.tscn") var infoScene: String

@onready var playButton: Button = $Play
@onready var levelSelect: Button = $"Level Select"
@onready var infoButton: Button = $Info

func playButtonDown() -> void:
	if startLevel:
		Global.fadeToNextLevel(self, startLevel)

func levelSelectButtonDown() -> void:
	if levelSelectScreen:
		Global.fadeToNextLevel(self, levelSelectScreen)

func infoButtonDown() -> void:
	if infoScene:
		Global.fadeToNextLevel(self, infoScene)
