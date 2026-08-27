## Child of Game. Tracks which resources and recipes this run has actually
## encountered, in the order they were first encountered - direct request:
## Market and Crafting should only list what the player has actually seen,
## in the order they showed up, not the full authored content table
## up-front (previously every resource/recipe in Db was listed regardless
## of whether the player had ever produced or unlocked it).
##
## A resource is discovered the moment it's first delivered to the Capital
## (Routing.deliver() - the single choke point every resource entering the
## central economy already passes through, whether produced there directly
## or shipped in) or first crafted (Crafting.craft_recipe()). A recipe is
## discovered the moment every one of its inputs has been discovered - the
## player has everything they'd need to plausibly make it, even before
## they've crafted it once (unlike MetaState.recipes_ever_unlocked, which
## is permanent, cross-run "ever crafted" stat-tracking - this is a
## separate, run-scoped, visibility concern).
##
## Run-scoped (lives on Game.run, not Game.meta) - a fresh run starts back
## at "nothing discovered yet," same as colony_slots/resource_routing/etc.
extends Node

signal resource_discovered(resource_id: StringName)
signal recipe_discovered(recipe_id: StringName)


func discovered_resources() -> Array[StringName]:
	return Game.run.discovered_resources if Game.run != null else []


func discovered_recipes() -> Array[StringName]:
	return Game.run.discovered_recipes if Game.run != null else []


func is_resource_discovered(resource_id: StringName) -> bool:
	return discovered_resources().has(resource_id)


func is_recipe_discovered(recipe_id: StringName) -> bool:
	return discovered_recipes().has(recipe_id)


## Records `resource_id` as discovered (a no-op if it already was), then
## checks whether any not-yet-discovered recipe just became fully
## discoverable as a result. Safe to call unconditionally on every delivery/
## craft - the common case (already discovered) is a cheap membership check.
func discover_resource(resource_id: StringName) -> void:
	if Game.run == null or resource_id == &"" or is_resource_discovered(resource_id):
		return
	Game.run.discovered_resources.append(resource_id)
	resource_discovered.emit(resource_id)
	_check_recipes()


func _check_recipes() -> void:
	for recipe: RecipeDef in Db.all_recipes():
		if is_recipe_discovered(recipe.id):
			continue
		if _all_inputs_discovered(recipe):
			Game.run.discovered_recipes.append(recipe.id)
			recipe_discovered.emit(recipe.id)


func _all_inputs_discovered(recipe: RecipeDef) -> bool:
	if recipe.inputs.is_empty():
		return false
	for ingredient: RecipeIngredient in recipe.inputs:
		if ingredient == null or not is_resource_discovered(ingredient.resource_id):
			return false
	return true
