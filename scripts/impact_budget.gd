extends RefCounted

static func state() -> Dictionary:
	if not Engine.has_meta(&"impact_budget"):
		Engine.set_meta(&"impact_budget",{"frame":-1,"used":{},"endpoints":{}})
	return Engine.get_meta(&"impact_budget")

static func reserve_endpoint(key: int, actor: Node, count: int) -> void:
	state().endpoints[key] = {"actor":weakref(actor),"count":count}

static func scope(node: Node) -> int:
	var top := node
	while top.get_parent()!=null and not top.get_parent() is Window:
		top = top.get_parent()
	return top.get_instance_id()

static func take(key: int, maximum: int) -> bool:
	var budget := state()
	var current := Engine.get_physics_frames()
	if current!=budget.frame:
		budget.frame = current
		budget.used.clear()
	var count := int(budget.used.get(key,0))
	var reserve := 0
	if budget.endpoints.has(key):
		var actor: Node = budget.endpoints[key].actor.get_ref()
		if is_instance_valid(actor) and actor.cast_active: reserve = int(budget.endpoints[key].count)
		else: budget.endpoints.erase(key)
	if count>=maximum-reserve: return false
	budget.used[key] = count+1
	return true
