#!/usr/bin/env bash
# Runs the full automated suite: script compilation, unit/integration tests
# and the UI navigation smoke test. Usage: GODOT=/path/to/godot ./run_tests.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")"
echo "== Importando projeto (gera cache de classes)"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
echo "== Compilando scripts"
"$GODOT" --headless --path . res://tools/check_scripts.tscn
echo "== Testes unitários e de integração"
"$GODOT" --headless --path . res://tests/test_runner.tscn
echo "== Fumaça de navegação da UI"
"$GODOT" --headless --path . res://tests/scenes/ui_smoke.tscn | grep -q UI_SMOKE_OK && echo "UI OK"
echo "Tudo certo."
