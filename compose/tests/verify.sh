#!/usr/bin/env bash
# Verifica o Compose de desenvolvimento já em execução (não sobe nem derruba nada).
#
# Uso: compose/tests/verify.sh [--timeout SEGUNDOS]
#
# 1. Espera todos os serviços do compose ficarem healthy (padrão: 120 s). Falha se algum
#    serviço não tiver healthcheck.
# 2. Sondagens: select 1 no PostgreSQL, PONG no Valkey com senha e NOAUTH sem senha,
#    HTTP 200 na interface e na API do Mailpit, e conexão TCP em todas as portas publicadas.
#
# Sai com código 0 se tudo passou, 1 se algo falhou e 2 para uso incorreto.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(cd "$TESTS_DIR/.." && pwd)"
REPO_ROOT="$(cd "$COMPOSE_DIR/.." && pwd)"
ENV_FILE="$COMPOSE_DIR/.env"
[ -f "$ENV_FILE" ] || ENV_FILE="$COMPOSE_DIR/.env.example"
TIMEOUT=120
FAILS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout) shift; TIMEOUT="${1:-}"; [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || { echo "[ERRO] --timeout precisa de um número" >&2; exit 2; } ;;
    -h|--help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "[ERRO] argumento desconhecido: $1" >&2; exit 2 ;;
  esac
  shift
done

ok()   { printf '[ OK ] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; FAILS=$((FAILS + 1)); }

dc() {
  docker compose --project-directory "$COMPOSE_DIR" -f "$COMPOSE_DIR/docker-compose.yml" \
    --env-file "$REPO_ROOT/.platform/versions.env" --env-file "$ENV_FILE" "$@"
}

health_of() {
  local id
  id="$(dc ps -q "$1" 2>/dev/null || true)"
  if [ -z "$id" ]; then echo "parado"; return; fi
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}sem-healthcheck{{end}}' "$id"
}

# --- 1. saúde -------------------------------------------------------------------

# Sem mapfile: o Bash do macOS é o 3.2.
SERVICES=()
while IFS= read -r s; do [ -n "$s" ] && SERVICES+=("$s"); done < <(dc config --services)
[ "${#SERVICES[@]}" -gt 0 ] || { fail "nenhum serviço no compose"; exit 1; }

deadline=$((SECONDS + TIMEOUT))
while :; do
  pending=()
  for s in "${SERVICES[@]}"; do
    h="$(health_of "$s")"
    if [ "$h" = "sem-healthcheck" ]; then fail "$s não tem healthcheck"; exit 1; fi
    [ "$h" = "healthy" ] || pending+=("$s=$h")
  done
  [ "${#pending[@]}" -eq 0 ] && break
  if [ "$SECONDS" -ge "$deadline" ]; then
    fail "serviços não ficaram healthy em ${TIMEOUT}s: ${pending[*]}"
    exit 1
  fi
  sleep 2
done
ok "todos os serviços healthy: ${SERVICES[*]}"

# --- 2. sondagens -----------------------------------------------------------------

# As variáveis entre aspas simples são expandidas dentro do container, de propósito.
# shellcheck disable=SC2016
r="$(dc exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select 1"' 2>&1 || true)"
if [ "$(printf '%s' "$r" | tr -d '[:space:]')" = "1" ]; then ok "PostgreSQL responde a select 1"; else fail "PostgreSQL: $r"; fi

# shellcheck disable=SC2016
r="$(dc exec -T valkey sh -c 'valkey-cli -a "$VALKEY_PASSWORD" --no-auth-warning ping' 2>&1 || true)"
if [ "$(printf '%s' "$r" | tr -d '[:space:]')" = "PONG" ]; then ok "Valkey responde PONG com senha"; else fail "Valkey com senha: $r"; fi

r="$(dc exec -T valkey valkey-cli ping 2>&1 || true)"
if printf '%s' "$r" | grep -q NOAUTH; then ok "Valkey recusa comando sem senha (NOAUTH)"; else fail "Valkey sem senha deveria recusar: $r"; fi

# Endereço publicado no host, por exemplo 127.0.0.1:8025.
published() { dc port "$1" "$2" 2>/dev/null | head -n 1 | tr -d '\r'; }

ui="$(published mailpit 8025)"
for path in / /api/v1/info; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${ui##*:}$path" || true)"
  if [ "$code" = "200" ]; then ok "Mailpit http://localhost:${ui##*:}$path responde 200"; else fail "Mailpit $path: HTTP $code"; fi
done

for pair in "postgres 5432" "valkey 6379" "mailpit 1025" "mailpit 8025"; do
  read -r svc port <<<"$pair"
  addr="$(published "$svc" "$port")"
  host="${addr%:*}"; hport="${addr##*:}"
  if [ "$host" != "127.0.0.1" ]; then fail "$svc:$port publicado em '$addr' (esperado 127.0.0.1)"; continue; fi
  if (exec 3<>"/dev/tcp/127.0.0.1/$hport") 2>/dev/null; then
    ok "$svc:$port aceita conexão em $addr"
  else
    fail "$svc:$port não aceita conexão em $addr"
  fi
done

if [ "$FAILS" -gt 0 ]; then echo "$FAILS verificação(ões) falharam"; exit 1; fi
echo "Todas as verificações passaram."
