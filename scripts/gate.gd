extends Sprite2D
enum gateType {keyCard, battery}
@export var type: gateType
@export var gateOpenTime: float = 0.1

var gridData: GridData
# light for indicating what the gate is for
var light: Node2D
var batterySlot: Node2D
var hasBattery: bool
var coords: Vector2

# tracks when gate was open close
var gateOpenTimeline: Array[bool]
var gateOpen: bool

func _ready() -> void:
	light = $Light
	batterySlot = $"Battery Slot"
	position = gridData.coordToPos(coords)
	gridData.gates[coords] = self
	# set colour according to type
	if type == gateType.keyCard:
		light.modulate = Color(0.224, 0.718, 0.741, 1.0)
	elif type == gateType.battery:
		light.modulate = Color(0.094, 0.553, 0.086, 1.0)
	updateOpenStatus()
		
func updateOpenStatus() -> void:
	if type == gateType.keyCard:
		var hasKeyCard: bool = false
		for item in gridData.inventory:
			if item.item == item.itemType.keyCard:
				hasKeyCard = true
				break
		# check if player is at an adjacent cell and has a keycard
		if (gridData.playerCoords - coords).length() <= 1 and hasKeyCard:
			gateOpenTimeline.append(true)
		else:
			gateOpenTimeline.append(false)
			
	# Battery gates do not use the timeline at all!
	toggleGate()

func toggleGate() -> void:
	# Determine what state the gate SHOULD be in right now
	var shouldBeOpen: bool
	if type == gateType.battery:
		shouldBeOpen = hasBattery
	else:
		shouldBeOpen = gateOpenTimeline[-1]
		
	# Play animations if the state needs to change
	if gateOpen and shouldBeOpen == false:
		# frame is 0
		frame = 1
		light.frame = 1
		await get_tree().create_timer(gateOpenTime).timeout
		frame = 2
		light.frame = 2
		
	elif !gateOpen and shouldBeOpen == true:
		# frame is 2
		frame = 1
		light.frame = 1
		await get_tree().create_timer(gateOpenTime).timeout
		frame = 0
		light.frame = 0
	
	# lock in the new state
	gateOpen = shouldBeOpen

func rewind() -> void:
	# Only keycard gates have a history to pop
	if type == gateType.keyCard:
		gateOpenTimeline.pop_back()
		
	await toggleGate()
