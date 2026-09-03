class_name Inventory
extends RefCounted
## A slot-based container of item stacks.
##
## A stack is identified by (item_id, quality, packaging) so a Radiant shard in
## a Shell Case never merges with a Dull one in waxed paper. Used for the
## player, every property's storage, vehicle boots and shop stock.

signal changed()

var id: String = "inventory"
var capacity: int = 8                 ## number of stacks, not units
var stacks: Array[Dictionary] = []    ## [{item, qty, quality, pack}]
var allow_overflow: bool = false      ## storage containers ignore stack caps


func _init(inventory_id: String = "inventory", slots: int = 8) -> void:
	id = inventory_id
	capacity = slots


# --- Queries ---------------------------------------------------------------

func is_empty() -> bool:
	return stacks.is_empty()


func used_slots() -> int:
	return stacks.size()


func free_slots() -> int:
	return maxi(0, capacity - stacks.size())


func stack_limit(item_id: String) -> int:
	if allow_overflow:
		return 99999
	return int(GameData.item(item_id).get("stack", GameConfig.DEFAULT_STACK_SIZE))


func count(item_id: String, quality: int = -1, pack: String = "") -> int:
	var total := 0
	for s in stacks:
		if s["item"] != item_id:
			continue
		if quality >= 0 and int(s["quality"]) != quality:
			continue
		if pack != "" and String(s["pack"]) != pack:
			continue
		total += int(s["qty"])
	return total


## Units of an item at or above a minimum quality.
func count_min_quality(item_id: String, min_quality: int) -> int:
	var total := 0
	for s in stacks:
		if s["item"] == item_id and int(s["quality"]) >= min_quality:
			total += int(s["qty"])
	return total


func count_any_product(min_quality: int = -1) -> int:
	var total := 0
	for s in stacks:
		if GameData.item(s["item"]).get("category", "") != ItemDB.CAT_PRODUCT:
			continue
		if min_quality >= 0 and int(s["quality"]) < min_quality:
			continue
		total += int(s["qty"])
	return total


func has(item_id: String, amount: int = 1, min_quality: int = -1) -> bool:
	if min_quality >= 0:
		return count_min_quality(item_id, min_quality) >= amount
	return count(item_id) >= amount


func total_units() -> int:
	var t := 0
	for s in stacks:
		t += int(s["qty"])
	return t


func total_weight() -> float:
	var w := 0.0
	for s in stacks:
		w += float(GameData.item(s["item"]).get("weight", 0.1)) * int(s["qty"])
	return w


## Heat radiated by carried contraband, reduced by packaging.
func contraband_heat() -> float:
	var heat := 0.0
	for s in stacks:
		var item: Dictionary = GameData.item(s["item"])
		if not bool(item.get("contraband", false)):
			continue
		var reduction := 0.0
		var pack: String = String(s["pack"])
		if pack != "":
			reduction = float(GameData.item(pack).get("heat_reduction", 0.0))
		heat += float(item.get("heat", 0.0)) * int(s["qty"]) * (1.0 - reduction)
	return heat


func contraband_units() -> int:
	var n := 0
	for s in stacks:
		if GameData.is_contraband(s["item"]):
			n += int(s["qty"])
	return n


## Estimated resale value at base prices - used for seizure and UI summaries.
func estimated_value() -> int:
	var v := 0.0
	for s in stacks:
		var base := float(GameData.item_value(s["item"]))
		var qm := GameConfig.quality_multiplier(int(s["quality"]))
		var pb := 1.0
		if String(s["pack"]) != "":
			pb += float(GameData.item(s["pack"]).get("value_bonus", 0.0))
		v += base * qm * pb * int(s["qty"])
	return int(round(v))


func find_stack(item_id: String, quality: int, pack: String) -> int:
	for i in stacks.size():
		var s := stacks[i]
		if s["item"] == item_id and int(s["quality"]) == quality and String(s["pack"]) == pack:
			return i
	return -1


# --- Mutation --------------------------------------------------------------

## Returns the number of units actually added.
func add(item_id: String, amount: int = 1, quality: int = 0, pack: String = "") -> int:
	if amount <= 0 or not GameData.items.has(item_id):
		return 0
	var limit := stack_limit(item_id)
	var remaining := amount

	# Top up existing partial stacks first.
	for s in stacks:
		if remaining <= 0:
			break
		if s["item"] == item_id and int(s["quality"]) == quality and String(s["pack"]) == pack:
			var space: int = limit - int(s["qty"])
			if space > 0:
				var moved: int = mini(space, remaining)
				s["qty"] = int(s["qty"]) + moved
				remaining -= moved

	# Then open new stacks while slots allow.
	while remaining > 0 and stacks.size() < capacity:
		var moved: int = mini(limit, remaining)
		stacks.append({"item": item_id, "qty": moved, "quality": quality, "pack": pack})
		remaining -= moved

	var added := amount - remaining
	if added > 0:
		changed.emit()
		EventBus.inventory_changed.emit(id)
		EventBus.item_gained.emit(item_id, added, quality)
	if remaining > 0:
		EventBus.inventory_full.emit(item_id)
	return added


