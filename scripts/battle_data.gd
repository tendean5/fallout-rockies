# Battle data — original species/weapons/items/zone palettes.
# Pure data + helpers. Preloaded statically by the battle scene and overworld.
# No class; static funcs only.

const HERO_MAX_HP := 40

static func weapons() -> Dictionary:
	return {
		"rust_pistol": {"id": "rust_pistol", "name": "Rust Pistol", "power": 9, "accuracy": 0.88, "type": "rust"},
		"dust_axe":    {"id": "dust_axe",   "name": "Dust Axe",   "power": 12, "accuracy": 0.78, "type": "dust"},
		"smoke_rifle": {"id": "smoke_rifle", "name": "Smoke Rifle", "power": 11, "accuracy": 0.82, "type": "smoke"},
	}

static func items() -> Dictionary:
	return {
		"stim":   {"id": "stim",   "name": "Stimpack", "heal": 20},
		"medkit": {"id": "medkit", "name": "Medkit",   "heal": 40},
	}

static func species() -> Dictionary:
	return {
		"rustjaw":   {"id": "rustjaw",   "name": "Rustjaw",   "types": ["rust"],  "weak": "smoke", "resist": "wind",  "max_hp": 30, "power": 7, "accuracy": 0.82, "spd": 10, "wild_weight": 3},
		"silt_pup":   {"id": "silt_pup",   "name": "Silt Pup",  "types": ["dust"],  "weak": "rust",  "resist": "dust",  "max_hp": 34, "power": 8, "accuracy": 0.74, "spd": 12, "wild_weight": 3},
		"smoke_wasp": {"id": "smoke_wasp", "name": "Smoke Wasp", "types": ["smoke"], "weak": "dust",  "resist": "smoke", "max_hp": 22, "power": 9, "accuracy": 0.78, "spd": 16, "wild_weight": 2},
	}

static func starting_kid() -> Dictionary:
	return {
		"level": 1,
		"max_hp": HERO_MAX_HP,
		"current_hp": HERO_MAX_HP,
		"exp": 0,
		"weapons": ["rust_pistol"],
		"active_weapon": "rust_pistol",
		"items": {"stim": 3, "medkit": 1},
		"hold": false,
	}

static func make_enemy(id: String, level: int) -> Dictionary:
	var base: Dictionary = species()[id].duplicate(true)
	base["level"] = level
	var extra := (level - 1) * 6
	base["max_hp"] = base["max_hp"] + extra
	base["hp"] = base["max_hp"]
	return base

static func enemy_for(id: String, kid_level: int) -> Dictionary:
	var level := kid_level + randi() % 2
	return make_enemy(id, level)

static func pick_species(region: String) -> String:
	# Ridley the caller determines the zone; M1 picks deterministically by region
	# with a tiny jitter so repeats don't feel mechanical.
	match region:
		"The Woods": return "silt_pup"
		"The Platte": return "silt_pup"
		"The Peaks", "The High Country", "The High Country Pass": return "smoke_wasp"
		_: return "rustjaw"

# Per-zone backdrop palettes (bg, accent, ground, panel, text)
static func zone_palette(region: String) -> Dictionary:
	match region:
		"Denver Ruins", "The Airport":
			return {"bg": Color("#1c1410"), "back": Color("#241a12"), "ground": Color("#33241a"), "accent": Color("#c9782a"), "panel": Color("#160f0a"), "panel_line": Color("#4a3a24"), "text": Color("#e6dcc0")}
		"The Woods":
			return {"bg": Color("#101a10"), "back": Color("#16241a"), "ground": Color("#1c2c1c"), "accent": Color("#5fae6a"), "panel": Color("#0c130c"), "panel_line": Color("#2a4030"), "text": Color("#dfe6d4")}
		"The Platte":
			return {"bg": Color("#0e1a18"), "back": Color("#12241f"), "ground": Color("#15302a"), "accent": Color("#52c0a5"), "panel": Color("#0a1412"), "panel_line": Color("#27463c"), "text": Color("#dce8e2")}
		"The High Country", "The Peaks", "The High Country Pass":
			return {"bg": Color("#10141c"), "back": Color("#161c28"), "ground": Color("#1d2433"), "accent": Color("#6aa4c8"), "panel": Color("#0b0e14"), "panel_line": Color("#2a3648"), "text": Color("#dce2ea")}
		_:
			return {"bg": Color("#1c1410"), "back": Color("#241a12"), "ground": Color("#33241a"), "accent": Color("#c9782a"), "panel": Color("#160f0a"), "panel_line": Color("#4a3a24"), "text": Color("#e6dcc0")}

static func type_mult(weapon_type: String, enemy: Dictionary) -> float:
	if weapon_type == enemy.get("weak", ""):
		return 1.5
	if weapon_type == enemy.get("resist", ""):
		return 0.5
	return 1.0
