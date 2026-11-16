# Como adicionar conteúdo

Depois de qualquer alteração: `./run_tests.sh` (valida referências, contagens e chaves de localização).

## Habilidade ativa

1. Em `data/abilities.json → actives`, adicione um objeto com `id`, `behavior`, `tags`, `name`, `desc`, `icon` e **5** entradas em `levels`.
2. Se reutilizar um comportamento existente (`orbit, chain, drone, beam, lob, zone_slow, split, nova, trail_mine, lance, swarm, vortex`), pronto.
3. Para um comportamento novo: crie `src/abilities/behaviors/<nome>_ability.gd` estendendo `AbilityRuntime` (implemente `tick(delta)` e, se tiver visual, `draw_visual()`), e registre-o em `src/abilities/ability_factory.gd`.
4. Cada chave nova de `levels` precisa de `param.<chave>` em `locale/*.json` (usado no "próximo efeito").
5. Opcional: evolução em `evolutions` com `from`, `requires` (id de módulo) e `params` fixos.

Use `battle.damage_enemy`, `battle.area_damage`, `battle.enemies.query/nearest`, `battle.projectiles.fire/lob`, `battle.fx.*`. Estatísticas: `stat("area")`, `interval(base)`, `extra_count()`.

## Inimigo

1. Em `data/enemies.json → enemies`, defina atributos, `behavior` (`chaser, flyer, ranged, splitter, buffer, charger, shaper`), `threat`, `params` e `visual{shape,color,accent,variants}`.
2. Inclua o id em `waves[].pool` ou `events[]` de algum mapa.
3. Comportamento novo: adicione ao enum `Enemy.Behavior`, ao `BEHAVIOR_MAP` e um ramo em `EnemySystem.update` (sempre com *telegraph* para ataques perigosos).
4. Elite: use a seção `elites` com `elite_skill` (`slam, brood, ring_volley, triple_dash`). Chefe: seção `bosses` com 3 fases e ataques implementados em `BossController`.

## Agente

1. `data/agents.json → agents`: `visual` (silhueta procedural: `shape` = hood|slim|visor|bulky|pack|cloak; `gear`), `start_ability`, `base_mods`, `per_level_mods`, `trait`, `unlock`, `milestones` (3).
2. Traço novo: implemente os ganchos em `src/actors/agent_traits.gd` (`update`, `on_player_damaged`, `on_crit`, `damage_mult`, `regen_mult`).
3. Novo agente é adicionado automaticamente ao save (merge de padrões) e ganha moeda `shard_<id>`.

## Missão / mapa

1. `data/maps.json → maps`: `sector` (ordem de desbloqueio), `palette`, `size`, `duration`, `boss`, `boss_time`, `layout` (seed e estilo dos obstáculos), `hazards`, `waves`, `min_alive`, `events`, `scaling`, `rewards`, `objectives` (3).
2. Modos ficam em `modes[]` com `rules` (`duration`, `no_boss`, `budget_mult`, `elite_interval`, `device_hp`, `victory_on_timer`…).

## Item

1. `data/equipment.json → items`: `slot`, `main{stat,op,base,per_level}`, `secondary[]`, `rarity_effects[]{rarity, stat, op, value, desc}`, `origin`, `icon`.
2. Formas de ícone novas: adicione um caso em `IconPainter.draw` (o padrão desenha um hexágono).
