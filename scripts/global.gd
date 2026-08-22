extends Node

# Scene references (Replace the strings with your actual file paths)
var clockScene: PackedScene = preload("res://scenes/clockSilhouette.tscn")
var playerSilhouetteScene: PackedScene = preload("res://scenes/playerSilhouette.tscn") # Add your path here

var clockInstance: Node2D
var needleInstance: Node2D
var playerSilhouetteInstance: Node2D

# Restart Animation Speeds & Settings
var fadeDuration: float = 0.5          # How long the black screen/clock takes to fade in and out
var needleRotateDuration: float = 1.5  # How long the needle takes to complete its spins
var needleSpinCount: float = 3.0       # Number of full anti-clockwise rotations
var fadeOutDelay: float = 0.8          # How long to wait before starting the fade-out
var levelFailHoldDuration: float = 1.0 # How long the instant fail screen stays before restarting

var whiteScreen: Sprite2D
var blackScreen: Sprite2D

var totalRewinds: int = 0
var levelOnePath: String = "res://levels/level_00.tscn"

func _ready() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	
	# Create the white screen
	whiteScreen = Sprite2D.new()
	whiteScreen.texture = CanvasTexture.new() # Built-in 1x1 white texture
	whiteScreen.modulate = Color.WHITE
	whiteScreen.centered = false
	whiteScreen.scale = viewport_size
	whiteScreen.z_index = 2
	add_child(whiteScreen)
	
	# Create the black screen
	blackScreen = Sprite2D.new()
	blackScreen.texture = CanvasTexture.new()
	blackScreen.modulate = Color.BLACK
	blackScreen.centered = false
	blackScreen.scale = viewport_size
	blackScreen.z_index = 2
	add_child(blackScreen)
	
	# Instantiate Player Silhouette
	if playerSilhouetteScene:
		playerSilhouetteInstance = playerSilhouetteScene.instantiate()
		playerSilhouetteInstance.z_index = 3 # Set to 3 as requested
		playerSilhouetteInstance.modulate.a = 0.0 # Make transparent for fading
		playerSilhouetteInstance.visible = false # Hidden initially
		add_child(playerSilhouetteInstance)
	
	# Instantiate Clock
	if clockScene:
		clockInstance = clockScene.instantiate()
		clockInstance.position = viewport_size / 2.0
		clockInstance.z_index = 3 # Above the black screen
		clockInstance.modulate.a = 0.0 # Make transparent for fading
		clockInstance.visible = false
		add_child(clockInstance)
		
		needleInstance = clockInstance.get_node("Needle")
		
	# Hide them initially so they don't block game on startup
	whiteScreen.visible = false
	blackScreen.visible = false
	whiteScreen.modulate.a = 0.0
	blackScreen.modulate.a = 0.0

# spawn next level scene
# pan to next level scene
# unload this scene
func transitionToNextLevel(currentLevel: Node2D, nextLevelScene: String, transitionDirection: Vector2 = Vector2(1, 0)) -> void:
	if !nextLevelScene:
		return

	# Spawn the next level scene
	var nextLevel: Node2D = load(nextLevelScene).instantiate()
	currentLevel.get_parent().add_child(nextLevel)
	
	# Position the next level off-screen
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	nextLevel.position.x = 2 * transitionDirection.x * viewport_size.x
	nextLevel.position.y = - 2 * transitionDirection.y * viewport_size.y
	
	# Create a tween to pan to the next level scene
	var tween: Tween = create_tween()
	tween.set_parallel(true) # Move both scenes at the same time
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Slide the current level out to the left, and the next level in from the right
	var currentLevelEndPoint = Vector2(-viewport_size.x * transitionDirection.x, viewport_size.y * transitionDirection.y)
	tween.tween_property(currentLevel, "position", currentLevelEndPoint, 1.0)
	tween.tween_property(nextLevel, "position", Vector2(0, 0), 2.0)
	
	# Wait for the panning animation to finish
	await tween.finished
	
	# Unload this scene
	currentLevel.queue_free()

func restartLevel(currentLevel: Node2D) -> void:
	if !currentLevel:
		return
		
	# 1. Fade the black screen and clock in (Silhouette is already visible from levelFail)
	blackScreen.visible = true
	if clockInstance: clockInstance.visible = true
	
	var fadeInTween: Tween = create_tween()
	fadeInTween.set_parallel(true)
	
	# Fading the clock automatically fades its child needle!
	fadeInTween.tween_property(blackScreen, "modulate:a", 1.0, fadeDuration)
	if clockInstance: fadeInTween.tween_property(clockInstance, "modulate:a", 1.0, fadeDuration)
	
	await fadeInTween.finished
	
	# 2. Make the needle rotate in the anticlockwise direction fast
	var rotateTween: Tween = create_tween()
	if needleInstance:
		rotateTween.tween_property(needleInstance, "rotation", -TAU * needleSpinCount, needleRotateDuration).as_relative().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		
	# 3. Unload and reload the current level
	var currentPath = currentLevel.scene_file_path
	var reloadedScene = load(currentPath) as PackedScene
	var nextLevel = reloadedScene.instantiate()
	currentLevel.get_parent().add_child(nextLevel)
	currentLevel.queue_free()
	
	# Wait using the variable
	await get_tree().create_timer(fadeOutDelay).timeout
	
	# 4. As the needle is rotating, fade all out to make the current level visible
	var fadeOutTween: Tween = create_tween()
	fadeOutTween.set_parallel(true)
	
	fadeOutTween.tween_property(blackScreen, "modulate:a", 0.0, fadeDuration)
	if clockInstance: fadeOutTween.tween_property(clockInstance, "modulate:a", 0.0, fadeDuration)
	
	await fadeOutTween.finished
	
	# Fully hide the UI overlays once transparent (removed silhouette hide)
	blackScreen.visible = false
	if clockInstance: clockInstance.visible = false
	
	# 5. Reset the clock and needle so that the needle is returned to 0 rotation
	if needleInstance:
		needleInstance.rotation = 0.0

