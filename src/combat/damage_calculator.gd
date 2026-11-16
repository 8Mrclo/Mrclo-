class_name DamageCalculator
extends RefCounted
## Damage formulas (see docs/FORMULAS.md).
## Outgoing: base × damage_stat × bonus × (crit ? crit_mult : 1) × (1 - resist)
## Incoming: dodge roll, then raw × 100 / (100 + armor) × (1 - damage_reduction), min floor.


static func outgoing(base: float, damage_stat: float, bonus_mult: float, crit_chance: float, crit_mult: float, resist: float, roll: float) -> Dictionary:
	var crit := roll < clampf(crit_chance, 0.0, 1.0)
	var dmg := maxf(base, 0.0) * maxf(damage_stat, 0.0) * maxf(bonus_mult, 0.0)
	if crit:
		dmg *= maxf(crit_mult, 1.0)
	dmg *= 1.0 - clampf(resist, 0.0, 0.9)
	return {"amount": dmg, "crit": crit}


static func incoming(raw: float, armor: float, damage_reduction: float, dodge: float, roll: float, min_damage: float = 1.0) -> Dictionary:
	if roll < clampf(dodge, 0.0, 0.6):
		return {"amount": 0.0, "dodged": true}
	var after_armor := maxf(raw, 0.0) * 100.0 / (100.0 + maxf(armor, 0.0))
	var final := after_armor * (1.0 - clampf(damage_reduction, 0.0, 0.75))
	return {"amount": maxf(final, min_damage) if raw > 0.0 else 0.0, "dodged": false}


## Effective interval for periodic abilities; never below 0.05s.
static func interval(base_interval: float, cooldown_stat: float, attack_speed: float) -> float:
	return maxf(0.05, base_interval * maxf(cooldown_stat, 0.05) / maxf(attack_speed, 0.05))
