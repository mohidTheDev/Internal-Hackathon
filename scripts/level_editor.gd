extends Control
## In-game level editor for the grid puzzle game.
##
## Internal data model uses plain objects with real references (e.g. a battery
## slot points directly at a GateData, not an array index) so entities can be
## freely added/removed/reordered while editing. Parallel-array flattening
## (matching main.gd's @export shape) only happens once, at export time.
##
## Usage: add level_editor.tscn as a scene and run it directly (F6), or wire
## a button in your main menu to switch to it.

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

class GateData:
	var coord: Vector2
	var type: int = 0        # 0 = keyCard, 1 = battery (matches main.gd's gateType enum)
	var orientation: int = 0 # 0 = Horizontal, 1 = Vertical (matches gateDir enum)

class TowerData:
	var coord: Vector2
	var fireUp: bool = true
	var fireDown: bool = true
	var fireLeft: bool = true
	var fireRight: bool = true
	var activeCycle: int = 1
	var inactiveCycle: int = 1

class ItemData:
	var coord: Vector2
	var itemType: int = 0 # 0 = keyCard, 1 = battery

class SlotData:
	var coord: Vector2
	var linkedGate: GateData = null
	var hasBatteryDefault: bool = false

enum Tool {SELECT, HOLE, SPAWN, GOAL, GATE, ITEM, TOWER, SLOT, ERASE}

# ---------------------------------------------------------------------------
# Editor state
# ---------------------------------------------------------------------------

var rows: int = 5
var columns: int = 5
var tileSize: int = 32
var gridYOffset: int = 20
var moveLimit: int = 10
var rewindDuration: int = 5

var goalCoord: Vector2 = Vector2(-1, -1)
var playerSpawnCoord: Vector2 = Vector2(-1, -1)

var holes: Array = []  # Array of Vector2
var gates: Array = []  # Array of GateData
var towers: Array = [] # Array of TowerData
var items: Array = []  # Array of ItemData
var slots: Array = []  # Array of SlotData

var nextLevelPath: String = "" # res:// path to another level .tscn, or ""
var loaded_level_path: String = ""

var current_tool: int = Tool.SELECT
var current_gate_is_battery: bool = false
var current_gate_vertical: bool = false
var current_item_is_battery: bool = false

# ---------------------------------------------------------------------------
# Preloaded resources (must match what main.gd expects to be assigned)
# ---------------------------------------------------------------------------

const TILE_SCENE := preload("res://scenes/tile.tscn")
const WALL_SCENE := preload("res://scenes/wall.tscn")
const HGATE_SCENE := preload("res://scenes/horizontalGate.tscn")
const VGATE_SCENE := preload("res://scenes/verticalGate.tscn")
const BATTERY_SLOT_SCENE := preload("res://scenes/batterySlot.tscn")
const TOWER_SCENE := preload("res://scenes/tower.tscn")
const KEYCARD_ITEM_SCENE := preload("res://scenes/keyCard.tscn")
const BATTERY_ITEM_SCENE := preload("res://scenes/battery.tscn")
const CLOCK_HUD_SCENE := preload("res://scenes/clockHUD.tscn")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const PLAYER_TEXTURE := preload("res://sprites/player.png")
const MAIN_SCRIPT := preload("res://scripts/main.gd")
const GRID_DATA_RES := preload("res://resources/gridData.tres")
const GRID_SCRIPT := preload("res://scripts/level_editor_grid.gd")

# ---------------------------------------------------------------------------
# UI references (built in code in _ready)
# ---------------------------------------------------------------------------

var grid_draw: Control
var entity_list: VBoxContainer
var status_label: Label
var rows_spin: SpinBox
var cols_spin: SpinBox
var move_limit_spin: SpinBox
var rewind_spin: SpinBox
var next_level_option: OptionButton
var gate_battery_check: CheckBox
var gate_vertical_check: CheckBox
var item_battery_check: CheckBox
var save_dialog: FileDialog
var load_dialog: FileDialog
var tool_buttons: Dictionary = {} # Tool -> Button

