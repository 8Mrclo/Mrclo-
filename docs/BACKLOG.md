# Backlog sugerido

## Alta prioridade
- Testes com jogadores e rebalanceamento (curva de XP, vida dos chefes, densidade dos mapas 2–5).
- Exportar e medir em 2–3 aparelhos Android intermediários; ajustar perfis gráficos.
- Arte final: sprites/atlases para agentes, inimigos e chefes; animações de ataque e morte.
- Trilha e efeitos sonoros finais (substituir `SoundSynth`).

## Média
- Navegação completa de menus por controle (foco visual e atalhos).
- Tutorial com destaque visual do elemento alvo (setas/recorte).
- Mais modificadores diários e eventos de mapa (tempestade de íons, maré alta).
- Tradução completa dos textos de conteúdo para inglês.
- Gráficos de estatísticas por partida (dano por habilidade) na tela de resultado.
- Codex com estatísticas por inimigo (abates, primeiro encontro).

## Infra / lançamento
- Backend opcional para validar compras, recompensas e relógio (offline) — `OfflineRewardCalculator` e `Wallet` já isolam as regras.
- CI (GitHub Actions) rodando `run_tests.sh` com Godot headless.
- Telemetria opt-in (hoje é apenas local).
- Definir a licença do projeto.
