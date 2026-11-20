#!/usr/bin/env bash
# Prepara a máquina do desenvolvedor (Linux e macOS).
#
# Uso: bootstrap/bootstrap.sh [install|doctor] [opções]
#
#   install   (padrão) instala o mise, Java e Node nas versões do versions.toml,
#             configura o shell e instala as extensões do Kiro e do VS Code.
#   doctor    só diagnostica, sem alterar nada. Sai com código 1 se algo essencial faltar.
#
# Opções:
#   --no-persist       não altera o shell nem a configuração global do mise
#   --install-dir DIR  pasta onde ficam o mise, o Java e o Node (ex.: ~/dev/tools). O PATH,
#                      o JAVA_HOME e o mise do shell passam a apontar para ela. A escolha fica
#                      gravada (BOLETO_INSTALL_DIR no bloco do shell). Padrão: ~/.boleto-dev
#   --clone            clona os repositórios que faltarem ao lado do boleto-docs
#   --editor <nome>    kiro, code ou none (padrão: todos os que forem encontrados)
#   -h, --help         mostra esta ajuda
#
# Nada aqui exige root, exceto instalar a libatomic no Linux (o script só avisa).
#
# Variável de ambiente BOLETO_DEV_HOME: instala tudo dentro desta pasta, isolado
# (útil para testes). Implica --no-persist e não combina com --install-dir.
# Variável BOLETO_IGNORE_DOCKER=1: falhas do Docker viram aviso (só para CI).
#
# Requisito: Docker com Compose e Git já instalados. O resto este script instala.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_DIR="$(cd "$REPO_ROOT/.." && pwd)"
ENV_FILE="$REPO_ROOT/.platform/versions.env"
EXT_FILE="$SCRIPT_DIR/extensions.txt"
GITHUB_ORG="Titulize"
REPOS="boleto-docs boleto-backend boleto-frontend boleto-migrations"

CMD="install"
NO_PERSIST=0
INSTALL_DIR_OPT=""
CUSTOM_DIR=0
INSTALL_MODE="padrão (~/.boleto-dev)"
DO_CLONE=0
EDITOR_OPT=""
FAILS=0
WARNS=0

# --- saída ---------------------------------------------------------------

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_FAIL=$'\033[31m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_FAIL=""; C_OFF=""
fi
ok()   { printf '%s[ OK ]%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$C_WARN" "$C_OFF" "$*"; WARNS=$((WARNS + 1)); }
fail() { printf '%s[FAIL]%s %s\n' "$C_FAIL" "$C_OFF" "$*"; FAILS=$((FAILS + 1)); }
info() { printf '       %s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
die()  { printf '%s[ERRO]%s %s\n' "$C_FAIL" "$C_OFF" "$*" >&2; exit 2; }

# Imprime o cabeçalho de comentários (da linha 2 até a primeira linha que não é comentário).
usage() { awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; }

# --- argumentos ------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    install|doctor) CMD="$1" ;;
    --no-persist) NO_PERSIST=1 ;;
    --install-dir) shift; INSTALL_DIR_OPT="${1:-}"; [ -n "$INSTALL_DIR_OPT" ] || die "--install-dir precisa de uma pasta" ;;
    --clone) DO_CLONE=1 ;;
    --editor) shift; EDITOR_OPT="${1:-}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "argumento desconhecido: $1 (use --help)" ;;
  esac
  shift
done

# --- versões -----------------------------------------------------------------

load_versions() {
  [ -f "$ENV_FILE" ] || die "$ENV_FILE não existe. Rode: npm run sync"
  local k v var
  while IFS='=' read -r k v || [ -n "$k" ]; do
    case "$k" in ''|'#'*) continue ;; esac
    printf -v "V_$k" '%s' "$v"
  done < "$ENV_FILE"
  for k in JAVA_MAJOR JAVA_CORRETTO_BUILD NODE_VERSION GRADLE_VERSION MISE_VERSION; do
    var="V_$k"
    [ -n "${!var:-}" ] || die "variável $k ausente em $ENV_FILE. Rode: npm run sync"
  done
}

