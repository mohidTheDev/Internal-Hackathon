extends Node

# spawn next level scene
# pan to next level scene
# unload this scene
func transitionToNextLevel(currentLevel: Node2D, nextLevelScene: PackedScene) -> void:
	if !nextLevelScene:
		return

	# Spawn the next level scene
	var nextLevel: Node2D = nextLevelScene.instantiate()
	currentLevel.get_parent().add_child(nextLevel)
	
	# Position the next level off-screen
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	nextLevel.position.x = viewport_size.x
	nextLevel.position.y = 0
	
	# Create a tween to pan to the next level scene
	var tween: Tween = create_tween()
	tween.set_parallel(true) # Move both scenes at the same time
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Slide the current level out to the left, and the next level in from the right
	tween.tween_property(currentLevel, "position:x", -viewport_size.x, 1.0)
	tween.tween_property(nextLevel, "position:x", 0.0, 1.0)
	
	# Wait for the panning animation to finish
	await tween.finished
	
	# Unload this scene
	currentLevel.queue_free()
