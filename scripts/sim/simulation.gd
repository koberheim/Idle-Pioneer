## Child of Game. The live game clock - the piece that was missing from
## every other subsystem this session built: Colony, Route, and
## CraftingStation all have correct, well-tested tick(delta) methods, but
## nothing was ever calling them during actual play. This is that caller.
##
## tick(delta) is the real logic, kept separate from _process() so tests can
## drive it directly with an exact delta instead of waiting on real frames -
## the same split every other subsystem in this project already uses
## (Colony.tick(), Route.tick(), etc.). _process() is just the live wiring:
## one call to tick() per frame, using the engine's own frame delta.
##
## Disabled by default (_process never fires) until something explicitly
## calls start() - the real game screen will do this once it exists (Phase
## 8's UI task). Without this guard, _process would fire every engine frame
## from the moment the game boots, including inside the automated test
## suite (Godot's main loop keeps running headless too) - silently ticking
## every test's shared Game state with an uncontrolled delta and corrupting
## exact-value assertions that have nothing to do with simulation timing.
extends Node


func _ready() -> void:
	set_process(false)


func start() -> void:
	set_process(true)


func stop() -> void:
	set_process(false)


func tick(delta: float) -> void:
	if not Game.has_run():
		return
	Game.colonies.tick(delta)
	Game.routes.tick(delta)
	Game.crafting_stations.tick(delta)
	Game.run.elapsed_seconds += delta


func _process(delta: float) -> void:
	tick(delta)
