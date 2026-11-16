# Formato dos dados (`data/`)

Todos os arquivos são JSON. Textos de conteúdo usam dicionário inline `{"pt_BR": "...", "en": "..."}` (o `en` é opcional; o fallback é pt_BR). Cores em `#rrggbb`. Ícones: `{"shape": "<forma>", "color": "#..."}` — as formas são desenhadas por `src/ui/icon_painter.gd`.

`ContentDatabase` valida na inicialização: ids duplicados, referências (habilidade inicial, evoluções, inimigos dos mapas, chefes, espaços, atributos), 5 níveis por habilidade/módulo e ciclos na árvore de pesquisa. Erros aparecem no console e o teste `test_content_validates` falha.

| Arquivo | Conteúdo |
|---|---|
| `stats.json` | `stats[]`: `id`, `base`, `min`, `max`, `fmt` (`int`, `dec`, `pct`, `mult`) |
| `balance.json` | `run` (curva de XP, limites de espaços, invulnerabilidade, drops, câmera…), `limits.<perfil>` (máx. inimigos/projéteis/FX/números), `damage_numbers`, `enemy_scaling`, `difficulty` |
| `agents.json` | `level_costs`, `agents[]`: `visual`, `start_ability`, `base_mods[]`, `per_level_mods[]`, `trait{id,params}`, `unlock{type: default|shards|account_level|mission}`, `max_level`, `milestones[]{level, mods?, trait_params?}` |
| `abilities.json` | `actives[]{behavior, tags, levels[5]}`, `passives[]{stat, op, values[5], extra?}`, `evolutions[]{from, requires, behavior, params}`, `fallbacks[]` |
| `enemies.json` | `enemies[]` (comuns; `spawn_only` para derivados), `elites[]{elite_skill, params}`, `bosses[]{phases[3]{threshold, rest, sequence, random, speed_mult}, attacks{...}, rewards}`, `drops.xp_tiers` |
| `maps.json` | `maps[]{palette, size, duration, boss, boss_time, layout, hazards[], waves[], min_alive[], events[], scaling, rewards, objectives[3]}`, `modes[]{cost, unlock, rules}`, `daily_modifiers[]` |
| `equipment.json` | `slots`, `rarities[]{max_level, stat_mult, cost_mult, recycle_scrap}`, `upgrade`, `fusion`, `items[]{slot, main{stat,op,base,per_level}, secondary[], rarity_effects[]}`, `starter_items` |
| `research.json` | `cost_growth`, `branches[]`, `nodes[]{branch, tier, col, max_rank, cost, effect{type: stat|meta}, requires[]}` |
| `objectives.json` | `tutorial[]`, `daily[]`, `weekly[]`: `{id, event, target, reward, mode: sum|max, filter?}`; `daily_active`, `weekly_active` |
| `achievements.json` | `achievements[]` com o mesmo formato + `name` |
| `store.json` | `tabs`, `offers[]{tab, cost, alt_cost?, gives, period: none|daily|weekly, limit, requires?, kind?: crate}`, `daily_rotation{slots, pool}`, `shard_offers_per_agent`, `crates{odds, pity_threshold, pity_min_rarity}` |
| `economy.json` | moedas, carteira inicial, XP de conta, recompensas de missão, offline, custos de reanimação, valores de desenvolvimento |
| `tutorial.json` | `steps[]{id, context, complete_on, skippable, text}` |

## Modificador

```json
{"stat": "damage", "op": "pct", "value": 0.1}
```

`op`: `flat` (soma absoluta), `pct` (percentual aditivo), `mult` (fator multiplicativo).

## Eventos (para objetivos/conquistas)

`EnemyDefeated, EliteDefeated, BossDefeated, DamageDealt, DamageTaken, AbilitySelected, EvolutionFormed, EquipmentUpgraded, EquipmentFused, EquipmentRecycled, ItemEquipped, MissionStarted, MissionCompleted, MissionFailed, CurrencySpent{currency}, CurrencyEarned{currency}, AgentUnlocked, AgentLeveled, ResearchPurchased, StorePurchase, CrateOpened, RunLevelReached, SurviveSeconds, ObjectiveClaimed, AccountLevel, PickupCollected, ScreenVisited{screen}, TutorialStep, StarsEarned, LoginDay` (ver `src/core/game_events.gd`).
