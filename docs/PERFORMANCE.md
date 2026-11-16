# Desempenho

## Técnicas

- **Object pooling** para inimigos, projéteis (aliados e hostis), FX (com pool separado e nunca esgotado para *telegraphs*), coletáveis. Nós inativos ficam ocultos na árvore (sem add/remove por quadro).
- **Laço central**: inimigos/projéteis não têm `_process`; `EnemySystem`/`ProjectileSystem` iteram arrays tipados.
- **Grade espacial** (`SpatialGrid`) reconstruída por *counting sort* em arrays compactos (`PackedInt32Array`), sem alocação após aquecimento. Todas as consultas de vizinhança usam a grade — não há busca global por inimigo por quadro.
- **Obstáculos** em grade estática própria (cada entidade testa só os obstáculos da sua célula).
- **LOD de IA**: inimigos além de `lod_near_radius` atualizam a cada `lod_far_interval` quadros com delta acumulado; separação é escalonada (metade por quadro, máx. 8 vizinhos).
- **Desenho em cache**: inimigos e projéteis chamam `queue_redraw` só ao mudar; *flash* de dano via `modulate`.
- **Números de dano agregados** por inimigo numa janela de 0,18 s, desenhados por um único nó, com limite por perfil.
- **Limites por perfil gráfico** (`balance.limits.low|medium|high`): inimigos, projéteis, FX, projéteis hostis, números, densidade de decoração.
- **XP com teto**: fragmentos além do limite fundem valor em fragmentos existentes.
- **HUD** atualiza textos a 10 Hz; ícones da build só quando a build muda.
- **Carregamento assíncrono** da batalha via `ResourceLoader.load_threaded_request` na tela de Loading.
- **Áudio** com 12 vozes, prioridade e *cooldown* por som.
- Painel de métricas (F3 ou Configurações): FPS, inimigos, projéteis, coletáveis, FX e memória.

## Medições (lógica, headless, desktop x86_64, Godot 4.3)

| Cenário | Entidades | Tempo médio de lógica/quadro | Pior quadro |
|---|---|---|---|
| Missão de 10 min (bot) | até ~230 inimigos | 0,5–1,6 ms | ~55 ms (picos isolados) |
| Laboratório de desempenho | 380 inimigos (teto do perfil médio) + projéteis | 3,8 ms | ~58 ms |

Os picos isolados ocorrem em momentos de criação de nós além do *prewarm* (primeira expansão dos pools) e na abertura de painéis. Medições de GPU/FPS reais em Android **ainda não foram feitas** (sem aparelho no ambiente); estimativa: aparelhos intermediários têm CPU 3–4× mais lenta que o desktop medido, o que mantém a lógica abaixo de ~15 ms no pior cenário do perfil médio. Recomenda-se o perfil *baixo* (260 inimigos) para aparelhos fracos e a opção de 30 FPS.

Como medir:

```bash
godot --headless --path . res://tests/scenes/battle_simulation.tscn -- lab:perf x 60 1
```
