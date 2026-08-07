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
	
	# Add check for occupancy
	
	return true
