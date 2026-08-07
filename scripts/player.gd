extends Sprite2D

@export var gridData: GridData
@export_category("Animation")
@export var totalFrames: int = 3
@export var moveTime: float = 0.1

var levelController: Node2D

var rewindDuration: int
var totalMoves: int
var currentMoves: int = 0
var currentCoord: Vector2
var coordTimeline: Array[Vector2]

# keeps track of whether an action has been initiated 
# (and being waited to end to end the turn)
var canAct: bool

func inputCheck() -> void:
	if Input.is_action_just_pressed("up"):
		move(Vector2(-1, 0))
	elif Input.is_action_just_pressed("down"):
		move(Vector2(1, 0))
	elif Input.is_action_just_pressed("left"):
		move(Vector2(0, -1))
	elif Input.is_action_just_pressed("right"):
		move(Vector2(0, 1))	
	elif Input.is_action_just_pressed("e"):
		rewind()
func _ready() -> void:
	levelController = get_parent()
	currentCoord = levelController.playerSpawnCoord
	position = gridData.coordToPos(currentCoord)
	coordTimeline.append(currentCoord)
	totalMoves = levelController.moveLimit
	rewindDuration = levelController.rewindDuration
	gridData.playerCoords = currentCoord
	
func _process(_delta: float) -> void:
	if(!levelController.isPlayerTurn and canAct):
		return
	inputCheck()

# physically moves player to (updated) currentCoord 
# (used even during time rewind)
func slide() -> void:
	# create a tween to slide player to new cell
	var moveTween: Tween = create_tween()
	moveTween.tween_property(self, "position", 
	gridData.coordToPos(currentCoord), moveTime)
	gridData.playerCoords = currentCoord
	
	# wait for sliding to complete
	await moveTween.finished
	return
	
# direction is [row, column]
# player moves during their turn
func move(direction: Vector2) -> void:
	if !gridData.canMoveTo(currentCoord + direction):
		return
	if currentMoves == totalMoves:
		levelController.failLevel()
		return
	# check if the gate
	canAct = false
	
	
	# movement logic
	currentCoord += direction
	currentMoves += 1
	coordTimeline.append(currentCoord)	
	await slide()
	
	# check if reached goal
	if currentCoord == levelController.goalCoord:
		levelController.completeLevel()
		return
	
	# check for item pickup
	if gridData.items.has(currentCoord):
		# make sure gridData.items has all values of type "PickableItem"
		print("Picked up ", str(gridData.items[currentCoord]))
		gridData.items[currentCoord].pickup()
	
	# animation
	frame = (frame + 1) % totalFrames
	canAct = true
	
	levelController.endTurn()

func turnComplete() -> void:
	levelController.endTurn()
	return

func rewind() -> void:
	# allow rewind only if player has moved atleast 5 steps
	if len(coordTimeline) <= rewindDuration:
		return
	
	canAct = false
	for i in range(rewindDuration):
		# loop through all entities with a rewindable state
		
		# loop through gates
		for gate in gridData.gates.values():
			await gate.rewind()
		
		# remove current position from timeline and move to previous position
		coordTimeline.pop_back()
		currentCoord = coordTimeline[-1]
		frame = (frame + totalFrames - 1) % totalFrames
		currentMoves -= 1
		await slide()
	
	levelController.isPlayerTurn = true
	canAct = true
