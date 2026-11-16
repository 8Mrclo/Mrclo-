class_name Palette
extends RefCounted
## Original palette: tropical sci-fi (petrol blue, coral, amber, violet).
## High-contrast mode swaps backgrounds to near-black and text to white.

const PETROL_DEEP := Color("#071d24")
const PETROL := Color("#0b2a33")
const PETROL_MID := Color("#0f3b47")
const PETROL_LIGHT := Color("#1b5a66")
const TEAL := Color("#3fd0c9")
const MINT := Color("#7cf5d0")
const CORAL := Color("#ff6f61")
const AMBER := Color("#ffb547")
const VIOLET := Color("#8a5cff")
const SAND := Color("#f2efe6")
const MUTED := Color("#9db4b8")
const GREEN := Color("#5fd38d")
const DANGER := Color("#ff4f61")

const CURRENCY_COLORS := {
	"scrap": Color("#ffb547"), "prisms": Color("#c79bff"), "field_data": Color("#3fa7ff"),
	"op_seals": Color("#ff6f61"), "crate_key": Color("#ffd36e"),
}


static func high_contrast() -> bool:
	return bool(Settings.get_value("high_contrast"))


static func bg() -> Color:
	return Color("#000000") if high_contrast() else PETROL_DEEP


static func panel_bg() -> Color:
	return Color("#0a0a0a") if high_contrast() else Color(0.06, 0.2, 0.24, 0.96)


static func panel_alt() -> Color:
	return Color("#141414") if high_contrast() else Color(0.08, 0.26, 0.3, 0.96)


static func text() -> Color:
	return Color.WHITE if high_contrast() else SAND


static func text_muted() -> Color:
	return Color("#dddddd") if high_contrast() else MUTED


static func border() -> Color:
	return Color.WHITE if high_contrast() else PETROL_LIGHT


static func currency(c: String) -> Color:
	if c.begins_with("shard_"):
		var a: Dictionary = Content.agent(c.substr(6))
		return JsonUtil.color(JsonUtil.dig(a, "visual.body", ""), CORAL)
	return CURRENCY_COLORS.get(c, SAND)


static func rarity(id: String) -> Color:
	return JsonUtil.color(Content.rarity(id).get("color", ""), SAND)
