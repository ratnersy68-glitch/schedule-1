class_name CityGraph
extends RefCounted
## Waypoint navigation for pedestrians and traffic.
##
## Deliberately not a NavigationMesh: baking one at runtime is slow on a phone
## and overkill for a city built from a grid. A hand-generated waypoint graph
## costs almost nothing to query, gives NPCs believable pavement-following
## behaviour, and lets a hundred agents path without a physics server round
## trip.

class Node2:
	var id: int
	var pos: Vector3
	var district: String
	var kind: String          ## "walk" | "road" | "door" | "crossing"
	var links: PackedInt32Array = PackedInt32Array()

	func _init(node_id: int, position: Vector3, district_id: String, node_kind: String) -> void:
		id = node_id
		pos = position
		district = district_id
		kind = node_kind


var nodes: Array[Node2] = []
## Spatial hash so "nearest node" is O(1) instead of O(n) per NPC per second.
var _buckets: Dictionary = {}
const BUCKET := 12.0


func add_node(pos: Vector3, district: String, kind: String = "walk") -> int:
	var n := Node2.new(nodes.size(), pos, district, kind)
	nodes.append(n)
	var key := _bucket_key(pos)
	if not _buckets.has(key):
		_buckets[key] = PackedInt32Array()
	var arr: PackedInt32Array = _buckets[key]
	arr.append(n.id)
	_buckets[key] = arr
	return n.id


func link(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= nodes.size() or b >= nodes.size():
		return
	if not nodes[a].links.has(b):
		nodes[a].links.append(b)
	if not nodes[b].links.has(a):
		nodes[b].links.append(a)


func _bucket_key(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / BUCKET)), int(floor(pos.z / BUCKET)))


## Nearest node, optionally restricted to a kind ("walk" for pedestrians,
## "road" for vehicles).
func nearest(pos: Vector3, kind: String = "") -> int:
	var best := -1
	var best_d := INF
	var key := _bucket_key(pos)
	for radius in range(0, 5):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if radius > 0 and absi(dx) != radius and absi(dz) != radius:
					continue
				var ids: PackedInt32Array = _buckets.get(key + Vector2i(dx, dz), PackedInt32Array())
				for id in ids:
					var n := nodes[id]
					if kind != "" and n.kind != kind:
						continue
					var d := n.pos.distance_squared_to(pos)
					if d < best_d:
						best_d = d
						best = id
		if best >= 0 and radius >= 1:
			break
	return best


## A* over the waypoint graph. Returns world positions, start excluded.
func find_path(from: Vector3, to: Vector3, kind: String = "") -> PackedVector3Array:
	var start := nearest(from, kind)
	var goal := nearest(to, kind)
	var out := PackedVector3Array()
	if start < 0 or goal < 0:
		return out
	if start == goal:
		out.append(nodes[goal].pos)
		return out

	var open: Array[int] = [start]
	var came := {}
	var g := {start: 0.0}
	var f := {start: nodes[start].pos.distance_to(nodes[goal].pos)}
	var closed := {}
	var guard := 0

	while not open.is_empty() and guard < 4000:
		guard += 1
		# Small graphs: a linear scan beats the cost of maintaining a heap.
		var best_i := 0
		for i in open.size():
			if float(f.get(open[i], INF)) < float(f.get(open[best_i], INF)):
				best_i = i
		var current: int = open[best_i]
		if current == goal:
			return _reconstruct(came, current)
		open.remove_at(best_i)
		closed[current] = true

		for neighbour in nodes[current].links:
			if closed.has(neighbour):
				continue
			if kind != "" and nodes[neighbour].kind != kind and nodes[neighbour].kind != "door":
				continue
			var tentative: float = float(g.get(current, INF)) \
				+ nodes[current].pos.distance_to(nodes[neighbour].pos)
			if tentative < float(g.get(neighbour, INF)):
				came[neighbour] = current
				g[neighbour] = tentative
				f[neighbour] = tentative + nodes[neighbour].pos.distance_to(nodes[goal].pos)
				if not open.has(neighbour):
					open.append(neighbour)
	return out


func _reconstruct(came: Dictionary, current: int) -> PackedVector3Array:
	var chain: Array[int] = [current]
	while came.has(current):
		current = came[current]
		chain.append(current)
	chain.reverse()
	var out := PackedVector3Array()
	for i in range(1, chain.size()):
		out.append(nodes[chain[i]].pos)
	return out


## A random walkable point in a district, for wandering and civilian spawns.
func random_node_in(district: String, kind: String = "walk") -> int:
	var candidates: Array[int] = []
	for n in nodes:
		if n.district == district and n.kind == kind:
			candidates.append(n.id)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]


func position_of(id: int) -> Vector3:
	if id < 0 or id >= nodes.size():
		return Vector3.ZERO
	return nodes[id].pos


func node_count() -> int:
	return nodes.size()


func clear() -> void:
	nodes.clear()
	_buckets.clear()
