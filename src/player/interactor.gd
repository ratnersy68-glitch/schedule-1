class_name Interactor
extends Node3D
## Finds the Interactable the player is looking at.
##
## Uses a sphere shape-cast rather than a thin ray: on a phone you are aiming
## with your thumb, and a little forgiveness is the difference between the
## game feeling responsive and feeling broken.

signal target_changed(target: Interactable)

const LAYER_INTERACTABLE := 1 << 3
const LAYER_WORLD := 1

@export var range_m: float = GameConfig.INTERACT_RANGE
@export var radius: float = GameConfig.INTERACT_RADIUS

var current: Interactable = null

var _shape := SphereShape3D.new()
var _params := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _accum := 0.0


func _ready() -> void:
	_shape.radius = radius
	_params.shape = _shape
	_params.collision_mask = LAYER_INTERACTABLE
	_params.collide_with_areas = true
	_params.collide_with_bodies = false
	_ray.collision_mask = LAYER_WORLD
	_ray.collide_with_areas = false


## Polled at 20Hz rather than every frame - interaction targets do not need
## 60Hz precision and this is a physics query on a mobile CPU.
func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum < 0.05:
		return
	_accum = 0.0
	_update_target()


func _update_target() -> void:
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var origin := global_position
	var dir := -global_transform.basis.z
	var best: Interactable = null
	var best_score := -INF

	# Sample a few points along the aim line and take the best candidate.
	for step in 5:
		var t := 0.25 + float(step) * (range_m - 0.25) / 4.0
		_params.transform = Transform3D(Basis.IDENTITY, origin + dir * t)
		var hits := space.intersect_shape(_params, 6)
		for hit in hits:
			var area = hit.get("collider")
			if not (area is Interactable):
				continue
			var it: Interactable = area
			if not it.enabled:
				continue
			var to_target: Vector3 = it.focus_point() - origin
			var dist := to_target.length()
			if dist > range_m + 1.0:
				continue
			# Prefer things near the centre of the screen and close by.
			var aim := dir.dot(to_target.normalized())
			var score := aim * 2.0 - dist * 0.25
			if score > best_score and _has_line_of_sight(space, origin, it):
				best_score = score
				best = it
		if best != null:
			break

	if best != current:
		current = best
		target_changed.emit(current)


func _has_line_of_sight(space: PhysicsDirectSpaceState3D, origin: Vector3,
		target: Interactable) -> bool:
	_ray.from = origin
	_ray.to = target.focus_point()
	var hit := space.intersect_ray(_ray)
	if hit.is_empty():
		return true
	# Allow a little slop: a doorframe should not block its own door handle.
	return origin.distance_to(hit["position"]) > origin.distance_to(target.focus_point()) - 0.6
