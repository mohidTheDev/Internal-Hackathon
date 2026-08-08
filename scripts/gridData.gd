class_name GridData extends Resource
var columns: int
var rows: int
var tileSize: int
var gridPosition: Vector2
var gridHoles: Array[Vector2]
var levelController: Node2D
var playerCoords: Vector2

# coordinate (Vector2) : item (node2D)
var items: Dictionary

# coordinate (Vector2) : gate (node2D)
var gates: Dictionary

# coordinate (Vector2) : batterySlot (node2D)
var batterySlots: Dictionary

# coordinate (Vector2) : tower (node2D)
var towers: Dictionary

# stores all coordinates currently hazardous due to active lasers
var activeLaserCells: Dictionary

# tracks absolute global time for deterministic tower math
var globalTurnCount: int = 0

# keeps track of items picked up by player
var inventory: Array[Node2D]

# Keeps track of what tiles are occupied and by what
# var gridOccupants: Array[Array]

# Takes tile coordinate and spits out pixel position
func coordToPos(tileCoord: Vector2) -> Vector2:
	var pos: Vector2
	pos.x = gridPosition.x + tileSize * tileCoord.y
	pos.y = gridPosition.y + tileSize * tileCoord.x
	return pos

func canMoveTo(tileCoord: Vector2) -> bool:
	if tileCoord in gridHoles:
		return false
	
	if (tileCoord.x < 0 or tileCoord.x >= rows 
	or tileCoord.y < 0 or tileCoord.y >= columns):
		return false
	
	# check for closed gate
	if gates.has(tileCoord) and !gates[tileCoord].gateOpen:
		return false
	
	# check for towers (towers are solid)
	if towers.has(tileCoord):
		return false
	
	return true

# Used by laser raycasts to check if a cell blocks the beam
func isSolid(tileCoord: Vector2) -> bool:
	# Lasers pass over holes, but stop at the edge of the map
	if (tileCoord.x < 0 or tileCoord.x >= rows 
	or tileCoord.y < 0 or tileCoord.y >= columns):
		return true
		
	# Lasers stop at closed gates, pass through open ones
	if gates.has(tileCoord) and !gates[tileCoord].gateOpen:
		return true
		
	# Lasers stop at towers
	if towers.has(tileCoord):
		return true
		
	return false
