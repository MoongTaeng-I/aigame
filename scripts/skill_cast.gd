extends RefCounted

# Shared cast lifecycle: immutable per-use stats, scheduled ticks, completion cooldown.
# The injected tick callback owns the effect; this class owns no enemy/death logic.
var level: int = 0
var levels: Array = []
var implemented: bool = false
var active: bool = false
var snapshot: Dictionary = {}
var started_at: float = 0.0
var completed_at: float = 0.0
var cooldown_until: float = 0.0
var hits_done: int = 0
var on_tick: Callable
var mode: String = "ticks"
var completion_field: String = "Duration_sec"

func configure(rows: Array, initial_level: int, callback: Callable, cast_mode: String = "ticks", duration_field: String = "Duration_sec") -> void:
	levels = rows.duplicate(true)
	levels.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.Level)<int(b.Level))
	level = initial_level
	on_tick = callback
	implemented = callback.is_valid()
	mode = cast_mode
	completion_field = duration_field

func max_level() -> int:
	return int(levels.back().Level) if not levels.is_empty() else 0

func can_start(now: float) -> bool:
	return implemented and level>=1 and not active and now+0.000000001>=cooldown_until

func start(now: float) -> bool:
	if not can_start(now):
		return false
	snapshot = levels[level-1].duplicate(true)
	started_at = now
	hits_done = 0
	active = true
	if mode!="ticks":
		on_tick.call(snapshot,now)
		if mode=="instant":
			_finish(now)
	advance(now)
	return true

func advance(now: float) -> void:
	if mode!="ticks":
		if active and now+0.000000001>=started_at+float(snapshot[completion_field]):
			_finish(started_at+float(snapshot[completion_field]))
		return
	while active:
		var tick_at := started_at + hits_done*float(snapshot.Hit_interval_sec)
		if now+0.000000001<tick_at:
			return
		on_tick.call(snapshot,tick_at)
		hits_done += 1
		if hits_done>=int(snapshot.Hits):
			_finish(tick_at)

func _finish(at: float) -> void:
	active = false
	completed_at = at
	cooldown_until = completed_at + float(snapshot.Cooldown_sec)

func cancel(now: float) -> void:
	if active:
		_finish(now)