detect_platform() {
  local os arch
  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=macos ;;
    *) die "sistema não suportado: $(uname -s). No Windows use bootstrap/bootstrap.ps1" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) die "arquitetura não suportada: $(uname -m)" ;;
  esac
  PLATFORM="${os}_${arch}"
  PLATFORM_UP="$(printf '%s' "$PLATFORM" | tr '[:lower:]' '[:upper:]')"
}

# --- ambiente isolado ou padrão -------------------------------------------

use_mise_dirs_under_home() {
  export MISE_DATA_DIR="$BOLETO_HOME/mise/data"
  export MISE_CONFIG_DIR="$BOLETO_HOME/mise/config"
  export MISE_CACHE_DIR="$BOLETO_HOME/mise/cache"
  export MISE_STATE_DIR="$BOLETO_HOME/mise/state"
}

resolve_install_dir() {
  local dir="$1"
  # Til literal (vem entre aspas do usuário): expande para $HOME.
  case "$dir" in
    \~) dir="$HOME" ;;
    \~/*) dir="$HOME/${dir#\~/}" ;;
  esac
  case "$dir" in /*) ;; *) die "use um caminho absoluto em --install-dir: $1" ;; esac
  case "$dir" in *:*) die "o caminho não pode conter ':' (separador do PATH): $dir" ;; esac
  case "$dir" in *\"*|*\$*|*\`*|*\\*) die "o caminho não pode conter aspas, \$, \` ou \\: $dir" ;; esac
  if [ "$CMD" = install ]; then
    mkdir -p "$dir" 2>/dev/null || die "não consegui criar $dir. Escolha uma pasta do seu usuário (ex.: ~/dev/tools)"
    [ -w "$dir" ] || die "sem permissão de escrita em $dir. Escolha uma pasta do seu usuário (ex.: ~/dev/tools)"
  fi
  dir="${dir%/}"
  printf '%s' "${dir:-/}"
}

setup_dirs() {
  if [ -n "${BOLETO_DEV_HOME:-}" ]; then
    [ -z "$INSTALL_DIR_OPT" ] || die "BOLETO_DEV_HOME e --install-dir não podem ser usados juntos"
    BOLETO_HOME="$BOLETO_DEV_HOME"
    NO_PERSIST=1
    INSTALL_MODE="isolada (BOLETO_DEV_HOME)"
    use_mise_dirs_under_home
  elif [ -n "$INSTALL_DIR_OPT" ] || [ -n "${BOLETO_INSTALL_DIR:-}" ]; then
    # A escolha gravada no shell (BOLETO_INSTALL_DIR) vale quando --install-dir não é passado.
    if [ -n "$INSTALL_DIR_OPT" ]; then
      BOLETO_HOME="$(resolve_install_dir "$INSTALL_DIR_OPT")"
      INSTALL_MODE="escolhida (--install-dir)"
    else
      BOLETO_HOME="$(resolve_install_dir "$BOLETO_INSTALL_DIR")"
      INSTALL_MODE="escolhida (BOLETO_INSTALL_DIR)"
    fi
    CUSTOM_DIR=1
    use_mise_dirs_under_home
  else
    BOLETO_HOME="$HOME/.boleto-dev"
  fi
  BIN_DIR="$BOLETO_HOME/bin"
  MISE_SHIMS="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
  export MISE_YES=1
  export MISE_NO_ANALYTICS=1
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    die "sha256sum ou shasum são necessários para verificar downloads"
  fi
}

find_mise() {
  if [ -x "$BIN_DIR/mise" ]; then
    MISE="$BIN_DIR/mise"
  elif command -v mise >/dev/null 2>&1; then
    MISE="$(command -v mise)"
  else
    MISE=""
  fi
}

mise_version() { "$MISE" --version 2>/dev/null | awk '{print $1}'; }

# --- etapas ------------------------------------------------------------------

NEED_LIBATOMIC=0

# O Node (binário oficial) depende da libatomic no Linux. Instalar exige root, então só avisamos.
check_linux_libs() {
  [ "$(uname -s)" = Linux ] || return 0
  if ldconfig -p 2>/dev/null | grep -q 'libatomic\.so\.1' \
    || ls /usr/lib*/libatomic.so.1* /lib*/libatomic.so.1* /usr/lib/*/libatomic.so.1* >/dev/null 2>&1; then
    ok "libatomic (exigida pelo Node)"
  else
    NEED_LIBATOMIC=1
    fail "libatomic ausente (o Node precisa dela). Instale: sudo dnf install libatomic   ou   sudo apt-get install libatomic1"
  fi
}

# Na CI (sem Docker utilizável) BOLETO_IGNORE_DOCKER=1 rebaixa as falhas do Docker para aviso.
docker_problem() { if [ -n "${BOLETO_IGNORE_DOCKER:-}" ]; then warn "$*"; else fail "$*"; fi; }

check_prereqs() {
  step "Pré-requisitos"
  check_linux_libs
  if command -v git >/dev/null 2>&1; then ok "Git $(git --version | awk '{print $3}')"; else fail "Git não encontrado. Instale em https://git-scm.com/downloads"; fi
  if command -v docker >/dev/null 2>&1; then
    ok "Docker $(docker --version | sed 's/Docker version //; s/,.*//')"
    if docker compose version >/dev/null 2>&1; then
      ok "Docker Compose $(docker compose version --short 2>/dev/null || echo '')"
    else
      docker_problem "Docker Compose (plugin v2) não encontrado"
    fi
    if docker info >/dev/null 2>&1; then ok "daemon do Docker em execução"; else docker_problem "daemon do Docker parado. Inicie o Docker"; fi
  else
    docker_problem "Docker não encontrado. Instale em https://docs.docker.com/get-docker/"
  fi
}

