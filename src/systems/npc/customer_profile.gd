class_name CustomerProfile
extends RefCounted
## A generated buyer.
##
## Customers are procedural rather than authored: an archetype gives them a
## haggling style and risk appetite, the district decides what they can afford,
## and their loyalty grows as you serve them. Named characters can also carry a
## profile so a story NPC can buy from you.

var id: String = ""
var display_name: String = ""
var archetype: String = "eager"
var prefers: Array[String] = []
var min_quality: int = 0
var quantity: int = 2
var loyalty: float = 0.0
var last_served_day: int = -99
var color: Color = Color.WHITE


static func generate(district_id: String, unique_id: String) -> CustomerProfile:
	var p := CustomerProfile.new()
	var keys: Array = GameData.customer_archetypes.keys()
	p.id = unique_id
	p.archetype = String(keys[randi() % keys.size()])
	var arch: Dictionary = GameData.customer_archetypes[p.archetype]

	var first := NpcDB.first_names()
	var last := NpcDB.last_names()
	p.display_name = "%s %s" % [first[randi() % first.size()], last[randi() % last.size()]]
	p.min_quality = int(arch.get("min_quality", 0))

	var q: Array = arch.get("quantity", [1, 2])
	p.quantity = randi_range(int(q[0]), int(q[1]))

	# Wealthier districts ask for better product.
	var wealth := float(GameData.district(district_id).get("wealth", 0.5))
	if wealth > 0.7 and randf() < 0.6:
		p.min_quality = maxi(p.min_quality, 2)

	# Most buyers want one or two specific products, weighted by district demand.
	var pool: Array[String] = []
	for pid in GameData.product_ids:
		var demand := EconomyService.demand_for(district_id, pid)
		var weight := int(clampf(demand * 4.0, 0.0, 8.0))
		for i in weight:
			pool.append(pid)
	if pool.is_empty():
		pool.append("pale_shard")
	p.prefers = [pool[randi() % pool.size()]]
	if randf() < 0.35:
		var second: String = pool[randi() % pool.size()]
		if not p.prefers.has(second):
			p.prefers.append(second)

	p.color = Color.from_hsv(randf(), 0.3, 0.85)
	return p


static func from_named(npc_id: String) -> CustomerProfile:
	var n: Dictionary = GameData.npc(npc_id)
	var p := CustomerProfile.new()
	p.id = npc_id
	p.display_name = String(n.get("name", npc_id))
	p.archetype = "collector"
	p.min_quality = int(n.get("min_quality", 2))
	p.quantity = 2
	var prefs: Array[String] = []
	for item in n.get("prefers", []):
		prefs.append(String(item))
	p.prefers = prefs
	p.color = n.get("color", Color.WHITE)
	return p


func opener_line() -> String:
	var lines: Array = DialogueDB.customer_openers().get(archetype, ["What have you got?"])
	return String(lines[randi() % lines.size()])


func archetype_label() -> String:
	return String(GameData.customer_archetypes.get(archetype, {}).get("label", "Buyer"))


func to_data() -> Dictionary:
	return {
		"id": id, "name": display_name, "archetype": archetype,
		"prefers": prefers, "min_quality": min_quality,
		"quantity": quantity, "loyalty": loyalty,
	}


func to_dict() -> Dictionary:
	var d := to_data()
	d["last_served_day"] = last_served_day
	d["color"] = [color.r, color.g, color.b]
	return d


static func from_dict(d: Dictionary) -> CustomerProfile:
	var p := CustomerProfile.new()
	p.id = String(d.get("id", ""))
	p.display_name = String(d.get("name", "Buyer"))
	p.archetype = String(d.get("archetype", "eager"))
	var prefs: Array[String] = []
	for item in d.get("prefers", []):
		prefs.append(String(item))
	p.prefers = prefs
	p.min_quality = int(d.get("min_quality", 0))
	p.quantity = int(d.get("quantity", 2))
	p.loyalty = float(d.get("loyalty", 0.0))
	p.last_served_day = int(d.get("last_served_day", -99))
	var c: Array = d.get("color", [1, 1, 1])
	if c.size() >= 3:
		p.color = Color(c[0], c[1], c[2])
	return p
