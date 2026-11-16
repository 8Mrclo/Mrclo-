class_name Dialogs
extends RefCounted
## Modal dialogs. They live on a CanvasLayer added to the current scene so
## they disappear automatically when the scene changes.


static func _layer(title_text: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.current_scene.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override("panel", UIKit.box(Palette.panel_bg(), Palette.TEAL, 3, 24))
	center.add_child(panel)
	var v := UIKit.vbox(16)
	panel.add_child(v)
	if title_text != "":
		var t := UIKit.title(title_text)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	return {"layer": layer, "box": v}


## Generic confirm. body may be a String or a Control.
static func confirm(title_text: String, body: Variant, confirm_text: String, on_confirm: Callable, danger: bool = false) -> void:
	var d := _layer(title_text)
	var v: VBoxContainer = d.box
	_add_body(v, body)
	var row := UIKit.hbox(14)
	var layer: CanvasLayer = d.layer
	var cancel := UIKit.button(Loc.t("common.cancel"), func(): layer.queue_free(), "ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := UIKit.button(confirm_text, func():
		layer.queue_free()
		on_confirm.call(), "danger" if danger else "primary")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(ok)
	v.add_child(row)
	ok.grab_focus.call_deferred()


static func info(title_text: String, body: Variant, close_text: String = "") -> CanvasLayer:
	var d := _layer(title_text)
	var v: VBoxContainer = d.box
	_add_body(v, body)
	var layer: CanvasLayer = d.layer
	var close := UIKit.button(close_text if close_text != "" else Loc.t("common.close"), func(): layer.queue_free(), "secondary")
	v.add_child(close)
	return layer


## Destructive confirm that requires typing an exact word.
static func typed_confirm(title_text: String, body: String, word: String, on_confirm: Callable) -> void:
	var d := _layer(title_text)
	var v: VBoxContainer = d.box
	var layer: CanvasLayer = d.layer
	v.add_child(UIKit.label(body, 24, Palette.text(), true))
	v.add_child(UIKit.label(Loc.t("dialog.type_word", {"word": word}), 22, Palette.AMBER, true))
	var edit := LineEdit.new()
	edit.placeholder_text = word
	edit.custom_minimum_size = Vector2(0, 64)
	v.add_child(edit)
	var row := UIKit.hbox(14)
	var cancel := UIKit.button(Loc.t("common.cancel"), func(): layer.queue_free(), "ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := UIKit.button(Loc.t("common.confirm"), func():
		if edit.text.strip_edges().to_upper() == word.to_upper():
			layer.queue_free()
			on_confirm.call()
		else:
			Router.toast(Loc.t("dialog.word_mismatch"), &"error"), "danger")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(ok)
	v.add_child(row)


static func _add_body(v: VBoxContainer, body: Variant) -> void:
	if body is Control:
		v.add_child(body)
	elif str(body) != "":
		var l := UIKit.label(str(body), 24, Palette.text(), true)
		l.custom_minimum_size = Vector2(560, 0)
		v.add_child(l)
