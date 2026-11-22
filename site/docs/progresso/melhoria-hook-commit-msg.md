---
sidebar_position: 9
title: 'Melhoria: hook commit-msg'
---

# Melhoria M1: hook `commit-msg` com commitlint

- **Situação:** Em andamento
- **Início:** 2026-11-22
- **Última atualização:** 2026-11-22
- **Repositórios:** `boleto-docs` (código e documentação), `boleto-backend` e `boleto-migrations` (só README, pendente)

## Objetivo

Recusar no `git commit` a mensagem fora do Conventional Commits (linhas até 100 colunas), nos quatro repositórios e nos worktrees, instalado pelo bootstrap. Motivo e decisão no [ADR 0043](../adr/0043-hook-commit-msg.md).

## Entregue

- `bootstrap/hooks/commit-msg.sh`: corpo do hook em POSIX `sh`, com falha fechada.
- `bootstrap/bootstrap.ps1` e `bootstrap/bootstrap.sh`: o `install` instala o commitlint do `boleto-docs` (`npm ci --ignore-scripts`) e grava o hook em `<git-common-dir>/hooks/commit-msg` de cada repositório presente; o `doctor` mostra o estado, compara as `commitlint.config.mjs` e faz um autoteste. O `install` recusa rodar de um worktree.
- `bootstrap/tests/hook.tests.sh` e `bootstrap/tests/hook.tests.ps1`: onze cenários.
- CI do bootstrap (Ubuntu e Windows PowerShell 5.1): ShellCheck e sintaxe ampliados, repositórios de teste e os cenários do hook.
- ADR 0043, guias `ambiente-do-dev`, `commits-e-releases` e `padrao-do-projeto`, README.

## Verificação

| O quê | Como | Resultado |
|---|---|---|
| Sintaxe PowerShell | parser no PowerShell 7 e no 5.1 (`bootstrap.ps1`, `path.tests.ps1`, `hook.tests.ps1`) | 0 erros |
| ShellCheck | Docker `koalaman/shellcheck:stable`, `--shell=bash` e `--shell=sh` | sem avisos |
| Install e doctor reais (Windows) | `BOLETO_DEV_HOME` em pasta temporária, repositórios `git init` irmãos, PowerShell 5.1 | hook instalado nos quatro, autoteste OK |
| `hook.tests.ps1` | PowerShell 5.1 e PowerShell 7 contra essa pasta | todos os cenários passaram |
| `path.tests.ps1` | PowerShell 5.1 e PowerShell 7 | passou |
| Install, doctor e `hook.tests.sh` (Linux) | contêiner `ubuntu:24.04` com `BOLETO_DEV_HOME`, repositórios `git init` irmãos, duas rodadas; `install` a partir de um worktree | cenários passaram nas duas rodadas; o `install` no worktree recusou (código 2) |
| Testes do repositório | `npm ci`, `npm run validate`, `npm run sync:check`, `npm test` | 44 testes, 0 falhas |
| Build do site | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` | passou, sem link quebrado |
| CI | workflows do PR | pendente (PR ainda não aberto) |

Não verificado: macOS; Git Bash do Windows rodando o `bootstrap.sh` (ele é só para Linux e macOS); `install` real na máquina do dev.

## Falhas e correções

- O `hook.tests.ps1` usou `Gc` como nome de função, que é alias de `Get-Content` no PowerShell. A primeira execução falhou em quatro cenários. Renomeado para `Invoke-GitIn` e reexecutado.
- A primeira cópia de teste do `boleto-docs` herdou o arquivo `.git` do worktree e o `install` recusou, como previsto. A cópia passou a ter `git init` próprio.

- No contêiner Linux, a mensagem do hook saiu com `bootstrapootstrap.ps1`: o `echo` do `dash` interpretou `\b`. O caminho passou a usar `/`. O cenário 11 também falhou ali, porque o contêiner só tem Node no mise; o teste passou a pôr a pasta do Node gravado no PATH.
- O `shellcheck` apontou SC2015 em `hook.tests.sh`; trocado por `if`.
- Ao montar a cópia de demonstração, o `git add -A` e o commit `chore: base da demonstracao` caíram na branch real `feat/hook-commit-msg` (a cópia levou o arquivo `.git` do worktree). Nada foi enviado. O commit foi desfeito com `git reset --mixed HEAD~1` e os arquivos ficaram intactos.

## Decisões e desvios do plano

[ADR 0043](../adr/0043-hook-commit-msg.md). O steering `.kiro/steering/padrao-projeto.md` só referencia o padrão, sem trecho copiado a atualizar.

## Pendências

- PR, CI do `boleto-docs` e integração.
- README do `boleto-backend` e do `boleto-migrations`; o README do primeiro commit do `boleto-frontend` deve citar o hook.
- `bootstrap install` real e demonstração nos repositórios reais.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-22 | Implementação no `boleto-docs`, ADR 0043 e documentação |
