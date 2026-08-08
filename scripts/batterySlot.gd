extends Sprite2D
# References
var gridData: GridData
var coords: Vector2
var parentGate: Node2D # The specific gate this slot controls

var hasBattery: bool = false
var insertedBatteryItem: Node2D = null # Keep track of the actual battery item

func _ready() -> void:
	# 1. Register ourselves in the global grid data so the player can find it
	gridData.batterySlots[coords] = self
	position = gridData.coordToPos(coords)
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

func update_visuals() -> void:
	if texture == null:
		return # No sprite sheet assigned yet — skip silently
	if hasBattery:
		frame = 1 # Active sprite (filled)
	else:
		frame = 0 # Inactive sprite (empty)
