extends CanvasLayer

# ─── Configuration ───────────────────────────────────────────────
const MAX_MESSAGES     := 15
const MESSAGE_DURATION := 5.0
const BASE_RESOLUTION  := Vector2(1920.0, 1080.0)

const BASE_FONT_SIZE         := 16
const BASE_PANEL_WIDTH_LOG   := 340.0
const BASE_PANEL_WIDTH_WATCH := 280.0
const BASE_PANEL_OFFSET      := 10.0
const BASE_BADGE_FONT_SIZE   := 12
const BASE_CORNER_RADIUS     := 6
const BASE_CONTENT_MARGIN    := 8.0
const BASE_SEPARATION        := 2

const COLORS := {
	"info":    Color(0.9, 0.9, 0.9),
	"success": Color(0.3, 1.0, 0.4),
	"warning": Color(1.0, 0.85, 0.2),
	"error":   Color(1.0, 0.3, 0.3),
	"debug":   Color(0.5, 0.8, 1.0),
	"watch":   Color(1.0, 0.75, 0.3),
}

# ─── Panels position ─────────────────────────────────────────────
enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }

# Vars to define the position of the panels
var log_corner:   int = Corner.TOP_LEFT
var watch_corner: int = Corner.TOP_RIGHT

# ─── Private variables ───────────────────────────────────────────
var _log_container:      VBoxContainer
var _watch_container:    VBoxContainer
var _left_panel:         PanelContainer
var _right_panel:        PanelContainer
var _messages:           Array = []
var _watches:            Dictionary = {}
var _last_viewport_size: Vector2 = Vector2.ZERO

# ═════════════════════════════════════════════════════════════════
#  Scale helpers  (defined before _setup_ui)
# ═════════════════════════════════════════════════════════════════

func _get_viewport_size() -> Vector2:
	return get_tree().root.get_visible_rect().size

func _get_scale_factor() -> float:
	var vp := _get_viewport_size()
	var sx  := vp.x / BASE_RESOLUTION.x
	var sy  := vp.y / BASE_RESOLUTION.y
	return clampf(minf(sx, sy), 0.4, 3.0)

