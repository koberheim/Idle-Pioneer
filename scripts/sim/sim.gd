## The simulation: pure functions over RunState/MetaState, no nodes. The live
## game calls step() every tick; offline catch-up calls it in larger chunks.
## Results must not depend on step size beyond small rounding.
class_name Sim
extends RefCounted

const EPS := 1e-9


static func step(run: RunState, meta: MetaState, dt: float, ev: SimEvents) -> void:
	if dt <= 0.0:
		return
	# Royal Favor ending mid-step: run the favoured part and the rest separately.
	if run.favor_seconds > 0.0 and run.favor_seconds < dt:
		var first: float = run.favor_seconds
		step(run, meta, first, ev)
		step(run, meta, dt - first, ev)
		return
	_step_all(run, meta, dt, ev)
	run.favor_seconds = maxf(run.favor_seconds - dt, 0.0)


static func _step_all(run: RunState, meta: MetaState, dt: float, ev: SimEvents) -> void:
	run.play_seconds += dt
	for c: RunState.ColonyState in run.colonies:
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
	var res: String = run.resource_of(c)
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
		# Many short voyages in one step (late game, offline catch-up): settle
		# whole round trips in closed form instead of one at a time.
		if c.trip <= 0.0 and c.stock >= 1.0 and remaining >= 3.0 * rt and rate * rt >= 1.0:
			var n: int = int(minf(floor(remaining / rt), 1.0e12)) - 1
			_batch_trips(run, meta, c, res, n, rate * rt, cap, ev)
			remaining -= float(n) * rt
			continue
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


## `n` complete round trips starting at the colony with its current stock.
## Each trip loads min(stock, cap) and `per_trip` more is produced meanwhile.
static func _batch_trips(run: RunState, meta: MetaState, c: RunState.ColonyState, res: String, n: int, per_trip: float, cap: float, ev: SimEvents) -> void:
	var s0: float = c.stock
	var delivered: float
	var final_stock: float
	if per_trip >= cap:
		# The route is the bottleneck: after the first load every trip is full.
		var first: float = minf(s0, cap)
		delivered = first + float(n - 1) * cap
		final_stock = s0 - first + per_trip + float(n - 1) * (per_trip - cap)
	else:
		# A backlog drains by (cap - per_trip) a trip, then trips carry what
		# was produced during the previous voyage.
		var m: int = 0
		if s0 >= cap:
			m = mini(int(minf(floor((s0 - cap) / (cap - per_trip)), 1.0e12)) + 1, n)
		delivered = float(m) * cap
		var s: float = s0 - float(m) * (cap - per_trip)
		if n > m:
			delivered += s + float(n - m - 1) * per_trip
			final_stock = per_trip
		else:
			final_stock = s
	c.stock = maxf(final_stock, 0.0)
	c.cargo = 0.0
	c.trip = 0.0
	run.shipments += n
	ev.add_shipment(c.id, res, delivered, n)
	ev.add(ev.delivered, res, delivered)
	receive(run, meta, res, delivered, ev)


static func _unload(run: RunState, meta: MetaState, c: RunState.ColonyState, res: String, ev: SimEvents) -> void:
	if c.cargo <= 0.0:
		return
	var qty: float = c.cargo
	c.cargo = 0.0
	run.shipments += 1
	ev.add_shipment(c.id, res, qty)
	ev.add(ev.delivered, res, qty)
	receive(run, meta, res, qty, ev)


static func _step_workshop(run: RunState, meta: MetaState, w: RunState.WorkshopState, def: Dictionary, dt: float, ev: SimEvents) -> void:
	var t: float = Balance.craft_seconds(run, meta, w)
	if t == INF or t <= 0.0:
		return
	var inputs: Dictionary = Balance.recipe_inputs(run, w.id)
	var limit: int = 1 << 30
	for input_id: String in inputs.keys():
		limit = mini(limit, int(minf(floor(run.stock_of(input_id) / float(inputs[input_id]) + EPS), 1.0e15)))
	if limit <= 0:
		# Waiting for materials; the bench keeps any work already done on the current item.
		return
	var total: float = w.progress + dt
	var n: int = mini(int(minf(floor(total / t), 1.0e15)), limit)
	if n <= 0:
		w.progress = total
		return
	for input_id: String in inputs.keys():
		run.warehouse[input_id] = maxf(run.stock_of(input_id) - float(inputs[input_id]) * n, 0.0)
	w.progress = minf(total - n * t, t)
	run.crafted[w.id] = int(run.crafted.get(w.id, 0)) + n
	ev.add(ev.crafted, w.id, n)
	receive(run, meta, w.id, float(n), ev)
