extends RefCounted

const HelperScript = preload("res://tests/shadow_summons_p0.gd")
const Data = preload("res://scripts/shadow_data.gd")
const Choices = preload("res://scripts/choice_manager.gd")
const EPS := 0.001
var t: SceneTree

func run(tree: SceneTree) -> void:
	t = tree
	var before: int = t.checks
	var failures: int = t.failures
	await data_and_card()
	await approach_windup_sweep_and_cooldown()
	await hitch_and_single_hit()
	await cast_exceptions_and_teleport()
	print("S7-IMPL-04 NEW RESULT: %d checks, %d failures" % [t.checks-before,t.failures-failures])

func fixture() -> Dictionary:
	var helper = HelperScript.new()
	helper.t = t
	var f: Dictionary = helper.fixture()
	f.helper = helper
	return f

func close(f: Dictionary) -> void:
	await f.helper.close(f)

func data_and_card() -> void:
	var store: CsvDataStore = t._store()
	var loaded: String = store.load_all()
	t.check(loaded.is_empty() and Data.validate(store).is_empty(),"S7-I4 actual sweep data validates")
	var shadow: Dictionary = store.get_row("shadow.csv","belion")
	var attack: Dictionary = store.get_row("shadow_attack.csv","belion_attack")
	t.check(shadow.Name_ko=="벨리온" and shadow.Search_radius==360.0 and shadow.Attack_id=="belion_attack" and shadow.Move_speed==320.0 and shadow.Chase_leash_distance==560.0 and shadow.Follow_distance==200.0 and shadow.Teleport_distance==900.0 and shadow.Sprite_path=="res://assets/art/shadow/belion_sheet.png","ART-04 Belion keeps common values with approved sprite path")
	t.check(attack.Damage==12 and attack.Range==300.0 and attack.Arc_deg==180.0 and attack.Interval_sec==1.5 and int(attack.Shape)==Data.Shape.SWEEP and attack.Windup_sec==0.4 and attack.Sweep_sec==0.3,"S7-I4 sweep approved starting values")
	var presentation := preload("res://scripts/shadow_afterimage.gd").presentation()
	t.check(int(float(presentation.Belion_chain_segments))==12 and float(presentation.Belion_trail_sec)==0.15,"S7-I4 chain presentation values")
	var choices := Choices.new()
	var f := fixture()
	choices.configure(f.player,store.get_table("choice.csv"),store.get_table("choice_level.csv"),store.get_row("choice_rule.csv","choice_rule_01"),f.summons)
	f.host.add_child(choices)
	t.check(choices.candidates().count("choice_belion")==1 and choices.records.choice_belion.Weight==10,"S7-I4 Belion card appears once with Ber weight")
	f.summons.summon("igrit")
	f.summons.summon("belion")
	t.check(f.summons.actors.size()==2 and not choices.candidates().has("choice_belion") and not choices.candidates().has("choice_igrit") and not choices.candidates().has("choice_charger_test"),"S7-I4 two-type limit excludes third shadow card")
	# Validation probes keep requested expectations, not production implementation values.
	attack.Windup_sec = 0.0
	t.check(Data.validate(store).contains("Windup_sec"),"S7-I4 nonpositive Windup_sec rejected")
	attack.Windup_sec = 0.4
	attack.Sweep_sec = INF
	t.check(Data.validate(store).contains("Sweep_sec"),"S7-I4 nonfinite Sweep_sec rejected")
	attack.Sweep_sec = 0.3
	store.get_row("shadow_attack.csv","igrit_attack").Windup_sec = 0.1
	t.check(Data.validate(store).contains("Windup_sec"),"S7-I4 fan rejects sweep-only timing value")
	store.get_row("shadow_attack.csv","igrit_attack").Windup_sec = null
	await close(f)

