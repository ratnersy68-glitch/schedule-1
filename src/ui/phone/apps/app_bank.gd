class_name AppBank
extends PhoneApp
## Bay Mutual: launder cash into a clean balance and read the ledger.

static var _amount: int = 100


func _init() -> void:
	super._init("bank", "Bank", "BNK", UIKit.MONEY)


func build(container: VBoxContainer) -> void:
	var panel := UIKit.panel(UIKit.BG_PANEL)
	var v := UIKit.vbox(4)
	panel.add_child(v)
	v.add_child(UIKit.stat_line("Cash on you",
		GameConfig.format_money(GameState.cash), UIKit.MONEY))
	v.add_child(UIKit.stat_line("Clean balance",
		GameConfig.format_money(GameState.bank), UIKit.MONEY))
	v.add_child(UIKit.stat_line("Net worth",
		GameConfig.format_money(GameState.net_worth()), UIKit.ACCENT))
	v.add_child(UIKit.separator())
	v.add_child(UIKit.stat_line("Lifetime earned",
		GameConfig.format_money(GameState.lifetime_earned), UIKit.GOOD))
	v.add_child(UIKit.stat_line("Lifetime spent",
		GameConfig.format_money(GameState.lifetime_spent), UIKit.BAD))
	v.add_child(UIKit.stat_line("Daily costs",
		GameConfig.format_money(GameState.daily_payroll() + GameState.daily_upkeep_total()),
		UIKit.BAD))
	container.add_child(panel)

	container.add_child(UIKit.label("LAUNDER", 11, UIKit.TEXT_FAINT))
	var fee_rate := GameConfig.LAUNDER_FEE
	for prop in GameState.all_owned_properties():
		fee_rate -= float(GameData.property(prop.id).get("launder_bonus", 0.0))
	fee_rate = maxf(0.0, fee_rate)
	container.add_child(UIKit.body(
		"Cash you cannot explain is cash you cannot spend on property. " +
		"Fee is %d%%. Retail fronts reduce it." % int(fee_rate * 100.0)))

	var amounts := UIKit.hbox(6)
	for value in [100, 500, 2500, 10000]:
		var b := UIKit.button(GameConfig.format_money(value),
			"primary" if _amount == value else "default")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(func():
			_amount = value
			_refresh())
		amounts.add_child(b)
	container.add_child(amounts)

	var deposit := UIKit.button("Deposit %s  (fee %s)" % [GameConfig.format_money(_amount),
		GameConfig.format_money(int(_amount * fee_rate))], "good")
	deposit.disabled = GameState.cash < _amount
	deposit.pressed.connect(func():
		if GameState.deposit(_amount):
			EventBus.toast_requested.emit("Deposited " + GameConfig.format_money(_amount), "money")
		_refresh())
	container.add_child(deposit)

	var withdraw := UIKit.button("Withdraw " + GameConfig.format_money(_amount))
	withdraw.disabled = GameState.bank < _amount
	withdraw.pressed.connect(func():
		if GameState.withdraw(_amount):
			EventBus.toast_requested.emit("Withdrew " + GameConfig.format_money(_amount), "money")
		_refresh())
	container.add_child(withdraw)

	container.add_child(UIKit.label("RECENT", 11, UIKit.TEXT_FAINT))
	if GameState.transactions.is_empty():
		container.add_child(UIKit.body("Nothing yet."))
	for i in mini(18, GameState.transactions.size()):
		var t: Dictionary = GameState.transactions[i]
		var amount := int(t.get("amount", 0))
		container.add_child(UIKit.stat_line(
			"D%d %s  %s" % [int(t.get("day", 1)),
				GameConfig.format_clock(float(t.get("hour", 0.0))), String(t.get("reason", ""))],
			GameConfig.format_money(amount),
			UIKit.MONEY if amount > 0 else UIKit.BAD))


func _refresh() -> void:
	if phone != null and phone.has_method("refresh_current"):
		phone.refresh_current()
