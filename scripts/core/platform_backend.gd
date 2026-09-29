## What every store/ads backend provides. Results come back as signals, the
## way the native SDKs report them.
class_name PlatformBackend
extends Node

signal purchase_result(product: String, owned: bool, reason: String)
signal rewarded_result(placement: String, completed: bool)
signal interstitial_result(placement: String)


## Called once at startup: gather consent, load ads, query owned products.
func start() -> void:
	pass


func price(_product: String) -> String:
	return ""


func buy(_product: String) -> void:
	pass


func restore() -> void:
	pass


## False until consent is resolved (or where ads can't be served at all).
func ads_allowed() -> bool:
	return false


func rewarded_ready() -> bool:
	return false


func show_rewarded(placement: String) -> void:
	rewarded_result.emit(placement, false)


func interstitial_ready() -> bool:
	return false


func show_interstitial(placement: String) -> void:
	interstitial_result.emit(placement)


func privacy_options_required() -> bool:
	return false


func show_privacy_options() -> void:
	pass
