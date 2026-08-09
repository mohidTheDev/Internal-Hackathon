extends Node

const SFX_POOL_SIZE := 6
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_index := 0

var sfx_streams := {
	"gate_open": preload("res://audio/sfx/gate_close.mp3"),
	"gate_close": preload("res://audio/sfx/gate_open.mp3"),
	"move": preload("res://audio/sfx/move.mp3"),
	"laser": preload("res://audio/sfx/laser.mp3"),
	"die": preload("res://audio/sfx/die.mp3"),
	"explosion": preload("res://audio/sfx/explosion.mp3"),
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


func play_sfx(name: String, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	if not sfx_streams.has(name):
		push_warning("Unknown sfx: %s" % name)
		return
	var player := sfx_pool[sfx_index]
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE
	player.stream = sfx_streams[name]
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
