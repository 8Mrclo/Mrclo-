# Exportação Android

1. Instale **Godot 4.3** e, em *Editor → Manage Export Templates*, baixe os templates 4.3.
2. Instale **JDK 17** e o **Android SDK** (platform-tools, build-tools 34, platform 34; NDK não é necessário para o template padrão).
3. *Editor → Editor Settings → Export → Android*: informe `Java SDK Path` e `Android SDK Path`. Um keystore de debug é gerado automaticamente pelo editor.
4. Abra *Project → Export*. O preset **Android** já existe em `export_presets.cfg`:
   - pacote `org.farolnove.nucleozero`, arm64-v8a, imersivo, orientação retrato (definida em `project.godot`), permissão de vibração, sem internet.
   - `include_filter` inclui `data/*.json` e `locale/*.json` (JSON não é recurso importado e precisa ser incluído explicitamente).
   - `exclude_filter` remove `tests/*` e `tools/*`.
5. Para release, configure seu keystore em *Release* (não versionar o arquivo nem senhas).
6. Exporte (`Export Project`) ou via CLI:
   ```bash
   godot --headless --path . --export-debug "Android" export/android/nucleo_zero.apk
   ```

Renderizador: *GL Compatibility* (amplo suporte em aparelhos intermediários). FPS alvo 60, opção de 30 em Configurações. Áreas seguras (notch) são respeitadas via `DisplayServer.get_display_safe_area()`.

> Neste ambiente de desenvolvimento não havia Android SDK; a exportação foi configurada mas não executada. Ver PROGRESS.md.
