## Stand-in store and ads for desktop and tests. Ads show a clearly labelled
## "test ad" card for a few seconds; the Ad-Free purchase succeeds at once.
## Nothing is sent anywhere. Launch with `-- ads=off` to simulate no fill /
## no connection, `-- store=fail` to simulate a declined payment.
class_name DesktopBackend
extends PlatformBackend

const AD_SECONDS := 3.0

var _no_ads: bool = false
var _fail_store: bool = false
var _owned: bool = false


func start() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_no_ads = args.has("ads=off")
	_fail_store = args.has("store=fail")
	var cf := ConfigFile.new()
	if cf.load("user://desktop_store.cfg") == OK:
		_owned = bool(cf.get_value("store", "ad_free", false))
	# The real stores report owned products at startup; so does this one.
	purchase_result.emit("ad_free", _owned, "")


func price(_product: String) -> String:
	return "$4.99"


func buy(product: String) -> void:
	if _fail_store:
		purchase_result.emit(product, false, "The purchase didn't go through. You haven't been charged.")
		return
	_owned = true
	var cf := ConfigFile.new()
	cf.set_value("store", product, true)
	cf.save("user://desktop_store.cfg")
	purchase_result.emit(product, true, "")


func restore() -> void:
	purchase_result.emit("ad_free", _owned, "")


func ads_allowed() -> bool:
	return not _no_ads


func rewarded_ready() -> bool:
	return not _no_ads


func interstitial_ready() -> bool:
	return not _no_ads


func show_rewarded(placement: String) -> void:
	_show_test_ad("Rewarded test ad", func(watched: bool) -> void: rewarded_result.emit(placement, watched), true)


func show_interstitial(placement: String) -> void:
	_show_test_ad("Test ad", func(_w: bool) -> void: interstitial_result.emit(placement), false)


## A full-screen placeholder standing in for the ad SDK's own screen.
func _show_test_ad(title: String, done: Callable, rewarded: bool) -> void:
	if DisplayServer.get_name() == "headless":
		done.call(true)
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var root := ColorRect.new()
	root.color = Color(0.08, 0.08, 0.1, 0.96)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(v)
	var l := Label.new()
	l.text = "%s\n(desktop stand-in; nothing is shown in real builds)" % title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var close := Button.new()
	close.text = "Close"
	close.disabled = rewarded
	v.add_child(close)
	var t := get_tree().create_timer(AD_SECONDS)
	var finished := [false]
	t.timeout.connect(func() -> void:
		finished[0] = true
		close.disabled = false
		close.text = "Close (reward earned)" if rewarded else "Close")
	close.pressed.connect(func() -> void:
		layer.queue_free()
		done.call(finished[0]))
