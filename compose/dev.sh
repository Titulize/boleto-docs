#!/usr/bin/env bash
# Atalhos do Compose de desenvolvimento (PostgreSQL, Valkey e Mailpit). Linux e macOS.
#
# Uso: compose/dev.sh <comando> [opções]
#
#   up              sobe os serviços e espera todos ficarem saudáveis
#   down            para e remove os containers (os dados continuam nos volumes)
#   reset           apaga containers e volumes (dados do PostgreSQL e do Valkey) e sobe de novo.
#                   Pede confirmação. Não apaga imagens nem o compose/.env
#   ps              mostra o estado dos serviços
#   logs [serviço]  mostra as últimas 100 linhas de log (de todos ou de um serviço)
#   help            mostra esta ajuda
#
# Opções:
#   -y, --yes       no reset, dispensa a confirmação
#
# Funciona de qualquer pasta. Na primeira execução cria compose/.env a partir do .env.example.
# As imagens vêm de .platform/versions.env (gerado a partir do versions.toml).
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$COMPOSE_DIR/.." && pwd)"
VERSIONS_ENV="$REPO_ROOT/.platform/versions.env"
ENV_FILE="$COMPOSE_DIR/.env"
ENV_EXAMPLE="$COMPOSE_DIR/.env.example"
PROJECT="boleto-dev"
WAIT_TIMEOUT=120

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_FAIL=$'\033[31m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_FAIL=""; C_OFF=""
fi
ok()   { printf '%s[ OK ]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
fail() { printf '%s[FAIL]%s %s\n' "$C_FAIL" "$C_OFF" "$*"; }
info() { printf '       %s\n' "$*"; }
die()  { printf '%s[ERRO]%s %s\n' "$C_FAIL" "$C_OFF" "$*" >&2; exit 2; }

usage() { awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; }

# --- argumentos ------------------------------------------------------------

CMD=""
SERVICE=""
YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    up|down|reset|ps|logs|help)
      [ -z "$CMD" ] || die "mais de um comando: $CMD e $1 (use help)"
      CMD="$1" ;;
    -y|--yes) YES=1 ;;
    -h|--help) CMD="help" ;;
    -*) die "opção desconhecida: $1 (use help)" ;;
    *)
      if [ "$CMD" != "logs" ] || [ -n "$SERVICE" ]; then die "argumento desconhecido: $1 (use help)"; fi
      SERVICE="$1" ;;
  esac
  shift
done
[ -n "$CMD" ] || CMD="help"

# --- variáveis ---------------------------------------------------------------

# Valor de uma variável: ambiente do shell > compose/.env > padrão (mesma precedência do Compose).
env_value() {
  local key="$1" default="$2" line
  if [ -n "${!key:-}" ]; then printf '%s' "${!key}"; return; fi
  if [ -f "$ENV_FILE" ]; then
    line="$(grep -E "^[[:space:]]*${key}=" "$ENV_FILE" | tail -n 1 | tr -d '\r' || true)"
    if [ -n "$line" ]; then printf '%s' "${line#*=}"; return; fi
  fi
  printf '%s' "$default"
}

dc() {
  docker compose --project-directory "$COMPOSE_DIR" -f "$COMPOSE_DIR/docker-compose.yml" \
    --env-file "$VERSIONS_ENV" --env-file "$ENV_FILE" "$@"
}

# --- pré-requisitos ----------------------------------------------------------

check_docker() {
  command -v docker >/dev/null 2>&1 || { fail "docker não encontrado no PATH"; exit 1; }
  docker compose version >/dev/null 2>&1 || { fail "docker compose não encontrado"; exit 1; }
  docker info >/dev/null 2>&1 || { fail "o daemon do Docker não responde. Abra o Docker Desktop ou inicie o serviço"; exit 1; }
  [ -f "$VERSIONS_ENV" ] || { fail "$VERSIONS_ENV não existe. Rode: npm run sync"; exit 1; }
}

ensure_env() {
  if [ ! -f "$ENV_FILE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    ok "compose/.env criado a partir do .env.example"
  fi
}

# --- comandos ----------------------------------------------------------------

cmd_up() {
  local out rc
  out="$(mktemp)"
  set +e
  dc up -d --wait --wait-timeout "$WAIT_TIMEOUT" 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  set -e
  if [ "$rc" -ne 0 ]; then
    if grep -qiE 'port is already allocated|address already in use|ports are not available' "$out"; then
      fail "porta ocupada no host. Mude a porta em $ENV_FILE"
      info "variáveis: POSTGRES_PORT, VALKEY_PORT, MAILPIT_SMTP_PORT, MAILPIT_UI_PORT"
    else
      fail "algum serviço não ficou saudável em ${WAIT_TIMEOUT}s"
      dc ps -a || true
      dc logs --tail 30 || true
    fi
    rm -f "$out"
    exit 1
  fi
  rm -f "$out"
  ok "serviços saudáveis"
  info "Mailpit (interface): http://localhost:$(env_value MAILPIT_UI_PORT 8025)"
  info "Mailpit (SMTP):      localhost:$(env_value MAILPIT_SMTP_PORT 1025)"
  info "PostgreSQL:          localhost:$(env_value POSTGRES_PORT 5432), banco $(env_value POSTGRES_DB boleto)"
  info "Valkey:              localhost:$(env_value VALKEY_PORT 6379) (com senha)"
}

cmd_reset() {
  local volumes answer
  volumes="$(docker volume ls -q --filter "label=com.docker.compose.project=$PROJECT")"
  if [ "$YES" -ne 1 ]; then
    warn "o reset apaga os containers e os volumes do projeto $PROJECT:"
    if [ -n "$volumes" ]; then
      printf '%s\n' "$volumes" | sed 's/^/         /'
    else
      info "(nenhum volume existe ainda)"
    fi
    if [ ! -t 0 ]; then
      die "terminal não interativo: confirme com --yes"
    fi
    printf 'Apagar os dados e recriar? [s/N] '
    read -r answer || answer=""
    case "$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" in
      s|sim|y|yes) ;;
      *) info "reset cancelado"; exit 0 ;;
    esac
  fi
  dc down --volumes --remove-orphans
  ok "containers e volumes removidos"
  cmd_up
}

case "$CMD" in
  help) usage; exit 0 ;;
esac

check_docker
ensure_env

case "$CMD" in
  up) cmd_up ;;
  down) dc down --remove-orphans; ok "serviços parados (os dados continuam nos volumes)" ;;
  reset) cmd_reset ;;
  ps) dc ps -a ;;
  logs)
    if [ -n "$SERVICE" ]; then dc logs --tail 100 "$SERVICE"; else dc logs --tail 100; fi ;;
esac
