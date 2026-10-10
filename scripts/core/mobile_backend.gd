## The real store and ads on phones.
##
## Ads (both platforms): Google AdMob through the Poing Studios plugin
## (addons/admob), with Google's consent message (UMP) shown first where the
## law requires it. No ad is requested until consent allows it.
## Ad-Free: Google Play Billing on Android (addons/GodotGooglePlayBilling),
## StoreKit 2 on iOS (ios/plugins/ios-in-app-purchase).
##
## Loaded by Platform only on a phone that has the plugins, so desktop play
## and the tests never touch the native SDKs. See docs/MONETIZATION.md.
extends PlatformBackend

## Google's published test units, used by every debug build.
const TEST_UNITS := {
	"Android": {"rewarded": "ca-app-pub-3940256099942544/5224354917", "interstitial": "ca-app-pub-3940256099942544/1033173712"},
	"iOS": {"rewarded": "ca-app-pub-3940256099942544/1712485313", "interstitial": "ca-app-pub-3940256099942544/4411468910"},
}
## Release unit ids live in Project Settings (idle_pioneer/ads/...), filled in
## at release time. A release build with none set shows no ads at all.
const UNIT_SETTING := "idle_pioneer/ads/%s_%s"
const RETRY_SECONDS: Array[float] = [15.0, 30.0, 60.0, 120.0, 300.0]

const IOS_IAP := "IOSInAppPurchase"
const PURCHASE_FAILED := "The purchase didn't go through. You haven't been charged."
const STORE_UNREACHABLE := "The store can't be reached right now. You haven't been charged."
const PENDING := "Your payment is pending. Ad-Free arrives as soon as it completes."

var _os: String = OS.get_name()
var _ads_ready_to_load: bool = false
var _rewarded: RewardedAd
var _interstitial: InterstitialAd
var _rewarded_tries: int = 0
var _interstitial_tries: int = 0
var _price: String = ""

# Android
var _billing: BillingClient
# iOS
var _iap: Object


# --- Start ----------------------------------------------------------------------

func start() -> void:
	_start_store()
	_request_consent()


func store_available() -> bool:
	return _billing != null or _iap != null


func price(_product: String) -> String:
	return _price


# --- Consent and ads --------------------------------------------------------------

func _request_consent() -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(params, func() -> void:
		if UserMessagingPlatform.consent_information.get_is_consent_form_available() \
				and UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
			UserMessagingPlatform.load_consent_form(func(form: ConsentForm) -> void:
				form.show(func(_e: FormError) -> void: _init_ads()),
				func(_e: FormError) -> void: _init_ads())
		else:
			_init_ads(),
		func(_e: FormError) -> void:
			# Offline or the consent service failed: fall back to the answer
			# the player gave last time, if any.
			_init_ads())


func _consent_allows_ads() -> bool:
	var s: int = UserMessagingPlatform.consent_information.get_consent_status()
	return s == ConsentInformation.ConsentStatus.NOT_REQUIRED or s == ConsentInformation.ConsentStatus.OBTAINED


func _init_ads() -> void:
	if _ads_ready_to_load or not _consent_allows_ads() or _unit("rewarded") == "":
		return
	_ads_ready_to_load = true
	var config := RequestConfiguration.new()
	# The game is not directed at children (store audience 13+).
	config.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
	MobileAds.set_request_configuration(config)
	var done := OnInitializationCompleteListener.new()
	done.on_initialization_complete = func(_s: InitializationStatus) -> void:
		_load_rewarded()
		_load_interstitial()
	MobileAds.initialize(done)


func _unit(kind: String) -> String:
	if OS.is_debug_build():
		return TEST_UNITS.get(_os, {}).get(kind, "")
	return str(ProjectSettings.get_setting(UNIT_SETTING % [_os.to_lower(), kind], ""))


func ads_allowed() -> bool:
	return _ads_ready_to_load and _consent_allows_ads()


func rewarded_ready() -> bool:
	return _rewarded != null


func interstitial_ready() -> bool:
	return _interstitial != null


func _retry(tries: int, again: Callable) -> void:
	var wait: float = RETRY_SECONDS[mini(tries, RETRY_SECONDS.size() - 1)]
	get_tree().create_timer(wait, true).timeout.connect(again)


func _load_rewarded() -> void:
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		_rewarded_tries = 0
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_rewarded_tries += 1
		_retry(_rewarded_tries, _load_rewarded)
	RewardedAdLoader.new().load(_unit("rewarded"), AdRequest.new(), cb)


func _load_interstitial() -> void:
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		_interstitial_tries = 0
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_interstitial_tries += 1
		_retry(_interstitial_tries, _load_interstitial)
	InterstitialAdLoader.new().load(_unit("interstitial"), AdRequest.new(), cb)


func show_rewarded(placement: String) -> void:
	var ad: RewardedAd = _rewarded
	if ad == null:
		rewarded_result.emit(placement, false)
		return
	_rewarded = null
	var earned := [false]
	var finish := func() -> void:
		ad.destroy()
		# The reward callback can land just after the dismissal; give it a
		# couple of frames before deciding the ad wasn't watched through.
		await get_tree().process_frame
		await get_tree().process_frame
		rewarded_result.emit(placement, earned[0])
		_load_rewarded()
	var calls := FullScreenContentCallback.new()
	calls.on_ad_dismissed_full_screen_content = finish
	calls.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = calls
	var reward := OnUserEarnedRewardListener.new()
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	ad.show(reward)


