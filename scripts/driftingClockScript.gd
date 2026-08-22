extends Node2D

var velocity: Vector2
var spawner: Node

func initialize(manager: Node, start_pos: Vector2, start_dir: Vector2, speed: float, depth: float) -> void:
	spawner = manager
	position = start_pos
	
	# 1. Spawn at a random rotation
	rotation = randf() * TAU 
	
	# Tie the speed to the depth for a parallax effect (smaller clocks drift slower)
	velocity = start_dir * speed * depth
	
	# Start invisible and infinitely small, just like your asteroid script
	modulate.a = 0
	scale = Vector2(0, 0)
	
	# Tween up to the target depth value (which controls both alpha and size)
	var alphaTween = create_tween()
	alphaTween.tween_property(self, "modulate", Color(1, 1, 1, depth), 2)
	
	var scaleTween = create_tween()
	scaleTween.tween_property(self, "scale", Vector2(depth, depth), 2)

func _process(delta: float) -> void:
	# Drift over time
	position += velocity * delta
	
	# Despawn and replace logic
	check_bounds()

func check_bounds() -> void:
	# The threshold past the edge of the screen before they despawn
	var margin: float = 150.0 
	var screen_size: Vector2 = get_viewport_rect().size
	
	if position.x < -margin or position.x > screen_size.x + margin or position.y < -margin or position.y > screen_size.y + margin:
		# Tell the parent spawner to spawn a replacement
		if spawner and spawner.has_method("spawn_replacement"):
			spawner.spawn_replacement()
			
		queue_free()
