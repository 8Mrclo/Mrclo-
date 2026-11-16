# Decisões

| # | Decisão | Motivo |
|---|---|---|
| 1 | Godot 4.3 + GDScript, renderizador GL Compatibility | Repositório vazio (regra do pedido); Compatibility tem o maior alcance em Android intermediário. |
| 2 | UI construída em código + cenas mínimas | Evita `.tscn` grandes e frágeis, mantém estilos centralizados (`ThemeFactory`/`UIKit`) e facilita revisão por diff. Cada tela pedida existe como cena navegável. |
| 3 | Conteúdo em JSON validado (não Resources `.tres`) | Editável sem o editor, diffs legíveis, validação centralizada e testável. Textos de conteúdo inline com pt_BR/en. |
| 4 | Sem motor de física no combate | Centenas de corpos físicos são caros em mobile; colisão analítica (círculos/retângulos) + grade espacial é previsível e barata. |
| 5 | Inimigos como nós Node2D com estado + laço central | Desenho em cache pelo motor, lógica num só laço tipado; pooling simples. |
| 6 | Arte e áudio procedurais | Identidade própria, zero risco de licença; tudo é placeholder claramente identificado e substituível. |
| 7 | Evoluções aparecem como cartão garantido no próximo nível | Regra própria (sem baús de chefe); exige ativa nv.5 + módulo específico. Requisito exibido no cartão. |
| 8 | Elites deixam *Caixa de Dados* (uma escolha extra) | Recompensa clara para enfrentar elites sem depender de baús. |
| 9 | Vitória da Expedição ao derrotar o chefe (surge em 9:00) | Mantém a missão em ~10 min; se o tempo passa, o chefe fica enfurecido (×1,5) para evitar partidas infinitas. Ruptura/Defesa vencem pelo tempo. |
| 10 | Defesa: inimigos que alcançam o repetidor se descarregam nele e somem | Regra legível ("intercepte antes que cheguem") e sem drenagem contínua injusta. |
| 11 | Ataques de chefe com regras anti-inevitáveis | *Telegraph* ≥ 0,5 s, anéis sempre com abertura, varreduras com arco limitado e marcado, escuridão sempre com zona segura alcançável, descanso entre ataques. |
| 12 | Eventos de combate agregados e emitidos ao fim da partida | Evita milhares de sinais e gravações por minuto; elites/chefes/escolhas/evoluções continuam imediatos. |
| 13 | Recompensas únicas por chave persistida (`claimed_keys`) | Idempotência simples contra duplicação (primeira conclusão, estrelas, conquistas, objetivos por período, correio). |
| 14 | Offline: âncora que só avança | Voltar o relógio gera anomalia e reancora no maior tempo já visto; impossível recuperar a mesma janela manipulando o relógio. |
| 15 | Cápsulas com probabilidades visíveis, garantia e alternativa por progressão | Moeda fictícia apenas; chaves de cápsula obtidas jogando. Resultados registrados localmente. |
| 16 | Labs e testes usam saves separados (`user://lab_save`, `user://test_saves`) | Nunca tocar no progresso real ao testar. |
| 17 | Tema compartilhado aplicado explicitamente em CanvasLayers | Controles sob CanvasLayer não herdam o tema da raiz no Godot 4. |
| 18 | Licença do projeto não definida | Cabe ao dono do repositório escolher; nada de terceiros foi incluído. |