func show_interstitial(placement: String) -> void:
	var ad: InterstitialAd = _interstitial
	if ad == null:
		interstitial_result.emit(placement)
		return
	_interstitial = null
	var finish := func() -> void:
		ad.destroy()
		interstitial_result.emit(placement)
		_load_interstitial()
	var calls := FullScreenContentCallback.new()
	calls.on_ad_dismissed_full_screen_content = finish
	calls.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: finish.call()
	ad.full_screen_content_callback = calls
	ad.show()


func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void:
		# The player may have just allowed (or withdrawn) ads.
		_init_ads())


# --- Store ----------------------------------------------------------------------

func _start_store() -> void:
	if _os == "Android" and Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = BillingClient.new()
		add_child(_billing)
		_billing.connected.connect(_on_billing_connected)
		_billing.disconnected.connect(func() -> void:
			get_tree().create_timer(30.0, true).timeout.connect(_billing.start_connection))
		_billing.query_product_details_response.connect(_on_product_details)
		_billing.query_purchases_response.connect(_on_owned_purchases)
		_billing.on_purchase_updated.connect(_on_purchase_updated)
		_billing.start_connection()
	elif _os == "iOS" and Engine.has_singleton(IOS_IAP):
		_iap = Engine.get_singleton(IOS_IAP)
		_iap.response.connect(_on_ios_response)
		_iap.request("startUpdateTask", {})
		_iap.request("products", {"productIDs": [Platform.AD_FREE]})
		_iap.request("transactionCurrentEntitlements", {})


func buy(product: String) -> void:
	if _billing != null:
		if not _billing.is_ready():
			_billing.start_connection()
			purchase_result.emit(product, false, STORE_UNREACHABLE)
			return
		var r: Dictionary = _billing.purchase(product)
		if int(r.get("response_code", BillingClient.BillingResponseCode.ERROR)) != BillingClient.BillingResponseCode.OK:
			purchase_result.emit(product, false, PURCHASE_FAILED)
	elif _iap != null:
		_iap.request("purchase", {"productID": product})
	else:
		super.buy(product)


func restore() -> void:
	if _billing != null:
		if _billing.is_ready():
			_billing.query_purchases(BillingClient.ProductType.INAPP)
		else:
			_billing.start_connection()  # _on_billing_connected queries purchases
	elif _iap != null:
		_iap.request("appStoreSync", {})


# Android ------------------------------------------------------------------------

func _on_billing_connected() -> void:
	_billing.query_product_details(PackedStringArray([Platform.AD_FREE]), BillingClient.ProductType.INAPP)
	_billing.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for d: Dictionary in r.get("product_details", []):
		if d.get("product_id", "") != Platform.AD_FREE:
			continue
		var offers = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			_price = str(offers[0].get("formatted_price", ""))


## The store's full list of what the player owns: a definite answer, so it
## may also take Ad-Free away (a refund or a revoked purchase).
func _on_owned_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	var owned := false
	for p: Dictionary in r.get("purchases", []):
		if _android_owns(p):
			owned = true
	purchase_result.emit(Platform.AD_FREE, owned, "")


func _on_purchase_updated(r: Dictionary) -> void:
	var code: int = int(r.get("response_code", -1))
	match code:
		BillingClient.BillingResponseCode.OK:
			for p: Dictionary in r.get("purchases", []):
				if not Platform.AD_FREE in Array(p.get("product_ids", [])):
					continue
				if _android_owns(p):
					purchase_result.emit(Platform.AD_FREE, true, "")
				elif int(p.get("purchase_state", 0)) == BillingClient.PurchaseState.PENDING:
					purchase_result.emit(Platform.AD_FREE, false, PENDING)
		BillingClient.BillingResponseCode.USER_CANCELED:
			pass  # the player closed the sheet; nothing to say
		BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
			_billing.query_purchases(BillingClient.ProductType.INAPP)
		_:
			purchase_result.emit(Platform.AD_FREE, false, PURCHASE_FAILED)


## A completed Ad-Free purchase. Acknowledges it on the way (Google refunds
## purchases left unacknowledged for three days). Never consumed.
func _android_owns(p: Dictionary) -> bool:
	if not Platform.AD_FREE in Array(p.get("product_ids", [])):
		return false
	if int(p.get("purchase_state", 0)) != BillingClient.PurchaseState.PURCHASED:
		return false
	if not bool(p.get("is_acknowledged", false)):
		_billing.acknowledge_purchase(str(p.get("purchase_token", "")))
	return true


# iOS ----------------------------------------------------------------------------

func _on_ios_response(request: String, data: Dictionary) -> void:
	var result: String = str(data.get("result", ""))
	match request:
		"products":
			if result == "success":
				for p: Dictionary in data.get("products", []):
					if p.get("id", "") == Platform.AD_FREE:
						_price = str(p.get("displayPrice", ""))
		"purchase":
			if data.get("productID", Platform.AD_FREE) != Platform.AD_FREE:
				return
			match result:
				"success":
					if str(data.get("revocationDate", "")) == "":
						purchase_result.emit(Platform.AD_FREE, true, "")
				"pending":
					purchase_result.emit(Platform.AD_FREE, false, PENDING)
				"userCancelled":
					pass
				_:
					purchase_result.emit(Platform.AD_FREE, false, PURCHASE_FAILED)
		"appStoreSync":
			_iap.request("transactionCurrentEntitlements", {})
		"transactionCurrentEntitlements":
			# Current entitlements leave out refunded and revoked purchases,
			# so this is a definite answer either way.
			if result != "success":
				return
			var owned := false
			for t: Dictionary in data.get("transactions", []):
				if t.get("productID", "") == Platform.AD_FREE and str(t.get("revocationDate", "")) == "":
					owned = true
			purchase_result.emit(Platform.AD_FREE, owned, "")
