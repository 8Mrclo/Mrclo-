extends Control
## Loading: threaded load of heavy scenes (battle) with a progress bar and a
## rotating lore tip.

var _target := ""
var _path := ""
var _bar: ProgressBar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(HangarBackground.new())
	_target = Router.params.get("target", "lobby")
	_path = Router.SCENES.get(_target, "")
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var v := UIKit.vbox(18)
	v.custom_minimum_size = Vector2(560, 0)
	c.add_child(v)
	var t := UIKit.title(Loc.t("loading.title"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_bar = UIKit.progress(0, 1, Palette.AMBER, 20)
	v.add_child(_bar)
	var tips := ["loading.tip1", "loading.tip2", "loading.tip3", "loading.tip4", "loading.tip5"]
	var tip := UIKit.label(Loc.t(tips[randi() % tips.size()]), 22, Palette.text_muted(), true)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	if _path != "":
		ResourceLoader.load_threaded_request(_path)


func _process(_delta: float) -> void:
	if _path == "":
		Router.goto("lobby", {}, false)
		set_process(false)
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path, progress)
	if progress.size() > 0:
		_bar.value = float(progress[0])
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		ResourceLoader.load_threaded_get(_path)
		Router.goto(_target, Router.params.get("target_params", {}), false)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		set_process(false)
		Router.toast(Loc.t("loading.error"), &"error")
		Router.goto("lobby", {}, false)
