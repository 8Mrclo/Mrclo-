class_name UIKit
extends RefCounted
## Builders for consistent UI widgets. Every visible string must be passed in
## already localized (via Loc), never hard-coded here.

const MIN_TOUCH := 64.0


static func box(bg_color: Color, border_color: Color, border_w: int, radius: int, skew_corner: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_w)
	# Asymmetric corners give the modular "diagonal panel" identity.
	sb.corner_radius_top_left = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_top_right = int(radius * 0.35) if skew_corner else radius
	sb.corner_radius_bottom_left = int(radius * 0.35) if skew_corner else radius
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	return sb


static func label(text: String, size: int = 24, color: Color = Color(0, 0, 0, 0), wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String) -> Label:
	var l := label(text, 34, Palette.text())
	l.add_theme_color_override("font_outline_color", Palette.PETROL_DEEP)
	l.add_theme_constant_override("outline_size", 6)
	return l


## kind: "primary" | "secondary" | "danger" | "ghost"
static func button(text: String, on_press: Callable, kind: String = "secondary", min_h: float = MIN_TOUCH) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(MIN_TOUCH, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var accent := Palette.TEAL
	match kind:
		"primary":
			accent = Palette.AMBER
			b.add_theme_stylebox_override("normal", box(Palette.CORAL.darkened(0.15), Palette.AMBER, 3, 22))
			b.add_theme_stylebox_override("hover", box(Palette.CORAL, Color.WHITE, 3, 22))
			b.add_theme_stylebox_override("pressed", box(Palette.CORAL.darkened(0.35), Palette.AMBER, 4, 22))
			b.add_theme_font_size_override("font_size", 30)
			b.add_theme_color_override("font_color", Color.WHITE)
		"danger":
			b.add_theme_stylebox_override("normal", box(Palette.DANGER.darkened(0.45), Palette.DANGER, 2, 16))
			b.add_theme_stylebox_override("hover", box(Palette.DANGER.darkened(0.3), Color.WHITE, 2, 16))
		"ghost":
			b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0.15), Palette.border(), 1, 14))
	if on_press.is_valid():
		b.pressed.connect(func():
			Audio.play_ui(&"click")
			Settings.vibrate(12)
			on_press.call())
	b.button_down.connect(func(): if not bool(Settings.get_value("reduce_motion")): b.scale = Vector2(0.97, 0.97))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	return b


static func panel(content: Control = null, bg_color: Color = Color(0, 0, 0, 0), border_color: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	if bg_color.a > 0.0 or border_color.a > 0.0:
		p.add_theme_stylebox_override("panel", box(bg_color if bg_color.a > 0 else Palette.panel_bg(), border_color if border_color.a > 0 else Palette.border(), 2, 18))
	if content:
		p.add_child(content)
	return p


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h: float = 0.0, expand: bool = true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func progress(value: float, max_value: float, color: Color = Palette.TEAL, h: float = 18.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = maxf(max_value, 0.0001)
	p.value = clampf(value, 0.0, p.max_value)
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 0, 8, false))
	return p


static func icon(shape: String, color: Color, size: float = 56.0, ring: Color = Color(0, 0, 0, 0)) -> ShapeIcon:
	var ic := ShapeIcon.new()
	ic.shape = shape
	ic.color = color
	ic.ring = ring
	ic.custom_minimum_size = Vector2(size, size)
	return ic


static func icon_from(def: Dictionary, size: float = 56.0, ring: Color = Color(0, 0, 0, 0)) -> ShapeIcon:
	var ic: Dictionary = def.get("icon", {})
	return icon(str(ic.get("shape", "")), JsonUtil.color(ic.get("color", ""), Palette.TEAL), size, ring)


## Inline cost/reward chips: {"scrap": 100, "prisms": 5}
static func amounts_row(amounts: Dictionary, size: int = 22, check_afford: bool = false) -> HBoxContainer:
	var row := hbox(10)
	for c in amounts:
		if not amounts[c] is float and not amounts[c] is int:
			continue
		var chip := hbox(4)
		chip.add_child(icon(currency_shape(c), Palette.currency(c), size + 6))
		var col := Palette.text()
		if check_afford and not Economy.can_afford({c: amounts[c]}):
			col = Palette.CORAL
		chip.add_child(label(Loc.format_number(amounts[c]), size, col))
		row.add_child(chip)
	return row


static func currency_shape(c: String) -> String:
	match c:
		"scrap": return "gear"
		"prisms": return "prism"
		"field_data": return "chip"
		"op_seals": return "seal"
		"crate_key": return "key"
	return "shard"


static func badge(count: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Palette.CORAL, Color.WHITE, 2, 12, false))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(str(count) if count > 0 else "!", 18, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.visible = count > 0
	return p


static func empty_state(text: String, shape: String = "hexagon") -> Control:
	var v := vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := icon(shape, Palette.PETROL_LIGHT, 80)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := label(text, 24, Palette.text_muted(), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.custom_minimum_size = Vector2(0, 220)
	return v


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
