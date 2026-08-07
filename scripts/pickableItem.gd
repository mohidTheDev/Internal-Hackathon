class_name PickableItem extends Sprite2D

var gridData: GridData
var coords: Vector2

enum itemType {keyCard, battery, weight}
@export var item: itemType
func _ready() -> void:
	# Add self to the grid
	gridData.items[coords] = self
	position = gridData.coordToPos(coords)
	
func pickup() -> void:
	# Remove from grid once picked up
	gridData.items.erase(coords)
	# Add to player inventory
	gridData.inventory.append(self)
	gridData.levelController.organiseInventory()
	
