extends Node2D

@export_category("Level Management")
@export_custom(PROPERTY_HINT_FILE, "*.tscn") var nextLevel: String
# @export var nextLevel: PackedScene
@export var transitionDirection: Vector2 = Vector2(1, 0)
# [row, column] to access a grid point
@export_category("Grid Data")
@export var gridData: GridData
@export var rows: int = 5
@export var columns: int = 5
@export var tileSize: int = 32
@export var gridYOffset: int = 20
@export var gridHoles: Array[Vector2]
@export var goalCoord: Vector2

enum gateType {keyCard, battery}
enum gateDir {Horizontal, Vertical}
# Using parallel arrays; so make corresponding arrasy
# have the same number of elements
@export_category("Grid Entities")
@export var pickableItems: Array[PackedScene]
@export var pickableItemsCoords: Array[Vector2]
@export var gates: Array[gateType]
@export var gatesOrientation: Array[gateDir]
@export var gatesCoords: Array[Vector2]

enum inventoryFlow {Horizontal, Vertical}
@export_category("Player")
@export var moveLimit: int = 10
@export var rewindDuration: int = 5
@export var playerSpawnCoord: Vector2
@export var playerInventoryPosition: Vector2
@export var playerInventoryFlow: inventoryFlow
@export var playerInventorySpacing: float = 40
@export var playerInventoryOrganiseTime: float = 0.5

@export_category("Packed Scenes")
@export var tile: PackedScene
@export var wall: PackedScene
@export var horizontalGate: PackedScene
@export var verticalGate: PackedScene
@export var goalTile: PackedScene

@export_category("HUD")
@export var watchAnimTime: float = 0.1
@export var needleJitterStrength: float = 8.0 # The maximum degrees the needle will shake
var watchAnimTimer: float = 0
var targetNeedleAngle: float = 0
@export var batterySlotScene: PackedScene
@export var towerScene: PackedScene

@export_category("Towers")
@export var towerCoords: Array[Vector2]
@export var towerFireUp: Array[bool]
@export var towerFireDown: Array[bool]
@export var towerFireLeft: Array[bool]
@export var towerFireRight: Array[bool]
@export var towerActiveCycle: Array[int]
@export var towerInactiveCycle: Array[int]

@export_category("Battery Slots")
# Parallel arrays: batterySlotCoords[i] is powered by the slot, opens gatesCoords[batterySlotGateIndex[i]]
@export var batterySlotCoords: Array[Vector2]
@export var batterySlotGateIndex: Array[int]
@export var batterySlotHasBatteryByDefault: Array[bool]
@export var batteryItemScene: PackedScene
var gridX: float
var gridY: float

var tilesHolder: Node2D
var itemsHolder: Node2D
var gatesHolder: Node2D
var wallsHolder: Node2D
var slotsHolder: Node2D
var towersHolder: Node2D
var isPlayerTurn: bool = true
var rewindAvailable: bool = false
# HUD references
var clock: Node2D
var movesLabel: Label

func animateWatch(delta):
	if (!rewindAvailable):
		clock.frame = 0
		watchAnimTimer = 0
		# Lock the needle firmly to the target angle when not rewinding
		clock.get_node("Needle").rotation_degrees = targetNeedleAngle
		return
	watchAnimTimer += delta
	if watchAnimTimer >= watchAnimTime:
		watchAnimTimer -= watchAnimTime	
		if clock.frame < 2 or clock.frame >= 5:
			clock.frame = 2
		else:
			clock.frame += 1
		# Apply jitter to the needle around the target angle
	var jitter: float = randf_range(-needleJitterStrength, needleJitterStrength)
	clock.get_node("Needle").rotation_degrees = targetNeedleAngle + jitter
func itemSetup() -> void:
	itemsHolder = $"Items Holder"
	for i in range(len(pickableItems)):
		var item = pickableItems[i].instantiate()
		item.coords = pickableItemsCoords[i]
		item.gridData = gridData
		itemsHolder.add_child(item)

func gateSetup() -> void:
	gatesHolder = $"Gates Holder"
	for i in range(len(gates)):
		var gate
		if gatesOrientation[i] == gateDir.Horizontal:
			gate = horizontalGate.instantiate()
		else:
			gate = verticalGate.instantiate()
		gate.gridData = gridData
		gate.coords = gatesCoords[i]
		if gates[i] == gateType.keyCard:
			gate.type = gate.gateType.keyCard
		elif gates[i] == gateType.battery:
			gate.type = gate.gateType.battery
		gatesHolder.add_child(gate)