func _scaled(base_value: float) -> int:
	return roundi(base_value * _get_scale_factor())

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	for c in ["corner_radius_top_left", "corner_radius_top_right",
			  "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		style.set(c, BASE_CORNER_RADIUS)
	style.content_margin_left   = BASE_CONTENT_MARGIN
	style.content_margin_right  = BASE_CONTENT_MARGIN
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _apply_panel_style(panel: PanelContainer, margin: int, corner: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	for c in ["corner_radius_top_left", "corner_radius_top_right",
			  "corner_radius_bottom_left", "corner_radius_bottom_right"]:
		style.set(c, corner)
	style.content_margin_left   = margin
	style.content_margin_right  = margin
	style.content_margin_top    = roundi(6 * _get_scale_factor())
	style.content_margin_bottom = roundi(6 * _get_scale_factor())
	panel.add_theme_stylebox_override("panel", style)

func _apply_badge_style(badge: Label) -> void:
	var s     := _get_scale_factor()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.45, 0.1)
	var radius := roundi(10 * s)
	style.corner_radius_top_left     = radius
	style.corner_radius_top_right    = radius
	style.corner_radius_bottom_left  = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left   = roundi(5 * s)
	style.content_margin_right  = roundi(5 * s)
	style.content_margin_top    = roundi(1 * s)
	style.content_margin_bottom = roundi(1 * s)
	badge.add_theme_stylebox_override("normal", style)

func _format_value(v: Variant) -> String:
	if v is Vector2:
		return "(%.2f, %.2f)" % [v.x, v.y]
	if v is Vector3:
		return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
	return str(v)

# ═════════════════════════════════════════════════════════════════
#  Life cicle
# ═════════════════════════════════════════════════════════════════

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	layer = 128
	_setup_ui()
	_last_viewport_size = _get_viewport_size()
	get_tree().root.size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	var new_size := _get_viewport_size()
	if new_size == _last_viewport_size:
		return
	_last_viewport_size = new_size
	_rebuild_layout()

func _corner_position(corner: int, panel_width: float, offset: int, panel_height: float = 0.0) -> Vector2:
	var vp := _get_viewport_size()
	match corner:
		Corner.TOP_LEFT:
			return Vector2(offset, offset)
		Corner.TOP_RIGHT:
			return Vector2(vp.x - panel_width - offset, offset)
		Corner.BOTTOM_LEFT:
			return Vector2(offset, vp.y - panel_height - offset)
		Corner.BOTTOM_RIGHT:
			return Vector2(vp.x - panel_width - offset, vp.y - panel_height - offset)
	return Vector2(offset, offset)

# ═════════════════════════════════════════════════════════════════
#  UI build
# ═════════════════════════════════════════════════════════════════

func _setup_ui() -> void:
	_left_panel  = _make_panel()
	_right_panel = _make_panel()
	add_child(_left_panel)
	add_child(_right_panel)

	_log_container = VBoxContainer.new()
	_left_panel.add_child(_log_container)

	_watch_container = VBoxContainer.new()
	_right_panel.add_child(_watch_container)

	_rebuild_layout()

func _rebuild_layout() -> void:
	# Dejamos que Godot procese el layout primero para tener size.y real
	await get_tree().process_frame
	_apply_layout()

func _apply_layout() -> void:
	var s      := _get_scale_factor()
	var offset := roundi(BASE_PANEL_OFFSET * s)
	var margin := roundi(BASE_CONTENT_MARGIN * s)
	var corner := roundi(BASE_CORNER_RADIUS * s)
	var sep    := roundi(BASE_SEPARATION * s)
	var gap    := roundi(8.0 * s)

	var w_log   := roundi(BASE_PANEL_WIDTH_LOG * s)
	var w_watch := roundi(BASE_PANEL_WIDTH_WATCH * s)
	var h_log   := _left_panel.size.y
	var h_watch := _right_panel.size.y

	var log_pos   := _corner_position(log_corner,   w_log,   offset, h_log)
	var watch_pos := _corner_position(watch_corner, w_watch, offset, h_watch)

	# ── Resolver solapamiento ────────────────────────────────────
	if log_corner == watch_corner:
		# Misma esquina exacta: colocar uno al lado del otro
		match log_corner:
			Corner.TOP_LEFT, Corner.BOTTOM_LEFT:
				watch_pos.x = log_pos.x + w_log + gap
			Corner.TOP_RIGHT, Corner.BOTTOM_RIGHT:
				log_pos.x = watch_pos.x - w_log - gap
	else:
		var log_is_top   := log_corner   in [Corner.TOP_LEFT,  Corner.TOP_RIGHT]
		var watch_is_top := watch_corner in [Corner.TOP_LEFT,  Corner.TOP_RIGHT]
		var same_row     := log_is_top  == watch_is_top

		if same_row:
			# Detectar cuál panel está a la izquierda y cuál a la derecha
			var left_x: float
			var left_w: int
			var right_x: float

			if log_pos.x <= watch_pos.x:
				left_x  = log_pos.x
				left_w  = w_log
				right_x = watch_pos.x
			else:
				left_x  = watch_pos.x
				left_w  = w_watch
				right_x = log_pos.x

			var overlap := (left_x + left_w + gap) - right_x

			if overlap > 0:
				if log_pos.x <= watch_pos.x:
					watch_pos.x += overlap
				else:
					log_pos.x += overlap

	# ── Apply ──────────────────────────────────────────────────
	_left_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_left_panel.position = log_pos
	_left_panel.custom_minimum_size = Vector2(w_log, 0)
	_apply_panel_style(_left_panel, margin, corner)
	_log_container.add_theme_constant_override("separation", sep)

	_right_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_right_panel.position = watch_pos
	_right_panel.custom_minimum_size = Vector2(w_watch, 0)
	_apply_panel_style(_right_panel, margin, corner)
	_watch_container.add_theme_constant_override("separation", roundi(3 * s))

	_rescale_existing_labels()

func _rescale_existing_labels() -> void:
	var fs       := _scaled(BASE_FONT_SIZE)
	var fs_badge := _scaled(BASE_BADGE_FONT_SIZE)

	for entry in _messages:
		if is_instance_valid(entry.text_label):
			entry.text_label.add_theme_font_size_override("font_size", fs)
		if is_instance_valid(entry.badge) and entry.badge.visible:
			entry.badge.add_theme_font_size_override("font_size", fs_badge)
			_apply_badge_style(entry.badge)

	for key in _watches:
		var w :Dictionary = _watches[key]
		if is_instance_valid(w.row):
			for child in w.row.get_children():
				if child is Label:
					child.add_theme_font_size_override("font_size", fs)

# ═════════════════════════════════════════════════════════════════
#  API PUBLIC — Efemeral logs
# ═════════════════════════════════════════════════════════════════

func info(message: String)    -> void: _add_message("[INFO] " + message, COLORS.info)
func success(message: String) -> void: _add_message("[OK]   " + message, COLORS.success)
func warning(message: String) -> void: _add_message("[WARN] " + message, COLORS.warning)
func error(message: String)   -> void: _add_message("[ERR]  " + message, COLORS.error)
func debug(message: String)   -> void: _add_message("[DBG]  " + message, COLORS.debug)

func log(label: String, value: Variant = "") -> void:
	_add_message(label + ": " + str(value), COLORS.info)

func clear_logs() -> void:
	for entry in _messages:
		if is_instance_valid(entry.row):
			entry.row.queue_free()
	_messages.clear()

# ═════════════════════════════════════════════════════════════════
#  API PUBLIC — Watch
# ═════════════════════════════════════════════════════════════════

func watch(key: String, value: Variant, icon: String = "") -> void:
	if Engine.is_editor_hint():
		return

	var display_value := _format_value(value)
	var fs := _scaled(BASE_FONT_SIZE)

	if _watches.has(key):
		_watches[key].value_label.text = display_value
		var tween := create_tween()
		tween.tween_property(_watches[key].value_label,
				"theme_override_colors/font_color", Color(1.0, 1.0, 0.4), 0.05)
		tween.tween_property(_watches[key].value_label,
				"theme_override_colors/font_color", COLORS.watch, 0.2)
	else:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", _scaled(6))

		var key_label := Label.new()
		key_label.text = (icon + " " if icon != "" else "") + key
		key_label.add_theme_font_size_override("font_size", fs)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(key_label)

		var val_label := Label.new()
		val_label.text = display_value
		val_label.add_theme_font_size_override("font_size", fs)
		val_label.add_theme_color_override("font_color", COLORS.watch)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_label)

		_watch_container.add_child(row)
		_watches[key] = { "row": row, "value_label": val_label }
		_reanchor_bottom_panels()   # ← añade esta línea

