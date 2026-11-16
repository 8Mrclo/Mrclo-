class_name HintBanner
extends PanelContainer
## Non-blocking tutorial hint. "Entendi" hides it (step stays pending and can
## reappear next session); "Pular" skips skippable steps permanently.

var _step_id := ""
var _label: Label
var _skip: Button


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UIKit.box(Color(Palette.PETROL_DEEP, 0.95), Palette.AMBER, 2, 18))
	var v := UIKit.vbox(8)
	add_child(v)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon("star", Palette.AMBER, 34))
	head.add_child(UIKit.label(Loc.t("tutorial.hint"), 22, Palette.AMBER))
	v.add_child(head)
	_label = UIKit.label("", 24, Palette.text(), true)
	v.add_child(_label)
	var row := UIKit.hbox(10)
	_skip = UIKit.button(Loc.t("tutorial.skip"), _on_skip, "ghost", 56)
	row.add_child(_skip)
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.button(Loc.t("tutorial.got_it"), func(): visible = false, "secondary", 56))
	v.add_child(row)
	Tutorial.step_shown.connect(_on_shown)
	Tutorial.step_closed.connect(_on_closed)


func _on_shown(step: Dictionary) -> void:
	_step_id = step.id
	_label.text = Loc.text(step.text)
	_skip.visible = bool(step.get("skippable", true))
	visible = true


func _on_skip() -> void:
	Tutorial.skip(_step_id)
	visible = false


func _on_closed(id: String) -> void:
	if id == _step_id:
		visible = false