func batterySlotSetup() -> void:
	if batterySlotScene == null or batterySlotCoords.is_empty():
		return
	slotsHolder = $"Slots Holder"
	for i in range(batterySlotCoords.size()):
		var slot = batterySlotScene.instantiate()
		slot.gridData = gridData
		slot.coords = batterySlotCoords[i]
		# Link to its gate using the parallel index array
		if i < batterySlotGateIndex.size():
			var gateIdx = batterySlotGateIndex[i]
			if gateIdx >= 0 and gateIdx < gatesHolder.get_child_count():
				slot.parentGate = gatesHolder.get_child(gateIdx)
				print("[BatterySlot] Slot ", i, " at ", batterySlotCoords[i], 
					" linked to gate: ", slot.parentGate.name)
			else:
				print("[BatterySlot] WARNING: gate index ", gateIdx, " out of range!")
			if i < batterySlotHasBatteryByDefault.size() and batterySlotHasBatteryByDefault[i]:
				var battery = batteryItemScene.instantiate()
				battery.gridData = gridData
				battery.coords = batterySlotCoords[i]
				itemsHolder.add_child(battery)
				slot.insert_battery(battery)
				slot.parentGate.updateOpenStatus()
				
		slotsHolder.add_child(slot)

func towerSetup() -> void:
	if towerScene == null or towerCoords.is_empty():
		return
	towersHolder = $"Towers Holder"
	for i in range(towerCoords.size()):
		var tower = towerScene.instantiate()
		tower.gridData = gridData
		tower.coords = towerCoords[i]
		
		# Safely apply parallel array settings if the user filled them out
		if i < towerFireUp.size(): tower.fireUp = towerFireUp[i]
		if i < towerFireDown.size(): tower.fireDown = towerFireDown[i]
		if i < towerFireLeft.size(): tower.fireLeft = towerFireLeft[i]
		if i < towerFireRight.size(): tower.fireRight = towerFireRight[i]
		if i < towerActiveCycle.size(): tower.activeCycle = towerActiveCycle[i]
		if i < towerInactiveCycle.size(): tower.inactiveCycle = towerInactiveCycle[i]
		
		towersHolder.add_child(tower)
		tower.setup()

func gridSetup() -> void:
	gridY = gridYOffset
	gridX = get_viewport_rect().size.x / 2.0 - tileSize * columns / 2.0
	
	# clear previously stored data
	gridData.inventory.clear()
	gridData.items.clear()
	gridData.gates.clear()
	
	# initialise the grid data file
	gridData.columns = columns
	gridData.rows = rows
	gridData.tileSize = tileSize
	gridData.gridPosition = Vector2(gridX, gridY)
	gridData.gridHoles = gridHoles
	
	tilesHolder = $"Tiles Holder"
	for row in range(rows):
		for column in range(columns):
			if Vector2(row, column) in gridHoles:
				continue
			var tileInstance = tile.instantiate()
			tileInstance.position = gridData.coordToPos(Vector2(row, column))
			tilesHolder.add_child(tileInstance)
	var goalTileInstance = goalTile.instantiate()
	goalTileInstance.position = gridData.coordToPos(goalCoord) + Vector2(0, tileSize / 2)
	tilesHolder.add_child(goalTileInstance)
	if transitionDirection == Vector2(1, 0):
		pass
	elif transitionDirection == Vector2(0, 1):
		goalTileInstance.rotation_degrees = -90
	elif transitionDirection == Vector2(-1, 0):
		goalTileInstance.frame = 1
	else:
		goalTileInstance.frame = 1
		goalTileInstance.rotation_degrees = -90
# Adds walls to the top tiles in each column
func wallSetup():
	wallsHolder = $"Walls Holder"
	
	var wallYSortOffset: Vector2 = Vector2(0, 16)
	# for each column (index), represents the row at which wall is present
	var wallRows: Array
	# stores wall for each column
	var wallArray: Array
	# loop through the columns
	for column in range(columns):
		# keeps track of the first tile in the column which is not a hole
		var row = 0;
		while Vector2(row, column) in gridHoles:
			row += 1
		wallRows.append(row)
		var wallInstance = wall.instantiate()
		wallsHolder.add_child(wallInstance)
		
		wallInstance.position = gridData.coordToPos(Vector2(row, column)) + wallYSortOffset
		#wallInstance.offset = -wallYSortOffset
		wallArray.append(wallInstance)
		
	# loop through the walls and change their sprites
	# depending on whether they have walls next to them
	for column in range(columns):
		# left most column
		if column == 0:
			if wallRows[1] >= wallRows[0]:
				wallArray[column].frame = 0
			elif wallRows[1] < wallRows[0]:
				wallArray[column].frame = 2
			continue
			
		# right most column
		if column == columns - 1:
			if wallRows[column - 1] >= wallRows[column]:
				wallArray[column].frame = 0
			elif wallRows[column - 1] < wallRows[column]:
				wallArray[column].frame = 1
			continue
		
		# wall in between
		var left: bool = wallRows[column - 1] >= wallRows[column]
		var right: bool = wallRows[column + 1] >= wallRows[column]
		if (left and right):
			wallArray[column].frame = 0
		elif left:
			wallArray[column].frame = 2
		elif right:
			wallArray[column].frame = 1
		else:
			wallArray[column].frame = 3
			
		
