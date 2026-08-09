extends Node

const SFX_POOL_SIZE := 7
const CUSTOM_SFX_POOL_SIZE := 9
var custom_sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_index := 0
var custom_sfx_index := 0

var sfx_streams := {
	"gate_open": preload("res://audio/sfx/gate_close.mp3"),
	"gate_close": preload("res://audio/sfx/gate_open.mp3"),
	"move": preload("res://audio/sfx/move.mp3"),
	"laser": preload("res://audio/sfx/laser.mp3"),
	"die": preload("res://audio/sfx/die.mp3"),
	"explosion": preload("res://audio/sfx/explosion.mp3"),
	"lvl_end": preload("res://audio/sfx/lvl_end.mp3")
}

var custom_sfx_streams := {
	"1": preload("res://audio/funnier_sfx/1.mp3"),
	"2": preload("res://audio/funnier_sfx/2.mp3"),
	"3": preload("res://audio/funnier_sfx/3.mp3"),
	"4": preload("res://audio/funnier_sfx/4.mp3"),
	"5": preload("res://audio/funnier_sfx/5.mp3"),
	"6": preload("res://audio/funnier_sfx/6.mp3"),
	"7": preload("res://audio/funnier_sfx/7.mp3"),
	"8": preload("res://audio/funnier_sfx/8.mp3"),
	"tbg": preload("res://audio/funnier_sfx/thats_borderline_gay.mp3")
}

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)

	music_player.bus = "Music"
	add_child(music_player)
	
	for i in CUSTOM_SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" # Or a different bus if intended
		add_child(p)
		custom_sfx_pool.append(p)

	music_player.bus = "Music"
	add_child(music_player)


func play_sfx(name: String, pitch_variation: float = 0.0, volume_db: float = 0.0, delay: float =0.0) -> void:
	if not sfx_streams.has(name):
		push_warning("Unknown sfx: %s" % name)
		return
	var player := sfx_pool[sfx_index]
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE
	player.stream = sfx_streams[name]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.volume_db = volume_db
	await get_tree().create_timer(delay).timeout
	player.play()
	
func play_custom_sfx(name: String, pitch_variation: float = 0.0, volume_db: float = 0.0, delay: float = 0.0) -> void:
	if not custom_sfx_streams.has(name):
		push_warning("Unknown custom sfx: %s" % name)
		return
		
	# Use the custom pool variables
	var player := custom_sfx_pool[custom_sfx_index]
	custom_sfx_index = (custom_sfx_index + 1) % CUSTOM_SFX_POOL_SIZE
	
	# Handle delay safely by doing it before changing stream properties
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		
	player.stream = custom_sfx_streams[name]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.volume_db = volume_db
	player.play()

func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.volume_db = -40
	music_player.play()
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", 0.0, fade_in)
	
func stop_music(fade_out: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -40, fade_out)
	tween.tween_callback(music_player.stop)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
