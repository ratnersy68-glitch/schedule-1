class_name ObjectPool
extends RefCounted
## A fixed-size pool of scene nodes.
##
## Mobile allocators do not like churn: spawning and freeing NPCs, pickups or
## effects every few seconds produces frame spikes and heap fragmentation. The
## pool allocates once, then hands out inactive members and takes them back.
##
## Members must implement `release()` and expose a `visible` property, which
## every Node3D and Control already does.

signal acquired(node: Node)
signal released(node: Node)

var members: Array[Node] = []
var _release_method: String = "release"


## `factory` is a Callable returning a fresh node. `parent` adopts them all.
func _init(factory: Callable, parent: Node, count: int,
		release_method: String = "release") -> void:
	_release_method = release_method
	for i in count:
		var node: Node = factory.call()
		parent.add_child(node)
		if node.has_method(_release_method):
			node.call(_release_method)
		members.append(node)


## Returns an inactive member, or null when the pool is exhausted. Exhaustion
## is a normal, expected condition: it is the budget doing its job.
func acquire() -> Node:
	for node in members:
		if not _is_active(node):
			acquired.emit(node)
			return node
	return null


func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method(_release_method):
		node.call(_release_method)
	released.emit(node)


func release_all() -> void:
	for node in members:
		release(node)


func active_count() -> int:
	var n := 0
	for node in members:
		if _is_active(node):
			n += 1
	return n


func size() -> int:
	return members.size()


func for_each_active(fn: Callable) -> void:
	for node in members:
		if _is_active(node):
			fn.call(node)


func _is_active(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	return bool(node.get("visible"))
