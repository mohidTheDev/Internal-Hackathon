extends Sprite2D

@export var gridData: GridData
@export_category("Animation")
@export var moveTime: float = 0.1
@export var animTime: float = 0.1
@export var ySortOffset: Vector2 = Vector2(0, 16)

var levelController: Node2D

var rewindDuration: int
var totalMoves: int
var currentMoves: int = 0
var currentCoord: Vector2
var coordTimeline: Array[Vector2]
var lookingLeft: bool = false
var lookTimeline: Array[bool]

var animTimer: float = 0
var isRewinding: bool = false

# keeps track of whether an action has been initiated 
# (and being waited to end to end the turn)
var canAct: bool = true

# manages player animation
func animate(delta) -> void:
	if canAct:
		# --- IDLE STATE ---
		animTimer += delta
		
		# Ensure we snap to a valid idle frame immediately when movement stops
		if lookingLeft and frame not in [2, 3]:
			frame = 2
		elif not lookingLeft and frame not in [0, 1]:
			frame = 0
			
		# Alternate frames based on animTime
		if animTimer >= animTime:
			animTimer -= animTime # smoother than resetting to 0.0
			if lookingLeft:
				frame = 3 if frame == 2 else 2
			else:
				frame = 1 if frame == 0 else 0
	else:
		# --- MOVING STATE ---
		animTimer = 0.0 # Reset timer for the next time we enter idle
		
		if isRewinding:
			frame = 4 if lookingLeft else 5
		else:
			frame = 5 if lookingLeft else 4

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
	
	# y sort pivot
	position = gridData.coordToPos(currentCoord) + ySortOffset
	#offset = -ySortOffset
	coordTimeline.append(currentCoord)
	lookTimeline.append(lookingLeft)
	totalMoves = levelController.moveLimit
	rewindDuration = levelController.rewindDuration
	gridData.playerCoords = currentCoord
	
func _process(delta: float) -> void:
	animate(delta)
	if(!levelController.isPlayerTurn and canAct):
		return
	inputCheck()

# physically moves player to (updated) currentCoord 
# (used even during time rewind)
func slide() -> void:
	# create a tween to slide player to new cell
	var moveTween: Tween = create_tween()
	moveTween.tween_property(self, "position", 
	gridData.coordToPos(currentCoord) + ySortOffset, moveTime)
	gridData.playerCoords = currentCoord
	
	# wait for sliding to complete
	await moveTween.finished
	return
	
# direction is [row, column]
# player moves during their turn
func move(direction: Vector2) -> void:
	if !canAct:
		return
	if !gridData.canMoveTo(currentCoord + direction):
		return
	if currentMoves == totalMoves:
		levelController.failLevel()
		return
	canAct = false
	
	if direction == Vector2(0, -1):
		lookingLeft = true
	else:
		lookingLeft = false
	
	# movement logic
	currentCoord += direction
	currentMoves += 1
	coordTimeline.append(currentCoord)
	lookTimeline.append(lookingLeft)
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
	isRewinding = true
	for i in range(rewindDuration):
		# loop through all entities with a rewindable state
		
		# loop through gates
		for gate in gridData.gates.values():
			await gate.rewind()
		
		# remove current position from timeline and move to previous position
		coordTimeline.pop_back()
		lookTimeline.pop_back()
		lookingLeft = lookTimeline[-1]
		currentCoord = coordTimeline[-1]
		currentMoves -= 1
		await slide()
	
	isRewinding = false
	levelController.isPlayerTurn = true
	canAct = true
