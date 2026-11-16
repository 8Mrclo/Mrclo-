# Progresso

## Definição de pronto do vertical slice

| Critério | Estado | Como foi verificado |
|---|---|---|
| Projeto abre sem erros | ✅ | `tools/check_scripts.tscn` (126 scripts, 78 testes), boot headless |
| Chega ao lobby | ✅ | fumaça de UI, capturas |
| Seleciona agente e equipamento | ✅ | telas Agentes/Arsenal; testes de inventário |
| Inicia missão | ✅ | fumaça (Loading → Battle) |
| Move por toque ou teclado | ✅ | joystick flutuante + `Input.get_vector`; simulação usa o joystick |
| Enfrenta hordas | ✅ | simulação: até 380 inimigos simultâneos |
| Sobe de nível e escolhe habilidades | ✅ | simulação e teste do painel |
| Forma ao menos uma evolução | ✅ | simulação com bot (2 evoluções) e laboratório |
| Enfrenta um chefe | ✅ | teste `test_every_boss_runs_all_phases` |
| Vence ou perde | ✅ | simulação: vitória aos 9:39; derrota com bot mortal |
| Recebe recompensas | ✅ | testes de recompensas + telas Resultado/Revelação |
| Melhora um equipamento | ✅ | testes + Oficina/Arsenal |
| Fecha e reabre mantendo progresso | ✅ | testes de save/load, migração e recuperação |
| Telas principais navegáveis | ✅ | fumaça visita todas as telas e abas |
| Sem erros recorrentes no console | ✅ | execuções headless sem `SCRIPT ERROR` |
| Desempenho documentado | ✅ | PERFORMANCE.md |

## Concluído por sistema

- Núcleo: serviços, roteador com fila e pilha de retorno, eventos, RNG com seed, tempo testável.
- Save: atômico, 3 backups, checksum, migração v1→v3, recuperação, autosave, apagar com confirmação digitada.
- Combate: 8 direções, mira configurável (4 modos), dano/crítico/perfuração/recuo/lentidão/dano contínuo/congelamento, invulnerabilidade, pausa, velocidade 1,5× desbloqueável, reanimação (pesquisa ou prismas), limites de entidades.
- Conteúdo: tudo listado no README.
- Meta: lobby, missões, agentes, arsenal, oficina (melhoria, redefinição, fusão manual/lote, reciclagem, pesquisa, histórico), loja (6 abas, rotação diária, limites, cronômetros, cápsulas com probabilidades e garantia), operações (tutorial/diárias/semanais), conquistas, códice, correio, recompensa offline, configurações completas, tutorial contextual e créditos.
- Ferramentas: menu dev, 8 laboratórios isolados, simulação de batalha, capturas de tela.

## Limitações atuais

- Arte e áudio são placeholders procedurais (formas e síntese); sem animações elaboradas.
- Mapas 2–5 têm duração de 7–8 min e tabelas mais curtas (estrutura completa, balanceamento menos refinado que o mapa 1).
- Balanceamento validado só por bot simples; requer testes com jogadores.
- Exportação Android configurada, não executada (sem SDK no ambiente); FPS em aparelho real não medido.
- Inglês completo na interface; nomes/descrições de conteúdo em inglês parciais (fallback pt_BR).
- Sem gamepad para navegação de menus além do foco padrão do Godot.

## Registro de verificação (última execução)

- `run_tests.sh`: 126 scripts compilados, 78 testes, 0 falhas; fumaça de UI ok.
- Simulação de 10 min (bot, invencível, Avenida Submersa): vitória aos ~9:40, 2 evoluções, chefe derrotado.
- Simulação mortal (bot simples, perfil novo): derrota entre 3 e 4 minutos — esperado para a 1ª tentativa sem melhorias permanentes; ajustar após testes com jogadores.
- Capturas renderizadas com `tools/screenshots.tscn` sob Xvfb (lobby, missões, agentes, arsenal, oficina/pesquisa, loja, operações, configurações, batalha, nível, chefe, resultado).
