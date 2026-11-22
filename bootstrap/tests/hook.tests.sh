#!/usr/bin/env bash
# Testes do hook commit-msg instalado pelo bootstrap (ADR 0043).
#
# Pressupõe que o `bootstrap.sh install` já rodou (com o mesmo BOLETO_DEV_HOME, se houver) e que
# existem, ao lado do boleto-docs, o boleto-backend (com um commit inicial) e o boleto-frontend
# (vazio). A CI cria os dois como repositórios de teste. Só altera esses dois repositórios.
#
#   BOLETO_DEV_HOME=/tmp/boleto-dev bash bootstrap/tests/hook.tests.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WS="$(cd "$ROOT/.." && pwd)"
BOOT="$ROOT/bootstrap/bootstrap.sh"
BACK="$WS/boleto-backend"
FRONT="$WS/boleto-frontend"
FAILS=0

pass() { printf '[ OK ] %s\n' "$1"; }
bad() { printf '[FAIL] %s\n' "$1"; FAILS=$((FAILS + 1)); }
check() { # check "nome" comando...
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else bad "$name"; fi
}
gc() { local d="$1"; shift; git -C "$d" -c user.name=ci -c user.email=ci@example.invalid -c commit.gpgsign=false "$@"; }
common_hook_of() { local d; d="$(git -C "$1" rev-parse --git-common-dir)"; case "$d" in /*) ;; *) d="$1/$d" ;; esac; printf '%s/hooks/commit-msg' "$d"; }
count_of() { git -C "$1" rev-list --count HEAD 2>/dev/null || echo 0; }
sha_of() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
install_out() { bash "$BOOT" install --editor none 2>&1; }

for d in "$BACK" "$FRONT"; do
  [ -d "$d/.git" ] || { echo "[FAIL] repositório de teste ausente: $d"; exit 1; }
done
git -C "$BACK" rev-parse --verify -q HEAD >/dev/null || { echo "[FAIL] o boleto-backend de teste precisa de um commit inicial"; exit 1; }

# 1. Hook com o marcador nos três repositórios, executável.
for r in "$ROOT" "$BACK" "$FRONT"; do
  h="$(common_hook_of "$r")"
  check "1. hook com marcador e executável em $(basename "$r")" bash -c "grep -q '^# boleto-hook: commit-msg' '$h' && [ -x '$h' ]"
done

# 2. Mensagem inválida no backend: recusada, sem commit novo.
before="$(count_of "$BACK")"
out="$(gc "$BACK" commit --allow-empty -m "mensagem invalida" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'type may not be empty' && [ "$(count_of "$BACK")" = "$before" ]; then
  pass "2. mensagem inválida recusada, com a saída do commitlint, sem commit novo"
else bad "2. mensagem inválida recusada (rc=$rc): $out"; fi

# 3. Linha de corpo de 101 colunas recusada, de 100 aceita.
l101="$(printf '%*s' 101 '' | tr ' ' a)"; l100="$(printf '%*s' 100 '' | tr ' ' a)"
out="$(gc "$BACK" commit --allow-empty -m "chore: corpo longo" -m "$l101" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'longer than 100'; then pass "3. linha de corpo com 101 colunas recusada"; else bad "3. corpo de 101 colunas deveria falhar (rc=$rc): $out"; fi
if gc "$BACK" commit --allow-empty -m "chore: corpo no limite" -m "$l100" >/dev/null 2>&1; then pass "3. linha de corpo com 100 colunas aceita"; else bad "3. corpo de 100 colunas deveria passar"; fi

# 4. Frontend vazio: inválida recusada, primeiro commit aceito.
if gc "$FRONT" commit --allow-empty -m "mensagem invalida" >/dev/null 2>&1; then bad "4. frontend vazio deveria recusar mensagem inválida"; else pass "4. frontend vazio recusa mensagem inválida"; fi
if gc "$FRONT" commit --allow-empty -m "feat: primeiro commit" >/dev/null 2>&1 && git -C "$FRONT" rev-parse --verify -q HEAD >/dev/null; then pass "4. frontend vazio aceita o primeiro commit válido"; else bad "4. primeiro commit válido do frontend deveria passar"; fi

# 5. Worktree do backend usa o mesmo hook.
wt="$BACK/.worktrees/hook-test"
git -C "$BACK" worktree add -q "$wt" -b chore/hook-test >/dev/null 2>&1
if [ -d "$wt" ]; then
  if gc "$wt" commit --allow-empty -m "mensagem invalida" >/dev/null 2>&1; then bad "5. worktree deveria recusar mensagem inválida"; else pass "5. worktree recusa mensagem inválida"; fi
  if [ "$(common_hook_of "$wt")" = "$(common_hook_of "$BACK")" ]; then pass "5. worktree compartilha o hook do repositório"; else bad "5. worktree com hook diferente"; fi
  git -C "$BACK" worktree remove --force "$wt" >/dev/null 2>&1
  git -C "$BACK" branch -D chore/hook-test >/dev/null 2>&1
else bad "5. não consegui criar o worktree de teste"; fi

# 6. Idempotência: segundo install mantém o hook e diz que já está ativo.
h="$(common_hook_of "$BACK")"
sum1="$(sha_of "$h")"
out="$(install_out)"
if [ "$(sha_of "$h")" = "$sum1" ] && printf '%s' "$out" | grep -q 'boleto-backend: hook já ativo'; then pass "6. install repetido mantém o hook (sha256 igual)"; else bad "6. install repetido alterou o hook ou não avisou"; fi

# 7. commit-msg alheio: install mantém e avisa; doctor avisa.
printf '#!/bin/sh\nexit 0\n' > "$h"
sum2="$(sha_of "$h")"
out="$(install_out)"
if [ "$(sha_of "$h")" = "$sum2" ] && printf '%s' "$out" | grep -q 'boleto-backend: commit-msg de outro autor'; then pass "7. install não sobrescreve commit-msg alheio e avisa"; else bad "7. install mexeu no commit-msg alheio"; fi
out="$(bash "$BOOT" doctor --editor none 2>&1)"
if printf '%s' "$out" | grep -q 'boleto-backend: commit-msg de outro autor'; then pass "7. doctor avisa do commit-msg alheio"; else bad "7. doctor não avisou do commit-msg alheio"; fi
rm -f "$h"

# 8. core.hooksPath no frontend: install não grava e avisa.
hf="$(common_hook_of "$FRONT")"
rm -f "$hf"
git -C "$FRONT" config core.hooksPath /nonexistent-hooks
out="$(install_out)"
if [ ! -e "$hf" ] && printf '%s' "$out" | grep -q 'boleto-frontend: core.hooksPath'; then pass "8. core.hooksPath: install não grava e avisa"; else bad "8. core.hooksPath deveria impedir a gravação"; fi
git -C "$FRONT" config --unset core.hooksPath

# 9. Hook removido: doctor sai com 1; install restaura (backend e frontend).
bash "$BOOT" doctor --editor none >/tmp/hook-doctor.$$ 2>&1; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'boleto-frontend: hook não instalado' /tmp/hook-doctor.$$; then pass "9. doctor sai com 1 e diz 'hook não instalado'"; else bad "9. doctor com hook removido (rc=$rc)"; fi
rm -f /tmp/hook-doctor.$$
install_out >/dev/null
if grep -q '^# boleto-hook: commit-msg' "$hf" && grep -q '^# boleto-hook: commit-msg' "$h"; then pass "9. install restaura o hook removido"; else bad "9. install não restaurou o hook"; fi

# 11. Node gravado inexistente: cai no node do PATH; sem Node nenhum, recusa e manda rodar o install.
orig_node="$(sed -n "s|^BOLETO_NODE='\(.*\)'\$|\1|p" "$h")"
sed "s|^BOLETO_NODE=.*|BOLETO_NODE='/nonexistent/node'|" "$h" > "$h.tmp" && mv "$h.tmp" "$h" && chmod +x "$h"
out="$(PATH="$(dirname "$orig_node"):$PATH" gc "$BACK" commit --allow-empty -m "mensagem invalida" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'type may not be empty'; then pass "11. Node gravado inexistente cai no node do PATH"; else bad "11. fallback para o node do PATH falhou (rc=$rc): $out"; fi
if PATH=/usr/bin:/bin command -v node >/dev/null 2>&1; then
  pass "11. (sem Node no PATH: pulado, há node em /usr/bin)"
else
  printf 'x\n' > "$HERE/.msg.$$"
  out="$(PATH=/usr/bin:/bin sh "$h" "$HERE/.msg.$$" 2>&1)"; rc=$?
  rm -f "$HERE/.msg.$$"
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'install'; then pass "11. sem Node nenhum o hook recusa e manda rodar o install"; else bad "11. sem Node o hook deveria recusar (rc=$rc): $out"; fi
fi
install_out >/dev/null

# 10. --no-verify pula o hook (comportamento documentado; a CI continua recusando).
before="$(count_of "$BACK")"
if gc "$BACK" commit --no-verify --allow-empty -m "mensagem invalida" >/dev/null 2>&1 && [ "$(count_of "$BACK")" -gt "$before" ]; then pass "10. --no-verify pula o hook"; else bad "10. --no-verify deveria pular o hook"; fi

printf '\n'
if [ "$FAILS" -gt 0 ]; then echo "$FAILS falha(s)."; exit 1; fi
echo "Todos os cenários do hook passaram."