# _enter_tree is called in top to bottom way (and before any _ready)
# here, it ensures the grid is setup before anything else happens
func _enter_tree() -> void:
	gridData.levelController = self
	# Clear shared Resource dicts — GridData is a .tres singleton
	# so these persist across runs if not explicitly cleared.
	gridData.gates.clear()
	gridData.batterySlots.clear()
	gridData.towers.clear()
	gridData.activeLaserCells.clear()
	gridData.items.clear()
	gridData.inventory.clear()
	#gridData.globalTurnCount = 0
	gridSetup()
	wallSetup()
	itemSetup()
	gateSetup()

# Question: do we need to do this in _ready?
func _ready() -> void:
	clock = $Clock
	movesLabel = clock.get_node("MovesLabel")
	updateHUD(0)
	batterySlotSetup()
	towerSetup()

func updateHUD(currentMoves: int) -> void:
	var remainingMoves: int = moveLimit - currentMoves
	movesLabel.text = str(remainingMoves)
	# Store the base angle instead of applying it immediately
	targetNeedleAngle = (get_node("Player").currentMoves * 45) % 360
	
	if currentMoves >= rewindDuration:
		rewindAvailable = true
		if clock.has_node("Keys"): clock.get_node("Keys").visible = true
	else:
		rewindAvailable = false
		if clock.has_node("Keys"): clock.get_node("Keys").visible = false
		
	# visual indication for movement
	
	# 1. Visual Escalation (Heartbeat Scale)
	var isCritical = remainingMoves <= 3
	var isWarning = remainingMoves <= float(moveLimit) / 2.0
	
	# Heartbeat Scale bump
	var bumpScale = Vector2(2, 2) if isCritical else Vector2(1.85, 1.85)
	var bumpDuration = 0.3 if isCritical else 0.15
	
	var scaleTween = create_tween()
	scaleTween.tween_property(clock, "scale", bumpScale, 0.05)
	scaleTween.tween_property(clock, "scale", Vector2(1.75, 1.75), bumpDuration).set_ease(Tween.EASE_OUT)
	
	# 2. Environmental Stress (Screen Shake & Flash)
	# Only trigger stress effects if the player actually just moved (not rewinding or starting)
	var playerNode = get_node("Player")
	if currentMoves > 0 and not playerNode.isRewinding:
		var shakeIntensity = 0.0
		if isCritical:
			shakeIntensity = 12.0
		elif isWarning:
			shakeIntensity = 4.0
			
		# Apply the Screen Shake by rapidly shifting the main level node
		if shakeIntensity > 0.0:
			var shakeTween = create_tween()
			for i in range(5):
				var randomOffset = Vector2(randf_range(-shakeIntensity, shakeIntensity), randf_range(-shakeIntensity, shakeIntensity))
				shakeTween.tween_property(self, "position", randomOffset, 0.04)
			shakeTween.tween_property(self, "position", Vector2.ZERO, 0.04) # Snap back to center

func _process(delta: float) -> void:
	animateWatch(delta)
	if (Input.is_action_just_pressed("r")):
		Global.restartLevel(self)

# arranges all items in the player's inventory (visually) to be equally spaced
func organiseInventory() -> void:
	var direction = Vector2(1, 0)
	if playerInventoryFlow == inventoryFlow.Vertical:
		direction = Vector2(0, 1)
	
	# loop through all elements of inventory
	for i in range(len(gridData.inventory)):
		# find their position with respect to the inventory ui position
		var targetPos: Vector2 = playerInventoryPosition + i * direction * playerInventorySpacing
		
		# tween to position
		var moveTween: Tween = create_tween()
		moveTween.tween_property(gridData.inventory[i], "position",
								targetPos, playerInventoryOrganiseTime)		

func endTurn():
	if isPlayerTurn:
		isPlayerTurn = false
	
	var player = $Player
	
	# loop through all other components that may move
	# or do smth and make them do their actions
	
	# loop through gates to update their state
	for gate in gridData.gates.values():
		gate.updateOpenStatus()
		
	# Clear active laser cells to refresh them based on the new turn state
	gridData.activeLaserCells.clear()
	for tower in gridData.towers.values():
		tower.update_lasers(len(player.coordTimeline))
	
	# player turn starts again
	isPlayerTurn = true

func completeLevel():
	# hide player
	# pause everything and play the level complete animation
	# (Player going down lift)
	SoundManager.play_sfx("lvl_end", 0, 0, 0.5)
	# scene transition
	Global.transitionToNextLevel(self, nextLevel, transitionDirection)

func failLevel():
	SoundManager.play_sfx("die")
	Global.levelFail(self)
	
