# Plano e auditoria

## Auditoria do repositório (início)

- Repositório vazio (nenhum commit, nenhum arquivo). Nenhuma engine, script, README ou configuração pré-existente.
- Decisão: **Godot 4.x + GDScript**, conforme instrução para repositório vazio. Versão alvo 4.3-stable (validada no ambiente de CI via binário headless).
- Problemas encontrados: nenhum código a preservar; nenhuma dependência paga; ambiente sem GPU — validação feita em modo headless e capturas via Xvfb (renderizador OpenGL por software).

## Arquitetura proposta

Serviços desacoplados como *autoloads* pequenos (um por responsabilidade), comunicação por sinais no `EventBus`, conteúdo 100% em `data/*.json` validado na inicialização, combate orientado a dados com *pooling* e grade espacial. Detalhes em [ARCHITECTURE.md](ARCHITECTURE.md).

## Fases

| Fase | Escopo | Estado |
|---|---|---|
| 1 | Auditoria, arquitetura, Boot, navegação, dados, save inicial | Concluída |
| 2 | Arena, jogador, câmera, inimigos, SpawnDirector, dano, XP, level up, habilidades | Concluída |
| 3 | Pooling, 12 ativas, 12 passivas, 8 evoluções, elites, 4 chefes, resultado | Concluída |
| 4 | Lobby, missões, agentes, inventário, equipamento, oficina | Concluída |
| 5 | Economia, loja simulada, objetivos, conquistas, pesquisa, offline | Concluída |
| 6 | Conteúdo, tutorial, localização, acessibilidade, áudio, polimento | Concluída (placeholders) |
| 7 | Testes, otimização, preset Android, documentação | Concluída; exportação real depende de SDK local |

## Árvore de diretórios

Ver README.md → *Estrutura*.
