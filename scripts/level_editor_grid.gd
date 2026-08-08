extends Control
## Draws the level grid and forwards clicks back to the main editor.
## Coordinate convention matches gridData.gd: Vector2(row, column).

var editor: Node # set by LevelEditor after instancing
const CELL := 40 # on-screen pixel size per cell (independent of in-game tileSize)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if not editor:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var col := int(event.position.x / CELL)
		var row := int(event.position.y / CELL)
		if row >= 0 and row < editor.rows and col >= 0 and col < editor.columns:
			editor._on_cell_clicked(Vector2(row, col))

func _draw() -> void:
	if not editor:
		return
	var font := ThemeDB.fallback_font
	for row in range(editor.rows):
		for col in range(editor.columns):
			var coord := Vector2(row, col)
			var rect := Rect2(col * CELL, row * CELL, CELL, CELL)

			var color: Color
			var label: String

			if _vec_in(coord, editor.holes):
				color = Color(0.15, 0.15, 0.15)
				label = ""
			else:
				var occ: Dictionary = editor._describe_cell(coord)
				color = occ.color
				label = occ.label

			draw_rect(rect, color, true)
			draw_rect(rect, Color(0.3, 0.3, 0.3), false, 1.0)
			if label != "":
				draw_string(font, Vector2(rect.position.x + 3, rect.position.y + CELL - 6),
					label, HORIZONTAL_ALIGNMENT_LEFT, CELL - 4, 11, Color.BLACK)

	custom_minimum_size = Vector2(editor.columns * CELL, editor.rows * CELL)

func _vec_in(v: Vector2, arr: Array) -> bool:
	for x in arr:
		if x == v:
			return true
	return false
