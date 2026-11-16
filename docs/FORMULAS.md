# Fórmulas

## Estatísticas (StatBlock)

Definições, base e limites em `data/stats.json`. Ordem de aplicação:

```
final = clamp( (base + Σflat) × max(0.1, 1 + Σpct) × Π max(0.1, 1 + mult_i) , min, max )
```

- `flat` soma valores absolutos; `pct` soma percentuais (aditivos entre si); `mult` multiplica (cada um é um fator independente, ex.: Sobremarcha +8% final).
- Proteções: soma de `pct` nunca reduz abaixo de ×0,1; cada `mult` nunca abaixo de ×0,1; `NaN`/`inf` são ignorados; `min`/`max` do stats.json impedem valores negativos e crescimento infinito (ex.: recarga mínima ×0,25, chance crítica ≤ 100%, esquiva ≤ 60%, redução de dano ≤ 75%).
- Fontes de modificadores numa partida: agente (base + por nível + marcos), equipamentos equipados, pesquisa, modificadores do modo diário e módulos passivos (removidos/recolocados por fonte a cada nível).

## Dano causado

```
dano = base_da_habilidade × stat.damage × bônus_de_traço × (crítico ? stat.crit_mult : 1) × (1 − resistência)
crítico se roll < clamp(stat.crit_chance, 0, 1);  crit_mult ≥ 1;  resistência ≤ 0,9
```

Resistência do inimigo = `resist` + bônus do Pastor Magnético. Dano contínuo (bruma, vórtice, dot) não critica.
Recuo: `direção × força × stat.knockback / massa` (chefes recebem 15%).

## Dano recebido

```
esquiva: roll < clamp(stat.dodge, 0, 0.6) → 0 de dano
após armadura = bruto × 100 / (100 + armadura)
final = max(após armadura × (1 − clamp(redução, 0, 0.75)), dano_mínimo)
```

Invulnerabilidade de `run.invuln_seconds` (+ pesquisa) após cada golpe. Dano de área contínua (escuridão, lodo) ignora a invulnerabilidade mas é proporcional ao tempo.

## Recarga

```
intervalo = max(0,05 s, base × stat.cooldown / stat.attack_speed)
```

## Escala de inimigos

```
vida = base × (1 + minutos × hp_per_minute) × mult_mapa × mult_modo × mult_dificuldade × (campeão ? 4 : 1)
dano = base × (1 + minutos × damage_per_minute) × mult_mapa × mult_dificuldade
velocidade = base × (1 + minutos × speed_per_minute) × mult_diário
chance de campeão = champion_chance_per_minute × minutos
```

Chefes: vida × (1 + 0,05 × minutos) × multiplicadores do mapa.

## Experiência

```
xp_necessária(n) = base + linear × n + power_mult × n^power      (balance.run.xp_curve)
xp_ganha = valor_do_fragmento × stat.xp_gain
```

Fragmentos acima de `max_xp_pickups` se fundem em fragmentos existentes (valor preservado).

## Orçamento de ameaça (SpawnDirector)

```
orçamento += onda.budget × cfg.budget_mult × Δt × (chefe vivo ? 0,5 : 1)     (teto 40)
enquanto orçamento > 0: escolhe inimigo ponderado; custo = threat
se vivos < min_alive(t): gasta mesmo sem orçamento
```

## Economia

- Melhoria de item: `sucata = round(scrap_base × (1 + nível)^scrap_power × cost_mult_raridade)`; a cada `data_every` níveis também custa Dados de Campo.
- Redefinição devolve `reset_refund` (80%) da sucata investida; reciclagem: `recycle_scrap(raridade) + 80% do investido`.
- Fusão: 3 iguais (mesmo item e raridade) → raridade seguinte, nível = maior dos três (limitado ao máximo da nova raridade); investimento dos consumidos é devolvido.
- Agente: `sucata = scrap_base × scrap_growth^(nível−1)`, `fragmentos = shards_base + shards_step × (nível−1)`.
- Pesquisa: `custo_rank = custo_base × cost_growth^rank_atual`.
- Conta: `xp_nível(n) = base × growth^(n−1)`.
- Recompensa de missão: por minuto + por abate + por elite + nível; vitória soma `clear` e bônus do modo; derrota soma `clear × fail_ratio × progresso`. Sucata × `reward_mult` do modo × dificuldade × (1 + pesquisa).
- Offline: `sucata = minutos × scrap_per_minute_per_sector × setor × (1 + taxa)`; limitado a `cap_hours` (+ pesquisa).
