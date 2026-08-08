class_name PickableItem extends Sprite2D

var gridData: GridData
var coords: Vector2
enum itemType {keyCard, battery, weight}
@export var item: itemType
@export var ySortOffset: Vector2 = Vector2(0, 16)
func _ready() -> void:
	# Add self to the grid
	gridData.items[coords] = self
	
	# y sort pivot
	position = gridData.coordToPos(coords) + ySortOffset
	#offset = -ySortOffset
	
func pickup() -> void:
	# Remove from grid once picked up
	gridData.items.erase(coords)
	# Add to player inventory
	gridData.inventory.append(self)
	gridData.levelController.organiseInventory()
	
