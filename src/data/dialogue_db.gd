class_name DialogueDB
extends RefCounted
## Branching dialogue trees for named characters.
##
## A node is {text, speaker?, options:[{label, next?, action?, arg?, cond?}]}.
## Actions handled by DialogueScreen -> DialogueRunner:
##   end, shop, bulk, hire, vehicles, teach, mission, sell, bank, none
## Conditions are Dictionaries evaluated by MissionService.check_requirement().

static func trees() -> Dictionary:
	return {
		# =================================================================
		"mira_vance": {
			"root": {
				"text": "There you are. You look like a man who has been counting coins in his pocket without taking them out.",
				"options": [
					{"label": "I need work.", "next": "work"},
					{"label": "What is this place, really?", "next": "lore"},
					{"label": "Later.", "action": "end"},
				],
			},
			"work": {
				"text": "Work I have. Whether you want it after you hear it is your business.",
				"options": [
					{"label": "Tell me.", "action": "mission"},
					{"label": "Back.", "next": "root"},
				],
			},
			"lore": {
				"text": "Cobalt Bay runs on light nobody licensed. The Bureau calls it a public safety matter. The Bureau also has a very nice building. Draw your own conclusions.",
				"options": [
					{"label": "And you?", "next": "lore2"},
					{"label": "Back.", "next": "root"},
				],
			},
			"lore2": {
				"text": "I introduce people. That is the whole trick. Everything else in this city is just two people who have not met yet.",
				"options": [{"label": "Back.", "next": "root"}],
			},
		},

		# =================================================================
		"dez_okonkwo": {
			"root": {
				"text": "Pell's Corner. If it's on a shelf it's for sale, if it's behind me it's negotiable.",
				"options": [
					{"label": "Show me the shelves.", "action": "shop"},
					{"label": "Got anything for me?", "action": "mission"},
					{"label": "Just looking.", "action": "end"},
				],
			},
		},

		# =================================================================
		"saoirse_lam": {
			"root": {
				"text": "You're the one from the water. I take volume, I pay under list, and I never remember a face. Those are the terms.",
				"options": [
					{"label": "Let's talk volume.", "action": "bulk"},
					{"label": "Any work going?", "action": "mission"},
					{"label": "Not today.", "action": "end"},
				],
			},
		},

		# =================================================================
		"odette_sang": {
			"root": {
				"text": "Mind the tray. That culture has been alive longer than your business has.",
				"options": [
					{"label": "I want to buy materials.", "action": "shop"},
					{"label": "Teach me a lattice.", "next": "teach"},
					{"label": "Anything you need doing?", "action": "mission"},
					{"label": "I'll leave you to it.", "action": "end"},
				],
			},
			"teach": {
				"text": "I can teach anything I know. What I know took eleven years and cost me a career, so I do not teach it for free.",
				"options": [
					{"label": "Show me what's available.", "action": "teach"},
					{"label": "Back.", "next": "root"},
				],
			},
		},

		# =================================================================
		"teo_marchetti": {
			"root": {
				"text": "Every vehicle on this forecourt has papers. Some of the papers are even for that vehicle.",
				"options": [
					{"label": "Show me what's for sale.", "action": "vehicles"},
					{"label": "Need a hand with anything?", "action": "mission"},
					{"label": "Another time.", "action": "end"},
				],
			},
		},

		# =================================================================
		"wendell_pike": {
			"root": {
				"text": "People need work. You need people. I take a finder's fee and everybody pretends I did something difficult.",
				"options": [
					{"label": "Who've you got?", "action": "hire"},
					{"label": "Anything else going?", "action": "mission"},
					{"label": "Not now.", "action": "end"},
				],
			},
		},

		# =================================================================
		"grip_halloran": {
			"root": {
				"text": "You've been busy. Mr Brandt notices busy. Busy is how people end up owing.",
				"options": [
					{"label": "I don't owe anyone.", "next": "defiant"},
					{"label": "What does he want?", "next": "terms"},
					{"label": "Say nothing.", "action": "end"},
				],
			},
			"terms": {
				"text": "A percentage. Paid in product, weekly, at this gate. In exchange nobody puts a crowbar through your container.",
				"options": [
					{"label": "Fine. For now.", "action": "mission"},
					{"label": "No.", "next": "defiant"},
				],
			},
			"defiant": {
				"text": "Everybody says that once. It's the only free one you get.",
				"options": [{"label": "Walk away.", "action": "end"}],
			},
		},

		# =================================================================
		"ivo_brandt": {
			"root": {
				"text": "Sit. You've built something out of a rusted box and a good ear, which is more than most of my lieutenants managed.",
				"options": [
					{"label": "You've been watching me.", "next": "watch"},
					{"label": "What do you want?", "action": "mission"},
					{"label": "Leave.", "action": "end"},
				],
			},
			"watch": {
				"text": "I watch everything that grows. Growth is either a supplier or a competitor and the paperwork differs enormously.",
				"options": [{"label": "Back.", "next": "root"}],
			},
		},

		# =================================================================
		"row_calder": {
			"root": {
				"text": "Civic Standards. I am not arresting you today, which I want you to understand is a choice I am making.",
				"options": [
					{"label": "Then what do you want?", "action": "mission"},
					{"label": "I've done nothing.", "next": "nothing"},
					{"label": "Walk away.", "action": "end"},
				],
			},
			"nothing": {
				"text": "You've done a great deal. What you have not done is anything I can put in front of a magistrate. Yet.",
				"options": [{"label": "Back.", "next": "root"}],
			},
		},

		# =================================================================
		"nadia_quill": {
			"root": {
				"text": "You're the light person. Don't look startled, everyone at the club calls you that.",
				"options": [
					{"label": "I have something you'll like.", "action": "sell"},
					{"label": "You mentioned work.", "action": "mission"},
					{"label": "Enjoy your evening.", "action": "end"},
				],
			},
		},
	}


## Generic lines used by procedural customers, keyed by archetype.
static func customer_openers() -> Dictionary:
	return {
		"cautious": [
			"Keep your voice down. What have you got?",
			"Quick. Before that patrol comes back round.",
			"I'll take one if it's clean. Only if it's clean.",
		],
		"eager": [
			"Tell me you've got something on you.",
			"I've got cash and about four minutes.",
			"Whatever's brightest. I'm not fussy.",
		],
		"collector": [
			"I'm told you can source properly. Show me.",
			"I want Radiant or better. I'll pay for it.",
			"If it flickers I'm not interested.",
		],
		"reseller": [
			"Bulk. What's your best rate?",
			"I move volume out of the Flats. Talk numbers.",
			"Small lots waste both our time.",
		],
		"tourist": [
			"Sorry, is this how it's done here?",
			"My friend said to ask you about the blue ones.",
			"I've got money. I have no idea what I'm doing.",
		],
	}


static func refusal_lines() -> PackedStringArray:
	return PackedStringArray([
		"That's not what I asked for.",
		"Too rough. Come back when you've got a clean one.",
		"Not at that price it isn't.",
		"Someone's watching. Forget it.",
	])
