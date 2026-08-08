extends Sprite2D

@export var gridData: GridData
@export_category("Animation")
@export var moveTime: float = 0.1
@export var animTime: float = 0.1

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
	elif Input.is_action_just_pressed("f"):
		interact_with_slot()
func _ready() -> void:
	levelController = get_parent()
	currentCoord = levelController.playerSpawnCoord
	position = gridData.coordToPos(currentCoord)
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
	gridData.coordToPos(currentCoord), moveTime)
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
	gridData.globalTurnCount += 1
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
	
	# Death check: Did we step into a laser, or did a laser just turn on?
	if gridData.activeLaserCells.has(currentCoord):
		levelController.failLevel()

func turnComplete() -> void:
	levelController.endTurn()
	return

func rewind() -> void:
	if !canAct:
		return
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
		
		var previousCoord = coordTimeline[-1]
		if currentCoord != previousCoord:
			currentMoves -= 1
			gridData.globalTurnCount -= 1
		
		# Re-evaluate laser towers for the past state
		gridData.activeLaserCells.clear()
		for tower in gridData.towers.values():
			tower.update_lasers(gridData.globalTurnCount)
			
		currentCoord = previousCoord
		await slide()
	
	# SNAP TO REALITY
	# After the replay is over, force the timeline's "present" state to match the 
	# physical battery, so the gate doesn't get stuck in the past!
	for gate in gridData.gates.values():
		if gate.type == gate.gateType.battery:
			gate.gateOpenTimeline[-1] = gate.hasBattery
			gate.toggleGate()
			
	# Also update lasers one last time just in case a gate snapped open/closed
	gridData.activeLaserCells.clear()
	for tower in gridData.towers.values():
		tower.update_lasers(gridData.globalTurnCount)
		
	isRewinding = false
	levelController.isPlayerTurn = true
	canAct = true

# Battery Slot — F key. Does NOT cost a move but still ends the turn
# so gates update. Appends to timelines so rewind stays in sync.
func interact_with_slot() -> void:
	print("[Player] Pressed F! Current Coord: ", currentCoord)
	print("[Player] Available Battery Slots: ", gridData.batterySlots.keys())
	if !canAct:
		print("[Player] cannot act")
		return
	if not gridData.batterySlots.has(currentCoord):
		print("[Player] no slot at ", currentCoord)
		return
	
	var slot = gridData.batterySlots[currentCoord]
	canAct = false
	
	if slot.hasBattery:
		# Remove battery — does not cost a move
		var battery = slot.remove_battery()
		gridData.inventory.append(battery)
		levelController.organiseInventory()
	else:
		# Find battery in inventory
		var batteryItem = null
		for item in gridData.inventory:
			if item.item == item.itemType.battery:
				batteryItem = item
				break
		if batteryItem == null:
			canAct = true
			return
		# Insert battery — does not cost a move
		gridData.inventory.erase(batteryItem)
		slot.insert_battery(batteryItem)
		levelController.organiseInventory()
	
	# Append to timelines so rewind replays this action
	coordTimeline.append(currentCoord)
	lookTimeline.append(lookingLeft)
	# currentMoves and globalTurnCount are intentionally NOT incremented!
	
	canAct = true
	# Trigger endTurn so gates record their state to the timeline array!
	levelController.endTurn()