install_mise() {
  step "mise $V_MISE_VERSION"
  # Só a cópia dentro da pasta de instalação conta: é ela que o PATH do shell vai usar.
  # Um mise de outra pasta (ou de uma instalação anterior) não é reaproveitado.
  if [ -x "$BIN_DIR/mise" ]; then
    MISE="$BIN_DIR/mise"
    local have; have="$(mise_version)"
    case "$have" in
      "$V_MISE_VERSION"*) ok "mise $have já instalado ($MISE)"; return ;;
      *) info "mise $have em $MISE difere da versão pinada; atualizando" ;;
    esac
  fi
  local url_var="V_MISE_URL_$PLATFORM_UP" sha_var="V_MISE_SHA256_$PLATFORM_UP"
  local url="${!url_var:-}" want="${!sha_var:-}"
  [ -n "$url" ] && [ -n "$want" ] || die "sem download do mise para $PLATFORM em $ENV_FILE"
  local tmp; tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  info "baixando $url"
  curl -fsSL --retry 3 -o "$tmp/mise.tar.gz" "$url"
  local got; got="$(sha256_of "$tmp/mise.tar.gz")"
  if [ "$got" != "$want" ]; then
    die "sha256 do mise não confere (esperado $want, obtido $got). Download descartado"
  fi
  tar -xzf "$tmp/mise.tar.gz" -C "$tmp"
  mkdir -p "$BIN_DIR"
  cp "$tmp/mise/bin/mise" "$BIN_DIR/mise"
  chmod +x "$BIN_DIR/mise"
  find_mise
  ok "mise $(mise_version) instalado em $MISE (sha256 conferido)"
}

install_tools() {
  step "Java $V_JAVA_MAJOR (Corretto $V_JAVA_CORRETTO_BUILD) e Node $V_NODE_VERSION"
  local java="java@corretto-$V_JAVA_CORRETTO_BUILD" node="node@$V_NODE_VERSION"
  # Roda a partir da pasta do usuário: dentro de um projeto, o mise.toml dele geraria avisos.
  if [ "$NO_PERSIST" -eq 0 ]; then
    (cd "$HOME" && "$MISE" use -g "$java" "$node")   # instala e define como padrão do usuário
    ok "Java e Node instalados e definidos como padrão do usuário (mise use -g)"
  else
    (cd "$HOME" && "$MISE" install "$java" "$node")
    info "--no-persist: padrão global do mise não alterado"
  fi
  info "Gradle $V_GRADLE_VERSION vem pelo Gradle Wrapper de cada projeto"
}

