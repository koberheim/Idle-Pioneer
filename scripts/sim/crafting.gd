## Executes a RecipeDef against Game.inventory (task P4). Static functions, no
## state - like PlacementRules, not something that needs an instance.
##
## can_craft/craft take a recipe id (the normal call shape, resolving through
## Db) and delegate to can_craft_recipe/craft_recipe, which operate on a
## RecipeDef directly. That split exists for one reason: it makes the
## atomicity edge case below testable without needing a real .tres fixture.
class_name Crafting


static func can_craft(recipe_id: StringName) -> bool:
	var recipe: RecipeDef = Db.recipe(recipe_id)
	return recipe != null and can_craft_recipe(recipe)


## Verifies every input is available, consumes them all, then produces the
## output - in that order, and only if the verify step passed for everything.
## Returns false (nothing consumed) if the recipe can't be crafted.
static func craft(recipe_id: StringName) -> bool:
	var recipe: RecipeDef = Db.recipe(recipe_id)
	if recipe == null:
		return false
	return craft_recipe(recipe)


static func can_craft_recipe(recipe: RecipeDef) -> bool:
	if recipe == null or not recipe.is_valid():
		return false
	var totals: Dictionary = _required_totals(recipe)
	for id: StringName in totals.keys():
		if not Game.inventory.has(id, totals[id]):
			return false
	return true


static func craft_recipe(recipe: RecipeDef) -> bool:
	if not can_craft_recipe(recipe):
		return false

	var totals: Dictionary = _required_totals(recipe)
	for id: StringName in totals.keys():
		if not Game.inventory.try_remove(id, totals[id]):
			# Shouldn't be reachable - can_craft_recipe() already verified every
			# total above. Guarded anyway rather than assumed.
			push_error(
				"Crafting.craft_recipe: try_remove failed for '%s' after can_craft_recipe() passed" % id
			)
			return false

	# Routed through Routing.deliver(), not a direct Game.inventory.add() -
	# a crafted good is exactly as subject to the Market's Auto Sell toggle
	# as a raw resource is. A real bug this pass: output used to bypass
	# routing entirely, so Auto Sell had no effect on crafted goods at all -
	# they piled up in inventory regardless of the toggle. deliver() also
	# calls Game.discoveries.discover_resource() itself, so that no longer
	# needs a separate call here.
	Game.routing.deliver(recipe.output_id, recipe.output_amount)

	# "Unlocked" is read pragmatically as "ever successfully crafted" - see
	# MetaState.recipes_ever_unlocked's class doc for why (no recipe-gating
	# mechanic exists yet to hang a stricter definition on). Permanent, so it
	# lives in Game.meta, not Game.run.
	if not Game.meta.recipes_ever_unlocked.has(recipe.id):
		Game.meta.recipes_ever_unlocked.append(recipe.id)

	return true


## Sums `amount` per resource_id across every ingredient row. This is what
## keeps craft_recipe() atomic even for a (pathological, but possible)
## recipe that lists the same resource_id in two separate ingredient rows:
## checking/consuming each row independently could pass a per-row check twice
## against the same stock and then fail partway through consuming, leaving
## inventory half-consumed. Aggregating first means there's exactly one
## check and one consume per distinct resource, so there's nothing left to
## fail once can_craft_recipe() has already said yes.
static func _required_totals(recipe: RecipeDef) -> Dictionary:
	var totals: Dictionary = {}
	for ingredient: RecipeIngredient in recipe.inputs:
		if ingredient == null:
			continue
		totals[ingredient.resource_id] = float(totals.get(ingredient.resource_id, 0.0)) + float(ingredient.amount)
	return totals
