extends Sprite2D

var gridData: GridData

@export var coords: Vector2
@export_group("Directions")
@export var fireUp: bool = true
@export var fireDown: bool = true
@export var fireLeft: bool = true
@export var fireRight: bool = true

@export_group("Timing")
@export var activeCycle: int = 1
@export var inactiveCycle: int = 1

# Line2D nodes for the lasers
var lines: Dictionary = {}

func _ready() -> void:
	gridData.towers[coords] = self
	position = gridData.coordToPos(coords)
	
	# Setup lines for each active direction
	if fireUp: lines[Vector2(-1, 0)] = Line2D.new()
	if fireDown: lines[Vector2(1, 0)] = Line2D.new()
	if fireLeft: lines[Vector2(0, -1)] = Line2D.new()
	if fireRight: lines[Vector2(0, 1)] = Line2D.new()
	
	for dir in lines:
		var line = lines[dir]
		line.width = 4
		line.default_color = Color(1, 0, 0, 0.8) # Red laser
		# Adjust line so it starts relative to the center of the 32x32 tile
		line.position = Vector2(16, 16)
		add_child(line)
		
	# Initial draw
	update_lasers(gridData.globalTurnCount)

func update_lasers(currentTurn: int) -> void:
	var cycleLength = activeCycle + inactiveCycle
	var isActive = false
	if cycleLength > 0:
		# Run the inactive cycle first, so it is always off on turn 0
		isActive = (currentTurn % cycleLength) >= inactiveCycle
	else:
		isActive = true # Always on if cycle is 0
		
	for dir in lines.keys():
		var line = lines[dir]
		line.clear_points()
		
		if not isActive:
			continue
			
		# Trace laser from adjacent cell
		var traceCoord = coords + dir
		
		# Start with empty points so the line begins exactly at the first adjacent cell
		var points = [] 
		
		while not gridData.isSolid(traceCoord):
			# Register as hazardous
			gridData.activeLaserCells[traceCoord] = true
			
			# Add visual point (relative to tower center)
			var relativePos = gridData.coordToPos(traceCoord) - position - Vector2(16, 16)
			# Add center offset so the beam hits the middle of the tile
			relativePos += Vector2(16, 16)
			points.append(relativePos)
			
			# Move to next cell
			traceCoord += dir
			
		# Extend line to the edge of the solid object it hit
		var hitPos = gridData.coordToPos(traceCoord) - position - Vector2(16, 16)
		hitPos += Vector2(16, 16)
		points.append(hitPos)
			
		for p in points:
			line.add_point(p)