shell_integration() {
  step "Shell"
  if [ "$NO_PERSIST" -eq 1 ]; then info "--no-persist: arquivos do shell não alterados"; return; fi
  local rc files="$HOME/.bashrc $HOME/.profile"
  # Se existir, o shell de login lê o .bash_profile e ignora o .profile.
  [ -f "$HOME/.bash_profile" ] && files="$files $HOME/.bash_profile"
  [ -f "$HOME/.zshrc" ] && files="$files $HOME/.zshrc"
  case "${SHELL:-}" in */zsh) files="$files $HOME/.zshrc" ;; esac
  local done_list=""
  for rc in $files; do
    case " $done_list " in *" $rc "*) continue ;; esac
    done_list="$done_list $rc"
    touch "$rc"
    local tmp; tmp="$(mktemp)"
    awk '/# >>> boleto-dev/{skip=1} !skip{print} /# <<< boleto-dev/{skip=0}' "$rc" > "$tmp"
    {
      cat "$tmp"
      printf '%s\n' '# >>> boleto-dev (gerenciado por bootstrap.sh, não edite)'
      if [ "$CUSTOM_DIR" -eq 1 ]; then
        # Os caminhos já foram validados (sem aspas, $, ` ou \), então podem ir entre aspas duplas.
        printf 'export BOLETO_INSTALL_DIR="%s"\n' "$BOLETO_HOME"
        printf 'export MISE_DATA_DIR="%s"\n' "$MISE_DATA_DIR"
        printf 'export MISE_CONFIG_DIR="%s"\n' "$MISE_CONFIG_DIR"
        printf 'export MISE_CACHE_DIR="%s"\n' "$MISE_CACHE_DIR"
        printf 'export MISE_STATE_DIR="%s"\n' "$MISE_STATE_DIR"
      fi
      printf '%s\n' "export PATH=\"$BIN_DIR:$MISE_SHIMS:\$PATH\""
      # Delimitador entre aspas: o texto vai literal para o arquivo e só expande quando o shell o carregar.
      cat <<'RC'
if command -v mise >/dev/null 2>&1; then
  _boleto_jh="$(mise where java 2>/dev/null || true)"
  [ -n "$_boleto_jh" ] && export JAVA_HOME="$_boleto_jh"
  unset _boleto_jh
fi
# <<< boleto-dev
RC
    } > "$rc"
    rm -f "$tmp"
    ok "PATH e JAVA_HOME configurados em $rc"
  done
  info "abra um novo terminal para valer"
}

editors() {
  case "$EDITOR_OPT" in
    none) return ;;
    kiro|code) command -v "$EDITOR_OPT" >/dev/null 2>&1 && echo "$EDITOR_OPT"; return 0 ;;
    "") ;;
    *) die "--editor deve ser kiro, code ou none" ;;
  esac
  command -v kiro >/dev/null 2>&1 && echo kiro
  command -v code >/dev/null 2>&1 && echo code
  return 0
}

extension_list() { grep -v '^[[:space:]]*\(#\|$\)' "$EXT_FILE" | awk '{print $1}'; }

editor_extensions() {
  local mode="$1" found=0 cli installed ext lower
  step "Extensões do editor"
  if [ "$EDITOR_OPT" = none ]; then info "--editor none: extensões ignoradas"; return 0; fi
  for cli in $(editors); do
    found=1
    installed="$("$cli" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
    for ext in $(extension_list); do
      lower="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
      if printf '%s\n' "$installed" | grep -qx "$lower"; then
        [ "$mode" = doctor ] && ok "$cli: $ext"
        continue
      fi
      if [ "$mode" = install ]; then
        if "$cli" --install-extension "$ext" >/dev/null 2>&1; then ok "$cli: $ext instalada"; else warn "$cli: não consegui instalar $ext"; fi
      else
        warn "$cli: extensão $ext não instalada"
      fi
    done
  done
  if [ "$found" -eq 0 ]; then warn "nenhum editor encontrado (comandos kiro ou code no PATH)"; fi
}

repos_step() {
  step "Repositórios (ao lado do boleto-docs)"
  local r
  for r in $REPOS; do
    if [ -d "$WORKSPACE_DIR/$r/.git" ]; then
      ok "$r"
    elif [ "$DO_CLONE" -eq 1 ] && [ "$CMD" = install ]; then
      if git clone -q "git@github.com:$GITHUB_ORG/$r.git" "$WORKSPACE_DIR/$r" 2>/dev/null \
        || git clone -q "https://github.com/$GITHUB_ORG/$r.git" "$WORKSPACE_DIR/$r" 2>/dev/null; then
        ok "$r clonado"
      else
        warn "$r: não consegui clonar (repositório privado exige acesso ao GitHub)"
      fi
    else
      warn "$r não encontrado em $WORKSPACE_DIR (use --clone)"
    fi
  done
}

