extends Node

# spawn next level scene
# pan to next level scene
# unload this scene

func transitionToNextLevel(currentLevel: Node2D, nextLevelScene: PackedScene, transitionDirection: Vector2 = Vector2(1, 0)) -> void:
	if !nextLevelScene:
		return

	# Spawn the next level scene
	var nextLevel: Node2D = nextLevelScene.instantiate()
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
