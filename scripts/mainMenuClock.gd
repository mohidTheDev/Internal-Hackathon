extends Node2D

@export_category("Clock Settings")
@export var tick_interval: float = 2.0 # Seconds between each tick
@export var rotation_step: float = 45.0 # Degrees to rotate per tick
@export var maximum_alpha: float = 0.8
@export var minimum_alpha: float = 0.1 # How faded the clock gets right before the next tick

@onready var needle: Sprite2D = $Needle
@onready var tick_sound: AudioStreamPlayer2D = $TickSound
@onready var music_player: AudioStreamPlayer2D = $MusicPlayer

var time_since_last_tick: float = 0.0

func _ready() -> void:
	# Initialize the clock fully visible
	modulate.v = maximum_alpha
	
	if music_player.stream != null:
		music_player.play()

func _process(delta: float) -> void:
	time_since_last_tick += delta
	
	# Calculate how close we are to the next tick (0.0 to 1.0)
	var time_progress: float = time_since_last_tick / tick_interval
	
	# Smoothly fade the entire clock's alpha from 1.0 down to the minimum_alpha
	modulate.v = lerp(maximum_alpha, minimum_alpha, time_progress)
	
	# Check if it is time to tick
	if time_since_last_tick >= tick_interval:
		_tick()

func _tick() -> void:
	# Reset the timer (subtracting the interval keeps it perfectly accurate over time)
	time_since_last_tick -= tick_interval
	
	# Snap the alpha immediately back to full visibility
	modulate.v = maximum_alpha
		
	# Rotate the needle clockwise by the specified degrees
	needle.rotation_degrees += rotation_step
	
	# Play the tick sound
	if tick_sound.stream != null:
		tick_sound.play()
