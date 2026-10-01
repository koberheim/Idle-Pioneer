## Store and advertising services behind one small interface, so game code
## never talks to an SDK directly: ads (rewarded and interstitial), the
## one-time Ad-Free purchase, and privacy consent.
##
## The backend is chosen at startup. On desktop (and in tests) a stand-in
## backend simulates everything so the whole flow can be played and tested
## without a store. The Android (AdMob + Play Billing) and iOS (AdMob +
## StoreKit) backends plug in here once the native plugins are added; see
## docs/MONETIZATION.md.
##
## Ownership of Ad-Free lives in its own file, never in the save or in save
## codes, so copying someone's save can't copy their purchase.
extends Node

signal ad_free_changed(owned: bool)
signal purchase_failed(reason: String)
## A rewarded ad finished: `completed` is true only if it was watched through.
signal rewarded_finished(placement: String, completed: bool)
signal interstitial_closed(placement: String)

const AD_FREE := "ad_free"
const ENTITLEMENT_PATH := "user://entitlements.cfg"

var backend: PlatformBackend
var _ad_free: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backend = _make_backend()
	add_child(backend)
	backend.purchase_result.connect(_on_purchase_result)
	backend.rewarded_result.connect(func(p: String, ok: bool) -> void:
		_end_ad()
		rewarded_finished.emit(p, ok))
	backend.interstitial_result.connect(func(p: String) -> void:
		_end_ad()
		interstitial_closed.emit(p))
	_ad_free = _load_entitlement()
	backend.start()


func _make_backend() -> PlatformBackend:
	# Native backends are added here when their plugins are installed:
	#   if Engine.has_singleton("<AdMob/Billing plugin>"): return AndroidBackend.new()
	return DesktopBackend.new()


# --- Ad-Free purchase ---------------------------------------------------------

func is_ad_free() -> bool:
	return _ad_free


## The store's localized price, or "" while unknown.
func ad_free_price() -> String:
	return backend.price(AD_FREE)


func buy_ad_free() -> void:
	if _ad_free:
		return
	backend.buy(AD_FREE)


func restore_purchases() -> void:
	backend.restore()


func _on_purchase_result(product: String, owned: bool, reason: String) -> void:
	if product != AD_FREE:
		return
	if reason != "":
		purchase_failed.emit(reason)
	if owned != _ad_free:
		_ad_free = owned
		_save_entitlement()
		ad_free_changed.emit(owned)


func _load_entitlement() -> bool:
	var cf := ConfigFile.new()
	if cf.load(ENTITLEMENT_PATH) != OK:
		return false
	return bool(cf.get_value("store", AD_FREE, false))


func _save_entitlement() -> void:
	var cf := ConfigFile.new()
	cf.set_value("store", AD_FREE, _ad_free)
	cf.save(ENTITLEMENT_PATH)


# --- Ads --------------------------------------------------------------------------

func rewarded_ready() -> bool:
	return backend.ads_allowed() and backend.rewarded_ready()


## Shows a rewarded ad; rewarded_finished follows. Ad-Free owners never need
## to call this: the reward is theirs without watching.
func show_rewarded(placement: String) -> void:
	_begin_ad()
	backend.show_rewarded(placement)


## Shows an interstitial if one is loaded and the player hasn't bought
## Ad-Free. Returns whether one is being shown (interstitial_closed follows).
func show_interstitial(placement: String) -> bool:
	if _ad_free or not backend.ads_allowed() or not backend.interstitial_ready():
		return false
	_begin_ad()
	backend.show_interstitial(placement)
	return true


## While an ad is on screen the game waits: the simulation is paused (the
## time neither counts nor is lost) and all game audio is silenced.
var _ad_open: bool = false


func _begin_ad() -> void:
	if _ad_open:
		return
	_ad_open = true
	Game.pause("ad")
	if Sfx.has_method("pause_all"):
		Sfx.pause_all()


func _end_ad() -> void:
	if not _ad_open:
		return
	_ad_open = false
	Game.resume("ad")
	if Sfx.has_method("resume_all"):
		Sfx.resume_all()


# --- Privacy ------------------------------------------------------------------------

## Whether the consent system requires a "Privacy choices" entry in Settings.
func privacy_options_required() -> bool:
	return backend.privacy_options_required()


func show_privacy_options() -> void:
	backend.show_privacy_options()
