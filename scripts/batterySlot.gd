extends Sprite2D

@export var ySortOffset: Vector2 = Vector2(0, 16)
# References
var gridData: GridData
var coords: Vector2
var parentGate: Node2D # The specific gate this slot controls

var hasBattery: bool = false
var insertedBatteryItem: Node2D = null # Keep track of the actual battery item
var keyIndicator: Sprite2D


func _ready() -> void:
	keyIndicator = $Keys
	keyIndicator.visible = false
	# 1. Register ourselves in the global grid data so the player can find it
	gridData.batterySlots[coords] = self
	position = gridData.coordToPos(coords) + ySortOffset
	update_visuals()

# Called by the player script
func insert_battery(battery: Node2D) -> void:
	hasBattery = true
	insertedBatteryItem = battery
	insertedBatteryItem.hide() # Hide the battery item when in the slot
	
	# 2. Tell the gate its power source is active
	if parentGate:
		parentGate.hasBattery = true
		
	update_visuals()

# Called by the player script
func remove_battery() -> Node2D:
	hasBattery = false
	var returned_battery = insertedBatteryItem
	returned_battery.show() # Show the battery item again when removed
	insertedBatteryItem = null
	
	# 3. Tell the gate its power source is gone
	if parentGate:
		parentGate.hasBattery = false
		
	update_visuals()
	return returned_battery # Give the battery back to the player

func _process(_delta: float) -> void:
	keyIndicator.visible = false
	if gridData.playerCoords != coords:
		return
	var playerHasBattery = null
	for item in gridData.inventory:
		if item.item == item.itemType.battery:
			playerHasBattery = item
			break
	if (hasBattery and !playerHasBattery) or (!hasBattery and playerHasBattery):
		keyIndicator.visible = true
func update_visuals() -> void:
	if texture == null:
		return # No sprite sheet assigned yet — skip silently
	if hasBattery:
		frame = 1 # Active sprite (filled)
	else:
		frame = 0 # Inactive sprite (empty)