func levelFail(currentLevel):
	# Corrected path to grab the player from the current level safely
	var playerNode = currentLevel.get_node("Player")
	playerSilhouetteInstance.frame = playerNode.frame
	# Instantly make the black screen visible
	blackScreen.modulate.a = 1.0
	blackScreen.visible = true
	
	# Instantly move silhouette to player position and make it visible
	if playerSilhouetteInstance and playerNode:
		playerSilhouetteInstance.global_position = playerNode.global_position
		playerSilhouetteInstance.modulate.a = 1.0
		playerSilhouetteInstance.visible = true
	
	# Stay there for a moment based on the variable
	await get_tree().create_timer(levelFailHoldDuration).timeout
	
	# Fade out the silhouette BEFORE restarting
	if playerSilhouetteInstance:
		var silhouetteFadeTween = create_tween()
		silhouetteFadeTween.tween_property(playerSilhouetteInstance, "modulate:a", 0.0, fadeDuration)
		await silhouetteFadeTween.finished
		playerSilhouetteInstance.visible = false
	
	restartLevel(currentLevel)
	
func returnToLevelOne(currentLevel: Node2D) -> void:
	# Reset the counter since they are back at the beginning
	fadeDuration= 0.5        # How long the black screen/clock takes to fade in and out
	needleRotateDuration= 5  # How long the needle takes to complete its spins
	needleSpinCount= 15.0      # Number of full anti-clockwise rotations
	fadeOutDelay = 3         # How long to wait before starting the fade-out
	levelFailHoldDuration= 1.0 
	totalRewinds = 0
	
	blackScreen.visible = true
	if clockInstance: clockInstance.visible = true
	
	var fadeInTween: Tween = create_tween()
	fadeInTween.set_parallel(true)
	
	fadeInTween.tween_property(blackScreen, "modulate:a", 1.0, fadeDuration)
	if clockInstance: fadeInTween.tween_property(clockInstance, "modulate:a", 1.0, fadeDuration)
	
	await fadeInTween.finished
	
	var rotateTween: Tween = create_tween()
	if needleInstance:
		rotateTween.tween_property(needleInstance, "rotation", -TAU * needleSpinCount, needleRotateDuration).as_relative().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		
	# Unload current level and load LEVEL ONE
	var reloadedScene = load(levelOnePath) as PackedScene
	var nextLevel = reloadedScene.instantiate()
	currentLevel.get_parent().add_child(nextLevel)
	currentLevel.queue_free()
	
	await get_tree().create_timer(fadeOutDelay).timeout
	
	var fadeOutTween: Tween = create_tween()
	fadeOutTween.set_parallel(true)
	
	fadeOutTween.tween_property(blackScreen, "modulate:a", 0.0, fadeDuration)
	if clockInstance: fadeOutTween.tween_property(clockInstance, "modulate:a", 0.0, fadeDuration)
	
	await fadeOutTween.finished
	
	blackScreen.visible = false
	if clockInstance: clockInstance.visible = false
	
	if needleInstance:
		needleInstance.rotation = 0.0

func fadeToNextLevel(currentLevel: Node2D, nextLevelScene: String) -> void:
	if !nextLevelScene:
		return

	# 1. Make the black screen visible and fade to solid black
	blackScreen.visible = true
	var fadeOutTween: Tween = create_tween()
	fadeOutTween.tween_property(blackScreen, "modulate:a", 1.0, fadeDuration)
	
	# Wait for the screen to go completely black
	await fadeOutTween.finished
	
	# 2. Unload the current scene and spawn the new one
	var loadedScene = load(nextLevelScene) as PackedScene
	var nextLevel = loadedScene.instantiate()
	currentLevel.get_parent().add_child(nextLevel)
	
	get_tree().current_scene = nextLevel
	
	currentLevel.queue_free()
	
	# Optional: Give the engine a tiny moment to process the new scene
	await get_tree().create_timer(0.1).timeout
	
	# 3. Fade the black screen back out to reveal the new level
	var fadeInTween: Tween = create_tween()
	fadeInTween.tween_property(blackScreen, "modulate:a", 0.0, fadeDuration)
	
	await fadeInTween.finished
	
	# Fully hide the black screen so it doesn't block clicks
	blackScreen.visible = false
