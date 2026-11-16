# Núcleo Zero

Jogo original de sobrevivência contra hordas (*horde survival / action roguelite*) para **Android (retrato 9:16)** e desktop, feito em **Godot 4.3 + GDScript**.

> Uma megacidade costeira foi atingida por uma tempestade eletromagnética chamada **O Pulso**. Máquinas autônomas, criaturas cristalinas e resíduos energéticos ocupam os distritos abandonados. Os agentes da **Farol Nove** recuperam tecnologia e protegem os últimos assentamentos.

Todo o conteúdo (nomes, personagens, inimigos, interface, regras, números, ícones, sons e músicas) é original. Arte e áudio são *placeholders* gerados em código — não há arquivos de terceiros.

## Estado atual

Vertical slice jogável: Boot → Lobby → seleção de agente/equipamento/missão → batalha completa de 10 min com hordas, níveis, 12 habilidades, 12 módulos, 8 evoluções, elites e chefe → resultado → recompensas → melhoria de equipamento → progresso persistido. Detalhes em [`docs/PROGRESS.md`](docs/PROGRESS.md).

| Conteúdo | Quantidade |
|---|---|
| Agentes | 6 (traço exclusivo, 20 níveis, 3 marcos) |
| Habilidades ativas / módulos / evoluções | 12 / 12 / 8 |
| Equipamentos | 24 em 6 espaços, 6 raridades |
| Inimigos | 8 comuns (+1 derivado), 4 elites, 4 chefes com 3 fases |
| Mapas / modos | 5 / 5 (Expedição, Ruptura, Caçada, Defesa, Simulação Diária) |
| Objetivos | 20 tutorial, 30 diários, 20 semanais, 40 conquistas |
| Pesquisa | 30 nós em 3 ramos |

## Requisitos

- [Godot 4.3](https://godotengine.org/download) (versão *standard*, não .NET). Testado com 4.3-stable.
- Para Android: export templates 4.3, Android SDK/JDK 17 (ver [`docs/ANDROID.md`](docs/ANDROID.md)).
- Nenhum serviço pago, chave ou backend.

## Como executar

```bash
godot --path .            # abre o jogo (cena principal: scenes/boot/boot.tscn)
godot -e --path .         # abre no editor
```

Na primeira abertura via linha de comando rode `godot --headless --path . --import` para gerar o cache de classes.

**Controles** — Toque: arraste em qualquer ponto da metade inferior (joystick flutuante de um polegar). Desktop: WASD/setas, clique-e-arraste com o mouse, controle (analógico esquerdo, Start pausa). `Esc`/`P` pausa, `F1` menu de desenvolvimento (somente builds de debug), `F3` métricas.

## Como testar

```bash
GODOT=/caminho/para/godot ./run_tests.sh
```

Executa: compilação de todos os scripts, **78 testes** unitários/integração (fórmulas, crítico, redução de dano, evoluções, ofertas aleatórias, garantia da cápsula, transações, saldo insuficiente, fusão, reciclagem, save/load, migração, recuperação de corrupção, missão concluída, recompensa única, recompensa offline, agentes, dependências da pesquisa, todos os chefes, todos os mapas, modo Defesa) e uma fumaça de navegação por todas as telas.

Simulação de uma missão inteira (bot automático):

```bash
godot --headless --path . res://tests/scenes/battle_simulation.tscn -- submerged_avenue expedition 800 1
```

Laboratórios isolados (habilidades, inimigos, cada chefe, desempenho, equipamentos, loja, save, recompensas): menu de desenvolvimento (`F1`) → *Laboratório de testes*. Usam um save separado.

## Documentação

| Documento | Conteúdo |
|---|---|
| [docs/PLAN.md](docs/PLAN.md) | Auditoria inicial, plano por fases, árvore de diretórios |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Serviços, fluxo de dados, ordem de atualização da batalha |
| [docs/FORMULAS.md](docs/FORMULAS.md) | Estatísticas, modificadores, dano, XP, economia |
| [docs/DATA_FORMAT.md](docs/DATA_FORMAT.md) | Formato de cada arquivo em `data/` |
| [docs/HOWTO.md](docs/HOWTO.md) | Como adicionar habilidade, inimigo, agente, missão e item |
| [docs/SAVE.md](docs/SAVE.md) | Sistema de save, backups, migração |
| [docs/ANDROID.md](docs/ANDROID.md) | Exportação Android |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Técnicas e medições |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Decisões técnicas e de design |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Status por fase e limitações atuais |
| [docs/BACKLOG.md](docs/BACKLOG.md) | Próximos passos sugeridos |
| [docs/ATTRIBUTIONS.md](docs/ATTRIBUTIONS.md) | Atribuições e licenças |

## Estrutura

```
project.godot          configuração, autoloads
data/                  todo o conteúdo e balanceamento (JSON editável)
locale/                textos de interface pt_BR / en
scenes/                cenas (boot, ui/*, battle)
src/
  core/                GameState, SceneRouter, Settings, ContentDatabase, RandomService, EventBus, tempo
  save/                SaveManager, SaveStore (atômico + backups), codec, migrações
  economy/             Wallet, EconomyManager, RewardManager, StoreService, cápsulas, offline
  equipment/           ItemRules, InventoryManager
  progression/         agentes, pesquisa, objetivos, conquistas, tutorial
  missions/            MissionManager (mapas, modos, RunConfig, estrelas)
  combat/              Battle, StatBlock, dano, grade espacial, pools, projéteis, FX, HUD, painéis
  actors/              Player, traços dos agentes, joystick, desenho dos agentes
  enemies/             Enemy, EnemySystem (máquinas de estado), SpawnDirector, BossController
  abilities/           12 comportamentos, Loadout, ofertas de nível
  ui/                  tema, kit, telas, widgets
  audio/               AudioManager + síntese procedural
  localization/        LocalizationManager
  analytics_local/     registro local de eventos (nada sai do aparelho)
  debug/               menu de desenvolvimento e laboratórios de batalha
tests/                 testes, simulação de batalha, fumaça de UI, laboratórios
tools/                 verificação de scripts, capturas de tela
assets/placeholders/   (vazio de propósito: placeholders são procedurais)
```

## Aviso sobre economia

O protótipo **não usa dinheiro real**, não tem checkout e todas as compras usam moedas fictícias. Saves locais podem ser editados por qualquer pessoa; um lançamento comercial com compras ou competição exigiria backend para validar transações, recompensas e relógio.
