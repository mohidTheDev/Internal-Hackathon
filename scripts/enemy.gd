extends Sprite2D

@export var gridData: GridData
@export var startCoord: Vector2
@export var moveTime: float = 0.1
@export var totalFrames: int = 3
@export var ySortOffset: Vector2 = Vector2(0, 24)

var coords: Vector2
var coordTimeline: Array[Vector2]

func _ready() -> void:
	# Register in gridData enemies array
	gridData.enemies.append(self)
	
	coords = startCoord
	position = gridData.coordToPos(coords) + ySortOffset
	coordTimeline.append(coords)

func take_turn() -> void:
	var valid_moves: Array[Vector2] = []
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	
	for dir in directions:
		var target = coords + dir
		if target.x >= 0 and target.x < gridData.rows and target.y >= 0 and target.y < gridData.columns:
			valid_moves.append(target)
			
	if valid_moves.size() > 0:
		var target = valid_moves[randi() % valid_moves.size()]
		coords = target
		coordTimeline.append(coords)
		await slide()
		check_collision()

func slide() -> void:
	var moveTween: Tween = create_tween()
	moveTween.tween_property(self, "position", gridData.coordToPos(coords) + ySortOffset, moveTime)
	await moveTween.finished
	frame = (frame + 1) % totalFrames

func check_collision() -> void:
	if coords == gridData.playerCoords:
		gridData.levelController.failLevel()

func rewind() -> void:
	if coordTimeline.size() > 1:
		coordTimeline.pop_back()
		coords = coordTimeline[-1]
		await slide()
