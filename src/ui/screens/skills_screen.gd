class_name SkillsScreen
extends GameScreen
## The four progression trees.

var _tree: String = "hustle"


func build_content() -> void:
	set_titles("Skills", "")
	refresh()


func refresh() -> void:
	if content == null:
		return
	clear_content()
	set_titles("Skills", "%d point%s to spend" %
		[GameState.skill_points, "" if GameState.skill_points == 1 else "s"])

	var head := UIKit.panel(UIKit.BG_PANEL)
	var hv := UIKit.vbox(4)
	head.add_child(hv)
	hv.add_child(UIKit.stat_line("Level", "%d" % GameState.level, UIKit.ACCENT))
	var bar := UIKit.progress(GameState.xp_progress(), UIKit.ACCENT, 8.0)
	hv.add_child(bar)
	var next_xp := GameConfig.xp_for_level(GameState.level + 1)
	hv.add_child(UIKit.stat_line("Experience", "%d / %d" % [GameState.xp, next_xp]))
	content.add_child(head)

	var tabs := UIKit.hbox(6)
	for t in SkillDB.TREES:
		var b := UIKit.button(String(SkillDB.TREE_LABELS[t]),
			"primary" if t == _tree else "default")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			_tree = t
			refresh())
		tabs.add_child(b)
	content.add_child(tabs)
	content.add_child(UIKit.label(String(SkillDB.TREE_BLURBS[_tree]), 13, UIKit.TEXT_DIM))

	for skill_id in SkillDB.skills_in_tree(_tree):
		content.add_child(_skill_row(skill_id))


func _skill_row(skill_id: String) -> Control:
	var s: Dictionary = GameData.skill(skill_id)
	var rank := GameState.skill_rank(skill_id)
	var maximum := int(s.get("ranks", 1))
	var row := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(6)
	row.add_child(v)

	var head := UIKit.hbox(8)
	var n := UIKit.label(String(s.get("name", skill_id)), 16)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UIKit.label("%d / %d" % [rank, maximum], 13, UIKit.TEXT_DIM))
	v.add_child(head)

	var pips := UIKit.hbox(4)
	for i in maximum:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(0, 5)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.color = UIKit.ACCENT if i < rank else UIKit.LINE
		pips.add_child(pip)
	v.add_child(pips)
	v.add_child(UIKit.body(String(s.get("desc", ""))))

	var current := GameState.skill_effect(String(s.get("effect", "")))
	if current != 0.0:
		v.add_child(UIKit.stat_line("Current bonus", "%+d%%" % int(current * 100.0), UIKit.GOOD))

	var requires: Dictionary = s.get("requires", {})
	if not requires.is_empty():
		var parts: Array[String] = []
		for req_id in requires:
			parts.append("%s %d" % [GameData.skill(req_id).get("name", req_id), int(requires[req_id])])
		v.add_child(UIKit.stat_line("Requires", ", ".join(parts), UIKit.TEXT_FAINT))

	if rank < maximum:
		var cost := SkillDB.cost_for_rank(skill_id, rank + 1)
		var b := UIKit.button("Buy rank %d  (%d pt%s)" % [rank + 1, cost, "" if cost == 1 else "s"],
			"primary")
		b.disabled = not GameState.can_purchase_skill(skill_id)
		b.pressed.connect(func():
			if GameState.purchase_skill(skill_id):
				AudioDirector.play_ui("levelup")
				refresh())
		v.add_child(b)
	else:
		v.add_child(UIKit.label("Mastered", 13, UIKit.GOOD))
	return row