doctor_tools() {
  step "Ferramentas do desenvolvedor"
  info "pasta de instalação: $BOLETO_HOME ($INSTALL_MODE)"
  find_mise
  if [ -z "$MISE" ]; then
    fail "mise não encontrado. Rode: bootstrap/bootstrap.sh install"
    return
  fi
  local have; have="$(mise_version)"
  case "$have" in
    "$V_MISE_VERSION"*) ok "mise $have" ;;
    *) warn "mise $have (pinada: $V_MISE_VERSION)" ;;
  esac
  local home expected_java_home=""
  if home="$("$MISE" where "java@corretto-$V_JAVA_CORRETTO_BUILD" 2>/dev/null)" && [ -x "$home/bin/java" ]; then
    ok "Java Corretto $V_JAVA_CORRETTO_BUILD instalado ($home)"
    expected_java_home="$home"
  else
    fail "Java Corretto $V_JAVA_CORRETTO_BUILD não instalado. Rode: bootstrap/bootstrap.sh install"
  fi
  if home="$("$MISE" where "node@$V_NODE_VERSION" 2>/dev/null)" && [ -x "$home/bin/node" ]; then
    ok "Node $V_NODE_VERSION instalado ($home)"
  else
    fail "Node $V_NODE_VERSION não instalado. Rode: bootstrap/bootstrap.sh install"
  fi

  # O que este terminal enxerga agora.
  local line major
  if command -v java >/dev/null 2>&1; then
    line="$(java -version 2>&1 | head -1)"
    major="$(printf '%s' "$line" | sed -E 's/.*version "([0-9]+).*/\1/')"
    if [ "$major" = "$V_JAVA_MAJOR" ]; then ok "java no PATH deste terminal: $line"; else warn "java no PATH deste terminal é $major, esperado $V_JAVA_MAJOR. Abra um novo terminal ou ative o mise"; fi
  else
    warn "java fora do PATH deste terminal. Abra um novo terminal"
  fi
  if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/java" ]; then
    warn "JAVA_HOME não definido neste terminal"
  elif [ -n "$expected_java_home" ] && [ "${JAVA_HOME%/}" != "${expected_java_home%/}" ]; then
    warn "JAVA_HOME deste terminal ($JAVA_HOME) é de outra instalação. Abra um novo terminal"
  else
    ok "JAVA_HOME=$JAVA_HOME"
  fi
  if command -v node >/dev/null 2>&1; then
    case "$(node --version)" in
      "v$V_NODE_VERSION") ok "node no PATH deste terminal: $(node --version)" ;;
      *) warn "node no PATH deste terminal é $(node --version), esperado v$V_NODE_VERSION" ;;
    esac
  fi
  info "Gradle $V_GRADLE_VERSION vem pelo Gradle Wrapper de cada projeto"
}

summary() {
  printf '\n'
  if [ "$FAILS" -gt 0 ]; then
    printf '%sResultado: %d falha(s), %d aviso(s).%s\n' "$C_FAIL" "$FAILS" "$WARNS" "$C_OFF"
    exit 1
  fi
  if [ "$WARNS" -gt 0 ]; then
    printf '%sResultado: tudo essencial em ordem, %d aviso(s).%s\n' "$C_WARN" "$WARNS" "$C_OFF"
  else
    printf '%sResultado: tudo em ordem.%s\n' "$C_OK" "$C_OFF"
  fi
}

main() {
  load_versions
  detect_platform
  setup_dirs
  case "$CMD" in
    install)
      check_prereqs
      [ "$NEED_LIBATOMIC" -eq 0 ] || die "instale a libatomic e rode o install de novo (nada foi baixado)"
      install_mise
      install_tools
      shell_integration
      editor_extensions install
      repos_step
      step "Verificação final"
      FAILS=0; WARNS=0
      check_prereqs
      doctor_tools
      summary
      ;;
    doctor)
      check_prereqs
      doctor_tools
      editor_extensions doctor
      repos_step
      summary
      ;;
  esac
}

main
