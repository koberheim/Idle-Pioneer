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


## Whether there is a store to buy from or restore with on this device.
func store_available() -> bool:
	return false


func price(_product: String) -> String:
	return ""


## The base backend has no store: buying reports that plainly.
func buy(product: String) -> void:
	purchase_result.emit(product, false, "The store isn't available right now. You haven't been charged.")


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