func can_accept(item_id: String, amount: int) -> bool:
	if not GameData.items.has(item_id):
		return false
	var limit := stack_limit(item_id)
	var space := 0
	for s in stacks:
		if s["item"] == item_id:
			space += maxi(0, limit - int(s["qty"]))
	space += free_slots() * limit
	return space >= amount


## Removes from the *lowest* quality first by default, which is what a player
## expects when a recipe asks for generic inputs.
## Returns units actually removed.
func remove(item_id: String, amount: int = 1, min_quality: int = -1,
		prefer_low_quality: bool = true) -> int:
	if amount <= 0:
		return 0
	var candidates: Array[int] = []
	for i in stacks.size():
		var s := stacks[i]
		if s["item"] != item_id:
			continue
		if min_quality >= 0 and int(s["quality"]) < min_quality:
			continue
		candidates.append(i)
	candidates.sort_custom(func(a, b):
		var qa := int(stacks[a]["quality"])
		var qb := int(stacks[b]["quality"])
		return qa < qb if prefer_low_quality else qa > qb)

	var remaining := amount
	var removed_quality := 0
	for i in candidates:
		if remaining <= 0:
			break
		var s := stacks[i]
		var take: int = mini(int(s["qty"]), remaining)
		s["qty"] = int(s["qty"]) - take
		remaining -= take
		removed_quality = int(s["quality"])
	_compact()

	var removed := amount - remaining
	if removed > 0:
		changed.emit()
		EventBus.inventory_changed.emit(id)
		EventBus.item_lost.emit(item_id, removed, removed_quality)
	return removed


## Removes exactly one identified stack slice (used by the inventory UI).
func remove_from_slot(index: int, amount: int) -> Dictionary:
	if index < 0 or index >= stacks.size():
		return {}
	var s := stacks[index]
	var take: int = mini(int(s["qty"]), amount)
	if take <= 0:
		return {}
	s["qty"] = int(s["qty"]) - take
	var result := {"item": s["item"], "qty": take, "quality": s["quality"], "pack": s["pack"]}
	_compact()
	changed.emit()
	EventBus.inventory_changed.emit(id)
	return result


## Moves up to `amount` of a slot into another inventory. Returns units moved.
func transfer_slot(index: int, target: Inventory, amount: int) -> int:
	if index < 0 or index >= stacks.size() or target == null:
		return 0
	var s := stacks[index]
	var want: int = mini(int(s["qty"]), amount)
	if want <= 0:
		return 0
	var moved := target.add(s["item"], want, int(s["quality"]), String(s["pack"]))
	if moved > 0:
		s["qty"] = int(s["qty"]) - moved
		_compact()
		changed.emit()
		EventBus.inventory_changed.emit(id)
	return moved


## Applies packaging to a stack, consuming wrappers from `source`.
func package_slot(index: int, pack_id: String, source: Inventory) -> int:
	if index < 0 or index >= stacks.size():
		return 0
	var s := stacks[index]
	if GameData.item(s["item"]).get("category", "") != ItemDB.CAT_PRODUCT:
		return 0
	if String(s["pack"]) == pack_id:
		return 0
	var per_pack := int(GameData.item(pack_id).get("capacity", 1))
	if per_pack <= 0:
		per_pack = 1
	var units := int(s["qty"])
	var wrappers_needed := int(ceil(float(units) / float(per_pack)))
	if source.count(pack_id) < wrappers_needed:
		return 0
	source.remove(pack_id, wrappers_needed)
	var quality := int(s["quality"])
	var item_id: String = s["item"]
	s["qty"] = 0
	_compact()
	add(item_id, units, quality, pack_id)
	return units


func clear() -> void:
	stacks.clear()
	changed.emit()
	EventBus.inventory_changed.emit(id)


## Removes a fraction of everything (a Bureau seizure). Returns what was taken.
func seize(fraction: float) -> Array[Dictionary]:
	var taken: Array[Dictionary] = []
	var f := clampf(fraction, 0.0, 1.0)
	if f <= 0.0:
		return taken
	for s in stacks:
		if not GameData.is_contraband(s["item"]):
			continue
		var take := int(ceil(int(s["qty"]) * f))
		if take <= 0:
			continue
		taken.append({"item": s["item"], "qty": take, "quality": s["quality"], "pack": s["pack"]})
		s["qty"] = int(s["qty"]) - take
	_compact()
	if not taken.is_empty():
		changed.emit()
		EventBus.inventory_changed.emit(id)
	return taken


func set_capacity(new_capacity: int) -> void:
	capacity = maxi(1, new_capacity)
	changed.emit()


func _compact() -> void:
	var out: Array[Dictionary] = []
	for s in stacks:
		if int(s["qty"]) > 0:
			out.append(s)
	stacks = out


# --- Serialisation ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"id": id, "capacity": capacity, "stacks": stacks.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	capacity = int(d.get("capacity", capacity))
	stacks.clear()
	for raw in d.get("stacks", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var item_id: String = String(raw.get("item", ""))
		if not GameData.items.has(item_id):
			continue  # content changed between versions: drop unknown items
		stacks.append({
			"item": item_id,
			"qty": int(raw.get("qty", 0)),
			"quality": int(raw.get("quality", 0)),
			"pack": String(raw.get("pack", "")),
		})
	_compact()
	changed.emit()