func _ready() -> void:
	# The project's base viewport is tiny (320x240, for the pixel-art game
	# view) with canvas_items stretch, which makes UI controls look zoomed
	# in and blurry when stretched to fill a normal desktop window. Give
	# this editor scene its own larger, unscaled window instead.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(1400, 900)

	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_ui()
	_refresh_entity_list()

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var root_box := HBoxContainer.new()
	root_box.anchor_right = 1.0
	root_box.anchor_bottom = 1.0
	root_box.offset_right = 0
	root_box.offset_bottom = 0
	add_child(root_box)

	# ---- Left panel: tools + level settings ----
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(260, 0)
	root_box.add_child(left_scroll)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left_scroll.add_child(left)

	left.add_child(_h1("Level Editor"))

	left.add_child(_h2("Grid Size"))
	var grid_row := HBoxContainer.new()
	rows_spin = SpinBox.new(); rows_spin.min_value = 1; rows_spin.max_value = 30; rows_spin.value = rows
	cols_spin = SpinBox.new(); cols_spin.min_value = 1; cols_spin.max_value = 30; cols_spin.value = columns
	grid_row.add_child(_label("Rows")); grid_row.add_child(rows_spin)
	grid_row.add_child(_label("Cols")); grid_row.add_child(cols_spin)
	left.add_child(grid_row)
	var resize_btn := Button.new(); resize_btn.text = "Resize Grid"
	resize_btn.pressed.connect(_resize_grid)
	left.add_child(resize_btn)

	left.add_child(_h2("Tools (click, then click grid)"))
	_add_tool_button(left, "Select / Inspect", Tool.SELECT)
	_add_tool_button(left, "Toggle Hole", Tool.HOLE)
	_add_tool_button(left, "Set Player Spawn", Tool.SPAWN)
	_add_tool_button(left, "Set Goal", Tool.GOAL)
	_add_tool_button(left, "Place Gate", Tool.GATE)
	_add_tool_button(left, "Place Item", Tool.ITEM)
	_add_tool_button(left, "Place Tower", Tool.TOWER)
	_add_tool_button(left, "Place Battery Slot", Tool.SLOT)
	_add_tool_button(left, "Erase", Tool.ERASE)
	_set_tool(Tool.SELECT)

	left.add_child(_h2("Gate options (used when placing)"))
	gate_battery_check = CheckBox.new(); gate_battery_check.text = "Battery gate (unchecked = KeyCard)"
	gate_battery_check.toggled.connect(func(v): current_gate_is_battery = v)
	left.add_child(gate_battery_check)
	gate_vertical_check = CheckBox.new(); gate_vertical_check.text = "Vertical (unchecked = Horizontal)"
	gate_vertical_check.toggled.connect(func(v): current_gate_vertical = v)
	left.add_child(gate_vertical_check)

	left.add_child(_h2("Item options (used when placing)"))
	item_battery_check = CheckBox.new(); item_battery_check.text = "Battery (unchecked = KeyCard)"
	item_battery_check.toggled.connect(func(v): current_item_is_battery = v)
	left.add_child(item_battery_check)

	left.add_child(_h2("Player / Rules"))
	var ml_row := HBoxContainer.new()
	move_limit_spin = SpinBox.new(); move_limit_spin.min_value = 1; move_limit_spin.max_value = 999; move_limit_spin.value = moveLimit
	move_limit_spin.value_changed.connect(func(v): moveLimit = int(v))
	ml_row.add_child(_label("Move limit")); ml_row.add_child(move_limit_spin)
	left.add_child(ml_row)
	var rw_row := HBoxContainer.new()
	rewind_spin = SpinBox.new(); rewind_spin.min_value = 0; rewind_spin.max_value = 999; rewind_spin.value = rewindDuration
	rewind_spin.value_changed.connect(func(v): rewindDuration = int(v))
	rw_row.add_child(_label("Rewind after")); rw_row.add_child(rewind_spin)
	left.add_child(rw_row)

	left.add_child(_h2("Next Level"))
	next_level_option = OptionButton.new()
	_populate_next_level_options()
	next_level_option.item_selected.connect(func(idx):
		nextLevelPath = String(next_level_option.get_item_metadata(idx)))
	left.add_child(next_level_option)

	left.add_child(_h2("File"))
	var new_btn := Button.new(); new_btn.text = "New Level"
	new_btn.pressed.connect(_new_level)
	left.add_child(new_btn)

	var save_btn := Button.new(); save_btn.text = "Save"
	save_btn.pressed.connect(func():
		if loaded_level_path != "":
			_export_level(loaded_level_path)
		else:
			save_dialog.popup_centered_ratio(0.6))
	left.add_child(save_btn)

	var save_as_btn := Button.new(); save_as_btn.text = "Save As..."
	save_as_btn.pressed.connect(func(): save_dialog.popup_centered_ratio(0.6))
	left.add_child(save_as_btn)

	var load_btn := Button.new(); load_btn.text = "Load..."
	load_btn.pressed.connect(func(): load_dialog.popup_centered_ratio(0.6))
	left.add_child(load_btn)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(status_label)

	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_RESOURCES
	save_dialog.add_filter("*.tscn", "Godot Scene")
	save_dialog.current_dir = "res://levels/"
	save_dialog.file_selected.connect(_export_level)
	add_child(save_dialog)

	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_RESOURCES
	load_dialog.add_filter("*.tscn", "Godot Scene")
	load_dialog.current_dir = "res://levels/"
	load_dialog.file_selected.connect(_load_level)
	add_child(load_dialog)

	# ---- Center: grid ----
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(grid_scroll)

	grid_draw = Control.new()
	grid_draw.set_script(GRID_SCRIPT)
	grid_draw.editor = self
	grid_scroll.add_child(grid_draw)

	# ---- Right panel: entity inspector list ----
	var right_scroll := ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(340, 0)
	root_box.add_child(right_scroll)

	entity_list = VBoxContainer.new()
	entity_list.custom_minimum_size = Vector2(330, 0)
	right_scroll.add_child(entity_list)

