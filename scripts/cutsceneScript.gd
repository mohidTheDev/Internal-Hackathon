extends Node2D

@export_custom(PROPERTY_HINT_FILE, "*.tscn") var nextScenePath: String
@export var imageFadeTime: float = 0.5
@export var keyAppearDelay: float = 1
@export var keyFadeTime: float = 0.5
@export_multiline var frameCaptions: Array[String]
var cutsceneFrame: int = 0
var cutsceneImage: Sprite2D
var key: Sprite2D
var captionLabel: Label

# time for which the image has been loaded
var currentImageTime: float = 0

var keyAppeared: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	cutsceneImage = $"Cutscene Image"
	key = $Keys
	captionLabel = $"Caption Label"
	captionLabel.text = frameCaptions[0]
	key.modulate.a = 0

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("e") and not is_transitioning:
		is_transitioning = true
		cutsceneFrame += 1
		if cutsceneFrame > 3:
			Global.fadeToNextLevel(self, nextScenePath)
			
			# Prevent multiple triggers while the screen is fading
			set_process(false) 
			return
			
		# fade in black screen (for image transitions)
		var fadeInTween = create_tween()
		fadeInTween.tween_property(Global.blackScreen,
		"modulate", Color(0.0, 0.0, 0.0, 1.0),
		imageFadeTime)
		
		# Make sure blackScreen is visible during middle transitions
		Global.blackScreen.visible = true 
		await fadeInTween.finished
		
		# Change image path of cutsceneImage depending on current value of cutsceneFrame
		cutsceneImage.texture = load("res://images/cutscene" 
		+ str(cutsceneFrame)+ ".png")
		
		# Change the captions
		captionLabel.text = frameCaptions[cutsceneFrame]
		
		# hide the key sprite
		key.modulate = Color(1.0, 1.0, 1.0, 0.0)
		
		# fade out black screen
		var fadeOutTween = create_tween()
		fadeOutTween.tween_property(Global.blackScreen,
		"modulate", Color(0.0, 0.0, 0.0, 0.0),
		imageFadeTime)
		
		# Hide the black screen after the tween so it doesn't block clicks
		fadeOutTween.tween_callback(func(): Global.blackScreen.visible = false)
		
		currentImageTime = 0
		keyAppeared = false
		
		await fadeOutTween.finished
		is_transitioning = false

	if keyAppeared:
		return

	# keep track of how long it has been and start fading in the key sprite accordingly
	currentImageTime += delta
	if currentImageTime >= keyAppearDelay:
		var keyFadeTween = create_tween()
		keyFadeTween.tween_property(key,
		"modulate", Color(1.0, 1.0, 1.0, 1.0), keyFadeTime)
		keyAppeared = true
