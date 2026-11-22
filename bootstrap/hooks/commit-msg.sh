# shellcheck shell=sh
# Corpo do hook commit-msg (ADR 0043). O bootstrap grava, antes deste texto, o shebang, o marcador
# "boleto-hook: commit-msg" e as variáveis BOLETO_DOCS_DIR (checkout do boleto-docs) e BOLETO_NODE
# (Node do mise). Este arquivo é POSIX sh: no Windows quem o executa é o sh do Git for Windows.
# Não use bashismos aqui.

node_bin=""
if [ -n "${BOLETO_NODE:-}" ] && [ -x "$BOLETO_NODE" ]; then
  node_bin="$BOLETO_NODE"
elif command -v node >/dev/null 2>&1; then
  node_bin="$(command -v node)"
fi
cli="$BOLETO_DOCS_DIR/node_modules/@commitlint/cli/cli.js"
config="$BOLETO_DOCS_DIR/commitlint.config.mjs"

missing=""
[ -n "$node_bin" ] || missing="$missing Node;"
[ -f "$cli" ] || missing="$missing commitlint (node_modules do boleto-docs);"
[ -f "$config" ] || missing="$missing commitlint.config.mjs do boleto-docs;"
if [ -n "$missing" ]; then
  echo "commit-msg: não consegui verificar a mensagem, falta:$missing" >&2
  echo "commit-msg: rode 'bootstrap/bootstrap.sh install' (Linux/macOS) ou 'bootstrap/bootstrap.ps1 install' (Windows)" >&2
  echo "commit-msg: no checkout do boleto-docs e tente o commit de novo." >&2
  exit 1
fi

if ! "$node_bin" "$cli" --config "$config" --edit "$1"; then
  echo "" >&2
  echo "commit-msg: mensagem recusada. Use Conventional Commits (tipo(escopo): descrição)" >&2
  echo "commit-msg: com título e linhas do corpo de até 100 caracteres, e refaça o commit." >&2
  exit 1
fi