func _add_tool_button(parent: Control, text: String, tool: int) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.pressed.connect(func(): _set_tool(tool))
	tool_buttons[tool] = b
	parent.add_child(b)

func _set_tool(tool: int) -> void:
	current_tool = tool
	for t in tool_buttons.keys():
		tool_buttons[t].button_pressed = (t == tool)

func _h1(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	return l

func _h2(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	return l

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _populate_next_level_options() -> void:
	next_level_option.clear()
	next_level_option.add_item("(none)")
	next_level_option.set_item_metadata(0, "")
	var dir := DirAccess.open("res://levels/")
	var idx := 1
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".tscn"):
				var path := "res://levels/" + f
				next_level_option.add_item(f)
				next_level_option.set_item_metadata(idx, path)
				idx += 1
			f = dir.get_next()
		dir.list_dir_end()

# ---------------------------------------------------------------------------
# Grid interaction
# ---------------------------------------------------------------------------

func _on_cell_clicked(coord: Vector2) -> void:
	match current_tool:
		Tool.SELECT:
			status_label.text = "Cell (%d,%d): %s" % [coord.x, coord.y, _cell_summary(coord)]
			return
		Tool.HOLE:
			if _vec_index(coord, holes) >= 0:
				holes.remove_at(_vec_index(coord, holes))
			else:
				_clear_cell(coord) # holes can't share a cell with entities
				holes.append(coord)
		Tool.SPAWN:
			playerSpawnCoord = coord
		Tool.GOAL:
			goalCoord = coord
		Tool.GATE:
			if _gate_at(coord) == null and _vec_index(coord, holes) < 0:
				var g := GateData.new()
				g.coord = coord
				g.type = 1 if current_gate_is_battery else 0
				g.orientation = 1 if current_gate_vertical else 0
				gates.append(g)
		Tool.ITEM:
			if _item_at(coord) == null and _vec_index(coord, holes) < 0:
				var it := ItemData.new()
				it.coord = coord
				it.itemType = 1 if current_item_is_battery else 0
				items.append(it)
		Tool.TOWER:
			if _tower_at(coord) == null and _vec_index(coord, holes) < 0:
				var t := TowerData.new()
				t.coord = coord
				towers.append(t)
		Tool.SLOT:
			if _slot_at(coord) == null and _vec_index(coord, holes) < 0:
				var s := SlotData.new()
				s.coord = coord
				slots.append(s)
		Tool.ERASE:
			_clear_cell(coord)
			if _vec_index(coord, holes) >= 0:
				holes.remove_at(_vec_index(coord, holes))
			if playerSpawnCoord == coord:
				playerSpawnCoord = Vector2(-1, -1)
			if goalCoord == coord:
				goalCoord = Vector2(-1, -1)

	_refresh_entity_list()
	grid_draw.queue_redraw()

func _clear_cell(coord: Vector2) -> void:
	var g := _gate_at(coord)
	if g:
		gates.erase(g)
		for s in slots:
			if s.linkedGate == g:
				s.linkedGate = null
	var it := _item_at(coord)
	if it:
		items.erase(it)
	var t := _tower_at(coord)
	if t:
		towers.erase(t)
	var s2 := _slot_at(coord)
	if s2:
		slots.erase(s2)

func _cell_summary(coord: Vector2) -> String:
	if coord == playerSpawnCoord:
		return "Player spawn"
	if coord == goalCoord:
		return "Goal"
	if _vec_index(coord, holes) >= 0:
		return "Hole"
	var g := _gate_at(coord)
	if g:
		return "Gate"
	var t := _tower_at(coord)
	if t:
		return "Tower"
	var s := _slot_at(coord)
	if s:
		return "Battery slot"
	var it := _item_at(coord)
	if it:
		return "Item"
	return "Empty tile"

func _describe_cell(coord: Vector2) -> Dictionary:
	if coord == playerSpawnCoord:
		return {"color": Color(0.2, 0.4, 0.9), "label": "Spawn"}
	if coord == goalCoord:
		return {"color": Color(0.85, 0.7, 0.1), "label": "Goal"}
	var g := _gate_at(coord)
	if g:
		var col: Color = Color(0.1, 0.6, 0.6) if g.type == 0 else Color(0.1, 0.6, 0.1)
		var ori: String = "H" if g.orientation == 0 else "V"
		var typ: String = "Key" if g.type == 0 else "Batt"
		return {"color": col, "label": "Gate %s-%s" % [ori, typ]}
	var t := _tower_at(coord)
	if t:
		return {"color": Color(0.8, 0.15, 0.15), "label": "Tower"}
	var s := _slot_at(coord)
	if s:
		return {"color": Color(0.55, 0.25, 0.75), "label": "Slot"}
	var it := _item_at(coord)
	if it:
		var lbl: String = "Key" if it.itemType == 0 else "Batt"
		return {"color": Color(0.9, 0.75, 0.2), "label": lbl}
	return {"color": Color(0.85, 0.85, 0.85), "label": ""}

func _gate_at(coord: Vector2) -> GateData:
	for g in gates:
		if g.coord == coord:
			return g
	return null

func _item_at(coord: Vector2) -> ItemData:
	for it in items:
		if it.coord == coord:
			return it
	return null

func _tower_at(coord: Vector2) -> TowerData:
	for t in towers:
		if t.coord == coord:
			return t
	return null

func _slot_at(coord: Vector2) -> SlotData:
	for s in slots:
		if s.coord == coord:
			return s
	return null

func _vec_index(v: Vector2, arr: Array) -> int:
	for i in range(arr.size()):
		if arr[i] == v:
			return i
	return -1

# ---------------------------------------------------------------------------
# Entity inspector list (right panel)
# ---------------------------------------------------------------------------

func _refresh_entity_list() -> void:
	for c in entity_list.get_children():
		c.queue_free()

	entity_list.add_child(_h2("Gates (%d)" % gates.size()))
	for g in gates:
		entity_list.add_child(_build_gate_row(g))

	entity_list.add_child(_h2("Towers (%d)" % towers.size()))
	for t in towers:
		entity_list.add_child(_build_tower_row(t))

	entity_list.add_child(_h2("Items (%d)" % items.size()))
	for it in items:
		entity_list.add_child(_build_item_row(it))

	entity_list.add_child(_h2("Battery Slots (%d)" % slots.size()))
	for s in slots:
		entity_list.add_child(_build_slot_row(s))

func _row_container() -> PanelContainer:
	var p := PanelContainer.new()
	var box := VBoxContainer.new()
	p.add_child(box)
	p.set_meta("box", box)
	return p

func _build_gate_row(g: GateData) -> Control:
	var p := _row_container()
	var box: VBoxContainer = p.get_meta("box")
	box.add_child(_label("Coord (%d,%d)" % [g.coord.x, g.coord.y]))

	var r1 := HBoxContainer.new()
	var type_btn := OptionButton.new()
	type_btn.add_item("KeyCard"); type_btn.add_item("Battery")
	type_btn.select(g.type)
	type_btn.item_selected.connect(func(idx): g.type = idx; grid_draw.queue_redraw())
	r1.add_child(type_btn)

	var ori_btn := OptionButton.new()
	ori_btn.add_item("Horizontal"); ori_btn.add_item("Vertical")
	ori_btn.select(g.orientation)
	ori_btn.item_selected.connect(func(idx): g.orientation = idx; grid_draw.queue_redraw())
	r1.add_child(ori_btn)
	box.add_child(r1)

	var del_btn := Button.new(); del_btn.text = "Delete Gate"
	del_btn.pressed.connect(func():
		gates.erase(g)
		for s in slots:
			if s.linkedGate == g:
				s.linkedGate = null
		_refresh_entity_list(); grid_draw.queue_redraw())
	box.add_child(del_btn)
	return p

func _build_tower_row(t: TowerData) -> Control:
	var p := _row_container()
	var box: VBoxContainer = p.get_meta("box")
	box.add_child(_label("Coord (%d,%d)" % [t.coord.x, t.coord.y]))

	var dir_row := HBoxContainer.new()
	var up := CheckBox.new(); up.text = "Up"; up.button_pressed = t.fireUp
	up.toggled.connect(func(v): t.fireUp = v)
	var down := CheckBox.new(); down.text = "Down"; down.button_pressed = t.fireDown
	down.toggled.connect(func(v): t.fireDown = v)
	var left := CheckBox.new(); left.text = "Left"; left.button_pressed = t.fireLeft
	left.toggled.connect(func(v): t.fireLeft = v)
	var right := CheckBox.new(); right.text = "Right"; right.button_pressed = t.fireRight
	right.toggled.connect(func(v): t.fireRight = v)
	dir_row.add_child(up); dir_row.add_child(down); dir_row.add_child(left); dir_row.add_child(right)
	box.add_child(dir_row)

	var cyc_row := HBoxContainer.new()
	var active_spin := SpinBox.new(); active_spin.min_value = 0; active_spin.max_value = 99; active_spin.value = t.activeCycle
	active_spin.value_changed.connect(func(v): t.activeCycle = int(v))
	var inactive_spin := SpinBox.new(); inactive_spin.min_value = 0; inactive_spin.max_value = 99; inactive_spin.value = t.inactiveCycle
	inactive_spin.value_changed.connect(func(v): t.inactiveCycle = int(v))
	cyc_row.add_child(_label("Active")); cyc_row.add_child(active_spin)
	cyc_row.add_child(_label("Inactive")); cyc_row.add_child(inactive_spin)
	box.add_child(cyc_row)

	var del_btn := Button.new(); del_btn.text = "Delete Tower"
	del_btn.pressed.connect(func():
		towers.erase(t); _refresh_entity_list(); grid_draw.queue_redraw())
	box.add_child(del_btn)
	return p

func _build_item_row(it: ItemData) -> Control:
	var p := _row_container()
	var box: VBoxContainer = p.get_meta("box")
	box.add_child(_label("Coord (%d,%d)" % [it.coord.x, it.coord.y]))

	var type_btn := OptionButton.new()
	type_btn.add_item("KeyCard"); type_btn.add_item("Battery")
	type_btn.select(it.itemType)
	type_btn.item_selected.connect(func(idx): it.itemType = idx; grid_draw.queue_redraw())
	box.add_child(type_btn)

	var del_btn := Button.new(); del_btn.text = "Delete Item"
	del_btn.pressed.connect(func():
		items.erase(it); _refresh_entity_list(); grid_draw.queue_redraw())
	box.add_child(del_btn)
	return p

func _build_slot_row(s: SlotData) -> Control:
	var p := _row_container()
	var box: VBoxContainer = p.get_meta("box")
	box.add_child(_label("Coord (%d,%d)" % [s.coord.x, s.coord.y]))

	var gate_opt := OptionButton.new()
	gate_opt.add_item("(no linked gate)")
	gate_opt.set_item_metadata(0, null)
	var select_idx := 0
	for i in range(gates.size()):
		var g = gates[i]
		gate_opt.add_item("Gate @ (%d,%d)" % [g.coord.x, g.coord.y])
		gate_opt.set_item_metadata(i + 1, g)
		if s.linkedGate == g:
			select_idx = i + 1
	gate_opt.select(select_idx)
	gate_opt.item_selected.connect(func(idx): s.linkedGate = gate_opt.get_item_metadata(idx))
	box.add_child(gate_opt)

	var default_check := CheckBox.new(); default_check.text = "Has battery by default"
	default_check.button_pressed = s.hasBatteryDefault
	default_check.toggled.connect(func(v): s.hasBatteryDefault = v)
	box.add_child(default_check)

	var del_btn := Button.new(); del_btn.text = "Delete Slot"
	del_btn.pressed.connect(func():
		slots.erase(s); _refresh_entity_list(); grid_draw.queue_redraw())
	box.add_child(del_btn)
	return p

# ---------------------------------------------------------------------------
# Grid resize / new level
# ---------------------------------------------------------------------------

func _resize_grid() -> void:
	rows = int(rows_spin.value)
	columns = int(cols_spin.value)
	holes = holes.filter(func(c): return c.x < rows and c.y < columns)
	gates = gates.filter(func(g): return g.coord.x < rows and g.coord.y < columns)
	towers = towers.filter(func(t): return t.coord.x < rows and t.coord.y < columns)
	items = items.filter(func(i): return i.coord.x < rows and i.coord.y < columns)
	slots = slots.filter(func(s): return s.coord.x < rows and s.coord.y < columns)
	if playerSpawnCoord.x >= rows or playerSpawnCoord.y >= columns:
		playerSpawnCoord = Vector2(-1, -1)
	if goalCoord.x >= rows or goalCoord.y >= columns:
		goalCoord = Vector2(-1, -1)
	_refresh_entity_list()
	grid_draw.queue_redraw()

func _new_level() -> void:
	rows = 5; columns = 5
	rows_spin.value = 5; cols_spin.value = 5
	holes.clear(); gates.clear(); towers.clear(); items.clear(); slots.clear()
	goalCoord = Vector2(-1, -1)
	playerSpawnCoord = Vector2(-1, -1)
	nextLevelPath = ""
	loaded_level_path = ""
	next_level_option.select(0)
	_refresh_entity_list()
	grid_draw.queue_redraw()
	status_label.text = "New level"

# ---------------------------------------------------------------------------
# Export: build the node tree main.gd expects, pack it, save as .tscn
# ---------------------------------------------------------------------------

func _export_level(path: String) -> void:
	if playerSpawnCoord.x < 0:
		status_label.text = "Set a player spawn before saving."
		return
	if goalCoord.x < 0:
		status_label.text = "Set a goal before saving."
		return

	var root := Node2D.new()
	root.name = "Node2D"
	root.set_script(MAIN_SCRIPT)
	root.y_sort_enabled = true

	root.rows = rows
	root.columns = columns
	root.tileSize = tileSize
	root.gridYOffset = gridYOffset
	root.moveLimit = moveLimit
	root.rewindDuration = rewindDuration
	root.goalCoord = goalCoord
	root.playerSpawnCoord = playerSpawnCoord
	var typed_holes: Array[Vector2] = []
	for h in holes:
		typed_holes.append(h)
	root.gridHoles = typed_holes
	root.gridData = GRID_DATA_RES

	root.tile = TILE_SCENE
	root.wall = WALL_SCENE
	root.horizontalGate = HGATE_SCENE
	root.verticalGate = VGATE_SCENE
	root.batterySlotScene = BATTERY_SLOT_SCENE
	root.towerScene = TOWER_SCENE
	root.batteryItemScene = BATTERY_ITEM_SCENE

	if nextLevelPath != "" and ResourceLoader.exists(nextLevelPath):
		root.nextLevel = load(nextLevelPath)

	var gates_type: Array[int] = []
	var gates_orientation: Array[int] = []
	var gates_coords: Array[Vector2] = []
	for g in gates:
		gates_type.append(g.type)
		gates_orientation.append(g.orientation)
		gates_coords.append(g.coord)
	root.gates = gates_type
	root.gatesOrientation = gates_orientation
	root.gatesCoords = gates_coords

	var item_scenes: Array[PackedScene] = []
	var item_coords: Array[Vector2] = []
	for it in items:
		item_scenes.append(KEYCARD_ITEM_SCENE if it.itemType == 0 else BATTERY_ITEM_SCENE)
		item_coords.append(it.coord)
	root.pickableItems = item_scenes
	root.pickableItemsCoords = item_coords

	var t_coords: Array[Vector2] = []
	var t_up: Array[bool] = []; var t_down: Array[bool] = []
	var t_left: Array[bool] = []; var t_right: Array[bool] = []
	var t_active: Array[int] = []; var t_inactive: Array[int] = []
	for t in towers:
		t_coords.append(t.coord)
		t_up.append(t.fireUp); t_down.append(t.fireDown)
		t_left.append(t.fireLeft); t_right.append(t.fireRight)
		t_active.append(t.activeCycle); t_inactive.append(t.inactiveCycle)
	root.towerCoords = t_coords
	root.towerFireUp = t_up
	root.towerFireDown = t_down
	root.towerFireLeft = t_left
	root.towerFireRight = t_right
	root.towerActiveCycle = t_active
	root.towerInactiveCycle = t_inactive

	var s_coords: Array[Vector2] = []
	var s_gate_idx: Array[int] = []; var s_default: Array[bool] = []
	for s in slots:
		s_coords.append(s.coord)
		var idx := -1
		if s.linkedGate != null:
			idx = gates.find(s.linkedGate)
		s_gate_idx.append(idx)
		s_default.append(s.hasBatteryDefault)
	root.batterySlotCoords = s_coords
	root.batterySlotGateIndex = s_gate_idx
	root.batterySlotHasBatteryByDefault = s_default

	# --- required child node tree (main.gd looks these up by name) ---
	_add_holder(root, "Walls Holder")
	var tiles_holder := _add_holder(root, "Tiles Holder")
	tiles_holder.modulate = Color(0.6321235, 0.6321235, 0.6321234, 1)
	tiles_holder.z_index = -1
	var items_holder := _add_holder(root, "Items Holder")
	items_holder.y_sort_enabled = true
	var gates_holder := _add_holder(root, "Gates Holder")
	gates_holder.y_sort_enabled = true
	_add_holder(root, "Slots Holder")
	_add_holder(root, "Towers Holder")

	var player := Sprite2D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.y_sort_enabled = true
	player.scale = Vector2(1.5, 1.5)
	player.texture = PLAYER_TEXTURE
	player.offset = Vector2(0, -16)
	player.hframes = 2
	player.vframes = 3
	player.set("gridData", GRID_DATA_RES)
	player.set("moveTime", 0.2)
	player.set("animTime", 0.5)
	player.set("ySortOffset", Vector2(0, 24))
	root.add_child(player)
	player.owner = root

	var clock := CLOCK_HUD_SCENE.instantiate()
	clock.name = "Clock"
	# NOTE: rough default placement — nudge this in-editor to match your HUD layout.
	clock.position = Vector2(tileSize * columns / 2.0 + 112, gridYOffset + 4)
	root.add_child(clock)
	clock.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		status_label.text = "Export failed (pack error %d)" % err
		root.queue_free()
		return

	var save_err := ResourceSaver.save(packed, path)
	root.queue_free()
	if save_err != OK:
		status_label.text = "Export failed (save error %d)" % save_err
	else:
		status_label.text = "Saved: %s" % path
		loaded_level_path = path
		_populate_next_level_options()

func _add_holder(root: Node2D, holder_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = holder_name
	root.add_child(n)
	n.owner = root
	return n

# ---------------------------------------------------------------------------
# Load an existing level .tscn back into the editor
# ---------------------------------------------------------------------------

func _load_level(path: String) -> void:
	if not ResourceLoader.exists(path):
		status_label.text = "File not found: %s" % path
		return

	var scene: PackedScene = load(path)
	var inst = scene.instantiate() # not added to the tree, so _ready/_enter_tree won't fire

	rows = inst.rows
	columns = inst.columns
	tileSize = inst.tileSize
	gridYOffset = inst.gridYOffset
	moveLimit = inst.moveLimit
	rewindDuration = inst.rewindDuration
	goalCoord = inst.goalCoord
	playerSpawnCoord = inst.playerSpawnCoord
	holes = inst.gridHoles.duplicate()

	rows_spin.value = rows
	cols_spin.value = columns
	move_limit_spin.value = moveLimit
	rewind_spin.value = rewindDuration

	gates.clear()
	for i in range(inst.gatesCoords.size()):
		var g := GateData.new()
		g.coord = inst.gatesCoords[i]
		g.type = inst.gates[i]
		g.orientation = inst.gatesOrientation[i]
		gates.append(g)

	items.clear()
	for i in range(inst.pickableItemsCoords.size()):
		var it := ItemData.new()
		it.coord = inst.pickableItemsCoords[i]
		it.itemType = 0 if inst.pickableItems[i] == KEYCARD_ITEM_SCENE else 1
		items.append(it)

	towers.clear()
	for i in range(inst.towerCoords.size()):
		var t := TowerData.new()
		t.coord = inst.towerCoords[i]
		t.fireUp = inst.towerFireUp[i] if i < inst.towerFireUp.size() else true
		t.fireDown = inst.towerFireDown[i] if i < inst.towerFireDown.size() else true
		t.fireLeft = inst.towerFireLeft[i] if i < inst.towerFireLeft.size() else true
		t.fireRight = inst.towerFireRight[i] if i < inst.towerFireRight.size() else true
		t.activeCycle = inst.towerActiveCycle[i] if i < inst.towerActiveCycle.size() else 1
		t.inactiveCycle = inst.towerInactiveCycle[i] if i < inst.towerInactiveCycle.size() else 1
		towers.append(t)

	slots.clear()
	for i in range(inst.batterySlotCoords.size()):
		var s := SlotData.new()
		s.coord = inst.batterySlotCoords[i]
		var gidx: int = inst.batterySlotGateIndex[i] if i < inst.batterySlotGateIndex.size() else -1
		if gidx >= 0 and gidx < gates.size():
			s.linkedGate = gates[gidx]
		s.hasBatteryDefault = inst.batterySlotHasBatteryByDefault[i] if i < inst.batterySlotHasBatteryByDefault.size() else false
		slots.append(s)

	nextLevelPath = inst.nextLevel.resource_path if inst.nextLevel else ""
	loaded_level_path = path

	inst.queue_free()
	_populate_next_level_options()
	_refresh_entity_list()
	grid_draw.queue_redraw()
	status_label.text = "Loaded: %s" % path