func unwatch(key: String) -> void:
	if _watches.has(key):
		_watches[key].row.queue_free()
		_watches.erase(key)

func clear_watches() -> void:
	for key in _watches.keys():
		_watches[key].row.queue_free()
	_watches.clear()

# ═════════════════════════════════════════════════════════════════
#  API PUBLIC — Conditional Logs
#  Only show the message if the condition is true
# ═════════════════════════════════════════════════════════════════

func log_if(condition: bool, message: String) -> void:
	if condition:
		_add_message("[INFO] " + message, COLORS.info)

func info_if(condition: bool, message: String) -> void:
	if condition:
		info(message)

func success_if(condition: bool, message: String) -> void:
	if condition:
		success(message)

func warning_if(condition: bool, message: String) -> void:
	if condition:
		warning(message)

func error_if(condition: bool, message: String) -> void:
	if condition:
		error(message)

func debug_if(condition: bool, message: String) -> void:
	if condition:
		debug(message)

## Shows the message with the corresponding type of the condition
## Useful to show OK/FAIL when checking in one line.
##
##   ScreenLog.log_ok(is_on_floor(), "On ground")
##   → "[OK]  On ground"  if true
##   → "[ERR] On ground"  if false
func log_ok(condition: bool, message: String) -> void:
	if condition:
		success(message)
	else:
		error(message)

## Shows the message with the corresponding type of the condition
## Useful to show OK/WARNING when checking in one line.
##
##   ScreenLog.log_warn(velocity.length() < 500.0, "Nomral speed")
func log_warn(condition: bool, message: String) -> void:
	if condition:
		success(message)
	else:
		warning(message)

# ═════════════════════════════════════════════════════════════════
#  API PUBLIC — Panels positions
# ═════════════════════════════════════════════════════════════════

