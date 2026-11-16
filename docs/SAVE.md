# Sistema de save

- Local: `user://save/` (no Android, armazenamento interno do app).
- Arquivos: `main.sav` + `backup_1..3.sav` (rotação) + `main.tmp` (temporário).
- Envelope: `{"format":1, "checksum": sha256(payload), "payload": "<json>"}`.

## Gravação atômica

1. Serializa e grava `main.tmp`; força flush.
2. Relê e valida o temporário (checksum).
3. Rotaciona: remove `backup_3`, `backup_2→3`, `backup_1→2`, `main→backup_1`.
4. Renomeia `main.tmp → main.sav`.

Uma interrupção em qualquer ponto deixa pelo menos uma cópia válida.

## Carregamento e recuperação

Tenta `main`, depois `backup_1..3`; o primeiro que decodifica vence. Arquivos inválidos são listados no relatório e o jogador recebe um aviso. Se nenhum for válido, cria um perfil novo.

## Versões e migração

`SaveDefaults.VERSION = 3`. `SaveMigrations.migrate` aplica passos sequenciais (`v1→v2→v3`), preenche campos ausentes com os padrões (`JsonUtil.merge_defaults`) e normaliza tipos (JSON transforma inteiros em float), descarta itens cujo conteúdo foi removido, corrige saldos negativos, equipados inexistentes e agente inválido.

## Quando salva

- Imediatamente após transações importantes (compra, melhoria, fusão, reciclagem, pesquisa, desbloqueio, fim de missão, resgates).
- Com *debounce* de 1,5 s para mudanças frequentes; autosave a cada 45 s se houver alterações.
- Ao fechar, pausar o app (Android) ou voltar.

## Conteúdo salvo

Perfil/conta, moedas e fragmentos, inventário, equipados, agentes, progresso de missões e estrelas, objetivos, conquistas e contadores vitalícios, pesquisa, tutorial, compras por período e garantia das cápsulas, chaves de recompensas únicas, histórico da oficina, log de transações, configurações, recordes, códice, correio, timestamps (offline) e versão.

## Apagar progresso

Configurações → *Apagar progresso* exige digitar **APAGAR**. Remove todos os arquivos e backups.

## Segurança

Não há segredos no cliente. O checksum detecta corrupção, **não** impede edição. Um lançamento comercial com compras/competição precisa de backend para validar compras, economia, recompensas e relógio (a recompensa offline já isola o cálculo em `OfflineRewardCalculator`, pronto para ser substituído por uma resposta do servidor).