func approach_windup_sweep_and_cooldown() -> void:
	var f := fixture()
	f.player.position = Vector2.ZERO
	var belion = f.summons.summon("belion")
	belion.position = Vector2.ZERO
	var target = t._spawn(f,Vector2(300,0),100)
	belion.tick(1.0)
	t.check(belion.cast_active and absf(belion.position.distance_to(target.position)-240.0)<=EPS,"S7-I4 approach stops and starts at Range times0.8")
	var cast_position: Vector2 = belion.position
	var fixed_facing: Vector2 = belion.facing
	target.position = cast_position+Vector2(0,200)
	belion.tick(0.2)
	t.check(belion.cast_active and belion.position==cast_position and belion.facing==fixed_facing and belion.sweep_visual_state().windup,"S7-I4 windup stays still with direction fixed")
	var low = t._spawn(f,cast_position+Vector2.RIGHT.rotated(-PI/4.0)*150.0,100)
	var center = t._spawn(f,cast_position+Vector2(150,0),100)
	var high = t._spawn(f,cast_position+Vector2.RIGHT.rotated(PI/4.0)*150.0,100)
	var outside_range = t._spawn(f,cast_position+Vector2(301,0),100)
	var outside_angle = t._spawn(f,cast_position+Vector2(-150,0),100)
	belion.tick(0.2)
	t.check(absf(angle_difference(fixed_facing.angle(),belion.sweep_current_angle)+PI/2.0)<=EPS,"S7-I4 sweep begins at negative half arc")
	belion.tick(0.15)
	t.check(low.hp==88 and center.hp==88 and high.hp==100,"S7-I4 first half advances uniformly and hits only passed angles")
	belion.tick(0.15)
	t.check(low.hp==88 and center.hp==88 and high.hp==88 and outside_range.hp==100 and outside_angle.hp==100,"S7-I4 full sweep has no duplicate and excludes range or angle outside")
	t.check(not belion.cast_active and absf(belion.ready_at-3.2)<=EPS and not belion.sweep_forward,"S7-I4 sweep end starts Interval and flips next direction")
	target.position = belion.position+Vector2(280,0)
	var waiting: Vector2 = belion.position
	belion.tick(0.5)
	t.check(belion.position==waiting and not belion.cast_active,"S7-I4 cooldown waits in place while target remains in Range")
	target.position = belion.position+Vector2(340,0)
	belion.tick(0.1)
	t.check(belion.position!=waiting and belion.position.distance_to(target.position)<340.0,"S7-I4 cooldown moves when target is outside Range")
	target.position = belion.position+Vector2(200,0)
	belion.tick(0.9)
	t.check(belion.cast_active and belion.sweep_sign==-1.0 and absf(angle_difference(belion.facing.angle(),belion.sweep_current_angle)-PI/2.0)<=EPS,"S7-I4 next sweep alternates from positive half arc")
	await close(f)

func hitch_and_single_hit() -> void:
	var f := fixture()
	f.player.position = Vector2.ZERO
	var belion = f.summons.summon("belion")
	belion.position = Vector2.ZERO
	var target = t._spawn(f,Vector2(240,0),100)
	belion.tick(0.0)
	var low = t._spawn(f,Vector2.RIGHT.rotated(-PI/3.0)*200.0,100)
	var high = t._spawn(f,Vector2.RIGHT.rotated(PI/3.0)*200.0,100)
	belion.tick(0.7)
	t.check(target.hp==88 and low.hp==88 and high.hp==88,"S7-I4 one hitch spanning windup and sweep misses no passed enemy")
	belion.tick(0.5)
	t.check(target.hp==88 and low.hp==88 and high.hp==88,"S7-I4 completed sweep never damages same enemies again")
	await close(f)

func cast_exceptions_and_teleport() -> void:
	var f := fixture()
	f.player.position = Vector2.ZERO
	var belion = f.summons.summon("belion")
	belion.position = Vector2.ZERO
	var target = t._spawn(f,Vector2(240,0),100)
	belion.tick(0.0)
	var other = f.summons.summon("igrit")
	other.position = Vector2(500,0)
	var overlap = t._spawn(f,Vector2(10,0),100)
	f.player.position = Vector2(-10,0)
	var before := [belion.position,f.player.position]
	f.manager._resolve_contact_pair(belion,f.player)
	t.check([belion.position,f.player.position]==before,"S7-I4 windup excludes player push pair")
	f.player.position = Vector2(-500,0)
	before = [belion.position,overlap.position]
	f.manager._resolve_contact_pair(belion,overlap)
	t.check([belion.position,overlap.position]==before,"S7-I4 windup excludes enemy push pair")
	overlap.position = Vector2(500,100)
	other.position = Vector2(10,0)
	before = [belion.position,other.position]
	f.manager._resolve_contact_pair(belion,other)
	t.check([belion.position,other.position]==before,"S7-I4 windup excludes shadow push pair")
	other.position = Vector2(500,0)
	overlap.position = Vector2(10,0)
	before = [belion.position,overlap.position]
	f.manager.push_iterations = 1
	f.manager._resolve_contact_pushes()
	t.check([belion.position,overlap.position]==before,"S7-I4 optimized push pass honors sweep exclusion")
	f.player.position = Vector2(-600,0)
	belion.tick(0.1)
	t.check(belion.cast_active and belion.position==Vector2.ZERO,"S7-I4 sweep cast ignores leash cancellation")
	f.player.position = Vector2(-900,0)
	belion.tick(0.0)
	t.check(not belion.cast_active and belion.position.distance_to(f.player.position)<=200.001,"S7-I4 teleport threshold cancels sweep and relocates by common rule")
	await close(f)
