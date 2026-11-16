# Arquitetura

## Autoloads (serviços)

Ordem de carregamento em `project.godot` (cada um tem uma responsabilidade):

| Autoload | Script | Papel |
|---|---|---|
| `EventBus` | core/combat_event_bus.gd | **CombatEventBus**: sinais globais e `emit_game(type, amount, data)` |
| `Rng` | core/random_service.gd | **RandomService**: streams nomeados (`run`, `loot`, `fx`, `meta`), seed de partida |
| `Loc` | localization/localization_manager.gd | **LocalizationManager**: `t(key)` para UI, `text(dict)` para conteúdo |
| `Content` | core/content_database.gd | **ContentDatabase**: carrega/indexa/valida `data/*.json` |
| `Game` | core/game_state.gd | **GameState**: dicionário persistido + estado de sessão (run pendente, último resultado) |
| `Saves` | save/save_manager.gd | **SaveManager**: autosave, debounce, gravação imediata |
| `Settings` | core/settings_manager.gd | **SettingsManager**: aplica volumes, FPS, idioma, gráficos |
| `Economy` | economy/economy_manager.gd | **EconomyManager**: única porta de alteração de saldo |
| `Inventory` | equipment/inventory_manager.gd | **InventoryManager**: itens, equipar, melhorar, fundir, reciclar |
| `Agents` | progression/agent_manager.gd | desbloqueio, níveis, marcos, modificadores |
| `Research` | progression/research_manager.gd | árvore permanente |
| `Missions` | missions/mission_manager.gd | **MissionManager**: mapas, modos, RunConfig, estrelas |
| `Objectives` | progression/objective_manager.gd | tutorial/diárias/semanais reativas |
| `Achievements` | progression/achievement_manager.gd | **AchievementManager** |
| `Rewards` | economy/reward_manager.gd | **RewardManager**: concessão idempotente, recompensas de missão e offline |
| `Store` | economy/store_service.gd | catálogo → regras → transação |
| `Tutorial` | progression/tutorial_manager.gd | dicas contextuais |
| `Analytics` | analytics_local/analytics_local.gd | log local |
| `Audio` | audio/audio_manager.gd | **AudioManager** |
| `Router` | core/scene_router.gd | **SceneRouter**: telas, pilha de retorno, transições, toasts |
| `DebugTools` | debug/debug_tools.gd | menu dev (apenas `OS.is_debug_build()`) |

`ObjectPoolManager` e `SpawnDirector` vivem dentro da cena de batalha (têm o ciclo de vida dela).

## Fluxo de dados

```
data/*.json ──► Content (somente leitura)
                     │
UI (telas) ──chama──► Managers ──mutam──► Game.data ──► Saves (atômico)
                     │
                     └─emit_game──► EventBus ──► Objectives / Achievements / Tutorial / Analytics
```

- Telas **não** alteram `Game.data` diretamente: usam os managers.
- Managers emitem `EventBus.notifications_changed`; telas se reconstroem (`ScreenBase.queue_rebuild`).
- Eventos de combate frequentes (abates, dano) são agregados na partida e emitidos ao final; elites/chefes/escolhas/evoluções são emitidos na hora.

## Batalha

`Battle` (scenes/battle/battle.tscn) constrói tudo em código:

```
Battle
├ ObjectPoolManager      pools: enemy, projectile, hostile, fx, fx_tele, pickup
├ Arena                  chão, obstáculos determinísticos, paredes temporárias
├ HazardSystem           perigos do mapa + zonas criadas por chefes
├ camadas (pickups, inimigos, habilidades, projéteis, efeitos)
├ DamageNumbers          números agregados num único nó
├ Player + CameraRig
├ BossController         (quando há chefe)
├ BattleHud / LevelUpPanel / PausePanel   (CanvasLayers)
```

Sistemas `RefCounted`: `EnemySystem`, `ProjectileSystem`, `FxSystem`, `PickupSystem`, `SpawnDirector`, `Loadout` (+ `AbilityRuntime` por habilidade), `AgentTraits`.

**Ordem por quadro**: input → jogador → diretor → inimigos (reconstrói a grade, IA, contato) → habilidades → projéteis → coletáveis → perigos → paredes → traços → chefe → FX → números → câmera → compactação (devolve mortos ao pool) → condições de fim → HUD (texto a 10 Hz) → abre painel de nível se houver escolhas pendentes.

Delta limitado a 50 ms e multiplicado pela velocidade (1× ou 1,5× desbloqueável).

## Telas

Cada tela é uma cena mínima (`scenes/ui/*.tscn`) com um script que estende `ScreenBase`, que fornece fundo animado, margens de área segura, cabeçalho, barra de moedas e navegação inferior. A UI é construída em código com `UIKit` e o tema é gerado por `ThemeFactory` (sem arquivos binários de tema).

## Padrões

- Nomes em inglês no código, textos via `Loc`.
- Tipagem estática onde possível; nenhum número de jogo no código (vêm de `data/`).
- Regras puras e testáveis em classes estáticas/`RefCounted`: `Wallet`, `DamageCalculator`, `StatBlock`, `UpgradeOffer`, `ItemRules`, `CrateRoller`, `OfflineRewardCalculator`, `ObjectiveTracker`, `SaveCodec`, `SaveMigrations`.
