extends GutTest
## Ads, the Ad-Free purchase and the rewarded bonus, against the desktop
## stand-in backend.


var _saved_path: String
var _saved_meta: MetaState
var _saved_run: RunState


func before_each() -> void:
	_saved_path = Game.save_path
	_saved_meta = Game.meta
	_saved_run = Game.run
	Game.save_path = "user://test_platform_save.json"
	Game.meta = MetaState.new()
	Game.start_run("english")


func after_each() -> void:
	SaveIO.delete(Game.save_path)
	Game.running = false
	Game.save_path = _saved_path
	Game.meta = _saved_meta
	Game.run = _saved_run


func test_consult_pays_once_per_cooldown() -> void:
	var before: float = Game.run.lifetime_gold
	assert_true(Game.consult_almanac())
	assert_gt(Game.run.lifetime_gold, before)
	# A duplicated ad callback must not pay twice.
	assert_false(Game.consult_almanac())
	assert_gt(Game.consult_ready_in(), 0.0)


func test_ad_free_is_never_carried_by_a_save_code() -> void:
	var code: String = Game.export_code()
	var text: String = Marshalls.base64_to_utf8(code.substr(4))
	assert_false(text.contains("ad_free"), "save codes don't mention the purchase")


func test_purchase_grants_and_survives_a_new_expedition() -> void:
	var was: bool = Platform.is_ad_free()
	Platform.buy_ad_free()
	assert_true(Platform.is_ad_free())
	Game.start_run("french")
	assert_true(Platform.is_ad_free())
	# Put things back for other tests.
	if not was:
		Platform._on_purchase_result("ad_free", false, "")
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://desktop_store.cfg"))


func test_no_interstitial_for_ad_free_owners() -> void:
	var was: bool = Platform.is_ad_free()
	Platform._on_purchase_result("ad_free", true, "")
	assert_false(Platform.show_interstitial("between_expeditions"))
	Platform._on_purchase_result("ad_free", was, "")
