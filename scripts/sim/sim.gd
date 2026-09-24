## The simulation: pure functions over RunState/MetaState, no nodes. The live
## game calls step() every tick; offline catch-up calls it in larger chunks.
## Results must not depend on step size beyond small rounding.
class_name Sim
extends RefCounted

const EPS := 1e-9


static func step(run: RunState, meta: MetaState, dt: float, ev: SimEvents) -> void:
	if dt <= 0.0:
		return
	run.play_seconds += dt
	for c: RunState.ColonyState in run.colonies:
		if c.founded:
			_step_colony(run, meta, c, dt, ev)
	for def: Dictionary in Content.recipes:
		var w: RunState.WorkshopState = run.workshop(def["id"])
		if w != null and w.built and w.colonists > 0:
			_step_workshop(run, meta, w, def, dt, ev)


## Goods arriving at the capital: sold on the spot, or held in the warehouse.
static func receive(run: RunState, meta: MetaState, resource_id: String, qty: float, ev: SimEvents) -> void:
	if qty <= 0.0:
		return
	if not run.discovered.has(resource_id):
		run.discovered.append(resource_id)
		ev.discovered.append(resource_id)
	if run.is_held(resource_id):
		run.warehouse[resource_id] = run.stock_of(resource_id) + qty
	else:
		sell(run, meta, resource_id, qty, ev)


static func sell(run: RunState, meta: MetaState, resource_id: String, qty: float, ev: SimEvents) -> void:
	var earned: float = qty * Balance.sell_price(run, meta, resource_id)
	run.gold += earned
	run.lifetime_gold += earned
	ev.gold_earned += earned
	ev.add(ev.sold, resource_id, qty)


static func _step_colony(run: RunState, meta: MetaState, c: RunState.ColonyState, dt: float, ev: SimEvents) -> void:
	var res: String = Content.colony(c.id)["resource"]
	var rate: float = Balance.production_rate(run, meta, c)
	var rt: float = Balance.round_trip_seconds(run, meta, c)

	if rt <= 0.0:
		receive(run, meta, res, rate * dt, ev)
		return

	var cap: float = Balance.cargo_capacity(run, meta, c)
	var remaining: float = dt
	# Each pass advances to the next event (departure, delivery, return) or
	# the end of the step, so a long offline step still completes every trip.
	var guard: int = 0
	while remaining > EPS and guard < 100000:
		guard += 1
		if c.trip <= 0.0:
			if c.stock >= 1.0:
				c.cargo = minf(c.stock, cap)
				c.stock -= c.cargo
				c.trip = EPS
				continue
			var wait: float = (1.0 - c.stock) / rate if rate > 0.0 else INF
			if wait >= remaining:
				c.stock += rate * remaining
				return
			c.stock += rate * wait
			remaining -= wait
			continue

		var next_mark: float = 0.5 if c.trip < 0.5 else 1.0
		var to_mark: float = (next_mark - c.trip) * rt
		var adv: float = minf(remaining, to_mark)
		c.stock += rate * adv
		c.trip += adv / rt
		remaining -= adv
		if adv >= to_mark - EPS:
			c.trip = next_mark
			if next_mark == 0.5:
				_unload(run, meta, c, res, ev)
			else:
				c.trip = 0.0


static func _unload(run: RunState, meta: MetaState, c: RunState.ColonyState, res: String, ev: SimEvents) -> void:
	if c.cargo <= 0.0:
		return
	var qty: float = c.cargo
	c.cargo = 0.0
	run.shipments += 1
	ev.shipments.append({"colony": c.id, "resource": res, "qty": qty})
	ev.add(ev.delivered, res, qty)
	receive(run, meta, res, qty, ev)


static func _step_workshop(run: RunState, meta: MetaState, w: RunState.WorkshopState, def: Dictionary, dt: float, ev: SimEvents) -> void:
	var t: float = Balance.craft_seconds(run, w)
	if t == INF or t <= 0.0:
		return
	var inputs: Dictionary = def["inputs"]
	var limit: int = 1 << 30
	for input_id: String in inputs.keys():
		limit = mini(limit, int(floor(run.stock_of(input_id) / float(inputs[input_id]) + EPS)))
	if limit <= 0:
		# Waiting for materials; the bench keeps any work already done on the current item.
		return
	var total: float = w.progress + dt
	var n: int = mini(int(floor(total / t)), limit)
	if n <= 0:
		w.progress = total
		return
	for input_id: String in inputs.keys():
		run.warehouse[input_id] = maxf(run.stock_of(input_id) - float(inputs[input_id]) * n, 0.0)
	w.progress = minf(total - n * t, t)
	run.crafted[w.id] = int(run.crafted.get(w.id, 0)) + n
	ev.add(ev.crafted, w.id, n)
	receive(run, meta, w.id, float(n), ev)
