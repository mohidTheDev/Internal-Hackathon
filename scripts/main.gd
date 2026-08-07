extends Node2D

# [row, column] to access a grid point
@export_category("Grid Data")
@export var gridData: GridData
@export var rows: int = 5
@export var columns: int = 5
@export var tileSize: int = 32
@export var gridYOffset: int = 20
@export var gridHoles: Array[Vector2]
@export var goalCoord: Vector2

enum gateType {keyCard, battery, pressurePlate}
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
@export var horizontalGate: PackedScene
@export var verticalGate: PackedScene
var gridX: float
var gridY: float

var tilesHolder: Node2D
var itemsHolder: Node2D
var gatesHolder: Node2D
var isPlayerTurn: bool = true

# HUD references
var movesLabel: Label
var rewindLabel: Label
var inventoryLabel: Label

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
		elif gates[i] == gateType.pressurePlate:
			gate.type = gate.gateType.pressurePlate
		gatesHolder.add_child(gate)

# update gridData.tres and lay down the tiles
func gridSetup() -> void:
	gridY = gridYOffset
	gridX = get_viewport_rect().size.x / 2.0 - tileSize * columns / 2.0
	
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

# _enter_tree is called in top to bottom way (and before any _ready)
# here, it ensures the grid is setup before anything else happens
func _enter_tree() -> void:
	gridData.levelController = self
	gridSetup()
	itemSetup()
	gateSetup()

func _ready() -> void:
	var hud = $HUD
	movesLabel = hud.get_node("MovesContainer/MovesLabel")
	rewindLabel = hud.get_node("RewindContainer/RewindLabel")
	inventoryLabel = hud.get_node("InventoryContainer/InventoryLabel")
	updateHUD(0)

func updateHUD(currentMoves: int) -> void:
	var remaining: int = moveLimit - currentMoves
	movesLabel.text = str(remaining)
	movesLabel.modulate = Color(1.0, 0.25, 0.25, 1.0) if remaining <= 3 \
		else (Color(1.0, 0.75, 0.1, 1.0) if remaining <= moveLimit / 2 \
		else Color(0.2, 1.0, 0.6, 1.0))
	if currentMoves >= rewindDuration:
		rewindLabel.text = "READY"
		rewindLabel.modulate = Color(0.4, 0.8, 1.0, 1.0)
	else:
		rewindLabel.text = str(currentMoves) + " / " + str(rewindDuration)
		rewindLabel.modulate = Color(0.6, 0.6, 0.8, 1.0)

func _process(delta: float) -> void:
	pass

func organiseInventory() -> void:
	var direction = Vector2(1, 0)
	if playerInventoryFlow == inventoryFlow.Vertical:
		direction = Vector2(0, 1)
	for i in range(len(gridData.inventory)):
		var targetPos: Vector2 = playerInventoryPosition + i * direction * playerInventorySpacing
		var moveTween: Tween = create_tween()
		moveTween.tween_property(gridData.inventory[i], "position",
								targetPos, playerInventoryOrganiseTime)
	updateInventoryHUD()

func updateInventoryHUD() -> void:
	var counts := {"Key": 0, "Battery": 0, "Weight": 0}
	for item in gridData.inventory:
		if item.item == item.itemType.keyCard: counts["Key"] += 1
		elif item.item == item.itemType.battery: counts["Battery"] += 1
		elif item.item == item.itemType.weight: counts["Weight"] += 1
	var lines: PackedStringArray = []
	for k in counts:
		if counts[k] > 0: lines.append(k + " x" + str(counts[k]))
	inventoryLabel.text = "\n".join(lines) if lines.size() > 0 else "Empty"

func endTurn():
	if isPlayerTurn:
		isPlayerTurn = false
	
	# loop through all other components that may move
	# or do smth and make them do their actions
	
	# loop through gates to update their state
	for gate in gridData.gates.values():
		gate.updateOpenStatus()
	
	# player turn starts again
	isPlayerTurn = true

func completeLevel():
	# hide player
	# pause everything and play the level complete animation
	# (Player going down lift)
	# tell global to do:
	# 	spawn next level scene
	# 	pan to next level scene
	# 	unload this scene
	print("Level Complete")

func failLevel():
	# play the eplosion animation
	# play the clock turning back time animation
	# do the fade transition back to this scene resetted
	print("Level Failed")
	
