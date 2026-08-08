extends Sprite2D

var gridData: GridData

@export_group("Visuals")
@export var laserStartGap: float = 12.0 # How many pixels away from the center the laser starts

@export var coords: Vector2
@export var ySortOffset: Vector2 = Vector2(0, 16)
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

func setup() -> void:
	gridData.towers[coords] = self
	# Set position exactly to the center of the tile
	position = gridData.coordToPos(coords) + ySortOffset
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
		# Since actual center and visual center coincide, line.position defaults to (0,0)
		add_child(line)
		
	# Initial draw
	update_lasers(1)

func update_lasers(currentTurn: int) -> void:
	var cycleLength = activeCycle + inactiveCycle
	var isActive = false
	if cycleLength > 0:
		# Run the inactive cycle first, so it is always off on turn 0
		isActive = (currentTurn % cycleLength) >= inactiveCycle
	else:
		isActive = true # Always on if cycle is 0
	# The physical center is the visual center
	var localVisualCenter: Vector2 = Vector2(0, 0)
	
	for dir in lines.keys():
		var line = lines[dir]
		line.clear_points()
		
		if not isActive:
			continue
			
		# Trace laser from adjacent cell
		var traceCoord = coords + dir
		
		# Start with empty points so the line begins exactly at the first adjacent cell
		var points = [] 
		var pixelDir = (gridData.coordToPos(coords + dir) - gridData.coordToPos(coords)).normalized()
		# Add the first point, originating from the visual center, plus the gap
		points.append(localVisualCenter + (pixelDir * laserStartGap))
		while not gridData.isSolid(traceCoord):
			# Register as hazardous
			gridData.activeLaserCells[traceCoord] = true
			# Aim directly for the true center of the target tile
			var targetGlobalCenter = gridData.coordToPos(traceCoord) + ySortOffset
			# Map it directly back to the tower's local space
			var localPos = targetGlobalCenter - position
			points.append(localPos)
			# Move to next cell
			traceCoord += dir
			
		# Final point where it hits the edge of the solid object
		var hitGlobalCenter = gridData.coordToPos(traceCoord) + ySortOffset
		var hitLocalPos = hitGlobalCenter - position
		points.append(hitLocalPos)
		
		for p in points:
			line.add_point(p)