## Move the logs panel to a corner.
## ScreenLog.set_log_corner(ScreenLog.Corner.BOTTOM_LEFT)
func set_log_corner(corner: int) -> void:
	log_corner = corner
	_rebuild_layout()

## Moves the watch logs to a corner.
## ScreenLog.set_watch_corner(ScreenLog.Corner.BOTTOM_RIGHT)
func set_watch_corner(corner: int) -> void:
	watch_corner = corner
	_rebuild_layout()

## Move both panels to a corner.
## ScreenLog.set_corners(ScreenLog.Corner.BOTTOM_LEFT, ScreenLog.Corner.BOTTOM_RIGHT)
func set_corners(log_c: int, watch_c: int) -> void:
	log_corner   = log_c
	watch_corner = watch_c
	_rebuild_layout()

# ═════════════════════════════════════════════════════════════════
#  Logic — Agrupation messages
# ═════════════════════════════════════════════════════════════════

func _add_message(text: String, color: Color) -> void:
	if Engine.is_editor_hint():
		return

	if _messages.size() > 0:
		var last: Dictionary = _messages.back()
		if last.text == text:
			_increment_count(last)
			return

	if _messages.size() >= MAX_MESSAGES:
		var oldest: Dictionary = _messages.pop_front()
		_destroy_entry(oldest)

	var fs  := _scaled(BASE_FONT_SIZE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _scaled(5))
	row.modulate.a = 0.0

	var text_label := Label.new()
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", fs)
	text_label.add_theme_color_override("font_color", color)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_label)

	var badge := _make_badge()
	badge.visible = false
	row.add_child(badge)

	_log_container.add_child(row)

	var entry := {
		"text":       text,
		"color":      color,
		"count":      1,
		"row":        row,
		"text_label": text_label,
		"badge":      badge,
		"tween":      null,
	}
	_messages.append(entry)
	_start_timer(entry)
	_messages.append(entry)
	_start_timer(entry)
	_reanchor_bottom_panels()

func _make_badge() -> Label:
	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", _scaled(BASE_BADGE_FONT_SIZE))
	badge.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_apply_badge_style(badge)
	return badge

func _increment_count(entry: Dictionary) -> void:
	entry.count += 1
	entry.badge.text    = "×%d" % entry.count
	entry.badge.visible = true
	_start_timer(entry)

	var tween := create_tween()
	tween.tween_property(entry.badge, "scale", Vector2(1.3, 1.3), 0.06) \
		 .set_ease(Tween.EASE_OUT)
	tween.tween_property(entry.badge, "scale", Vector2(1.0, 1.0), 0.12) \
		 .set_ease(Tween.EASE_IN_OUT)

	entry.row.modulate.a = 1.0

func _start_timer(entry: Dictionary) -> void:
	if entry.tween != null and entry.tween.is_valid():
		entry.tween.kill()

	var tween := create_tween()
	entry.tween = tween

	if entry.row.modulate.a < 1.0:
		tween.tween_property(entry.row, "modulate:a", 1.0, 0.15)

	tween.tween_interval(MESSAGE_DURATION)
	tween.tween_property(entry.row, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		_messages.erase(entry)
		if is_instance_valid(entry.row):
			entry.row.queue_free()
	)

func _destroy_entry(entry: Dictionary) -> void:
	if entry.tween != null and entry.tween.is_valid():
		entry.tween.kill()
	if is_instance_valid(entry.row):
		entry.row.queue_free()

# Recalculate the Y position of the BOTTOM panels without waiting for a frame.
# Its called every time the content size changes to keep them sttached to the border.
func _reanchor_bottom_panels() -> void:
	await get_tree().process_frame   # esperar a que size.y se actualice

	var s      := _get_scale_factor()
	var offset := roundi(BASE_PANEL_OFFSET * s)
	var vp     := _get_viewport_size()

	if log_corner in [Corner.BOTTOM_LEFT, Corner.BOTTOM_RIGHT]:
		_left_panel.position.y = vp.y - _left_panel.size.y - offset

	if watch_corner in [Corner.BOTTOM_LEFT, Corner.BOTTOM_RIGHT]:
		_right_panel.position.y = vp.y - _right_panel.size.y - offset
