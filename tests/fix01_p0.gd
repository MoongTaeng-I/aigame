extends RefCounted
const UI = preload("res://scripts/system_ui.gd")
const Budget = preload("res://scripts/impact_budget.gd")

func run(t: SceneTree) -> void:
	for key in ["panel","icon","frame"]:
		var style := UI.THEME.get_stylebox(key,"Panel" if key=="panel" else "SystemUI") as StyleBoxTexture
		t.check(style.axis_stretch_horizontal==0 and style.axis_stretch_vertical==0,"FIX01 stretch edges "+key)
	for key in ["normal","hover","pressed","disabled"]:
		var style := UI.THEME.get_stylebox(key,"Button") as StyleBoxTexture
		t.check(style.axis_stretch_horizontal==0 and style.axis_stretch_vertical==0,"FIX01 stretch button "+key)
	var f: Dictionary = preload("res://tests/fx03_p0.gd").new().fixture(t)
	var belion: Node2D = f.shadows.summon("belion")
	belion.position = Vector2.ZERO
	var victims: Array = []
	for i in range(30):
		f.manager._spawn_from_row({"Enemy_id":"enemy_01","Spawn_count":1})
		var enemy: Node2D = f.manager.get_living_enemies().back()
		enemy.position = Vector2(150+(i%10)*12,-60+(i/10)*60)
		victims.append({"enemy":enemy,"hp":enemy.hp})
	belion.target = victims[0].enemy
	belion.start_attack()
	belion.tick(0.7)
	t.check(victims.all(func(v: Dictionary) -> bool: return v.enemy.hp==v.hp-12),"FIX01 capped visual frame still damages all30 once at existing sweep time")
	var fx: Node = belion.attack_fx
	t.check(fx.burst_hits==3 and not belion.cast_active,"FIX01 at most three victim bursts per actual sweep")
	t.check(int(Budget.state().used.get(Budget.scope(fx),0))<=40,"FIX01 shared number/hit/particle frame budget40")
	t.check(fx.impacts.slots.filter(func(s: Dictionary) -> bool: return s.active and s.kind=="shard").size()>=7,"FIX01 reserved endpoint burst survives dense final frame")
	f.host.free(); await t.process_frame
	await preload("res://tests/ui_glyph_p0.gd").new().run(t)
	var flow := preload("res://scripts/game_flow.gd").new(); t.root.add_child(flow)
	while flow.state=="loading": await t.process_frame
	var ui: Control = flow.ui
	var image: Control = ui.cards[1].get_node("Art")
	var frame: NinePatchRect = ui.cards[1].get_child(1)
	t.check(frame.position==Vector2(-40,-40) and frame.size==image.size+Vector2(80,80) and frame.axis_stretch_horizontal==0,"FIX01 region frame surrounds image with full patch margins")
	var arrows: Array = []
	for child in ui.get_children():
		if child is Button and child.text in ["‹","›"]: arrows.append(child)
	t.check(arrows[0].position.x+arrows[0].size.x<=320-16 and arrows[1].position.x>=960+16,"FIX01 arrows16px outside central frame")
	t.check(ui.cards[2].position.x-24>=arrows[1].position.x+arrows[1].size.x+16,"FIX01 side preview16px away from arrow")
	flow.free(); t.paused = false; await t.process_frame
