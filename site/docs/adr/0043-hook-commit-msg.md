---
title: 'ADR 0043: Hook commit-msg com commitlint, instalado pelo bootstrap'
---

# ADR 0043: Hook commit-msg com commitlint, instalado pelo bootstrap

- **Status:** Aceito
- **Data:** 2026-11-22

## Contexto

O commitlint da CI reprovou commits já enviados por linhas de corpo com mais de 100 colunas: duas vezes no Task 8 (uma correção exigiu reescrever a branch; na outra o PR #5 do `boleto-backend` foi fechado e reenviado como PR #6) e uma no Task 6 (PR #1 do `boleto-docs`). O [padrão do projeto](../guias/padrao-do-projeto.md) já manda rodar o commitlint antes de enviar, mas isso depende de lembrar. Os agentes trabalham em worktrees (`<repo>/.worktrees/<nome>`), e o `boleto-frontend` ainda não tem commit.

## Decisão

O `bootstrap` (`bootstrap.ps1` e `bootstrap.sh`) grava o hook `commit-msg` em `<git-common-dir>/hooks/` de cada repositório presente (`boleto-docs`, `boleto-backend`, `boleto-migrations`, `boleto-frontend`).

- **Mecanismo.** Arquivo em `.git/hooks`, não `core.hooksPath`. O diretório comum é compartilhado por todos os worktrees e existe em repositório vazio. O bootstrap não grava se `core.hooksPath` estiver definido nem sobrescreve um `commit-msg` sem o marcador `# boleto-hook: commit-msg`.
- **Texto único.** O corpo do hook é `bootstrap/hooks/commit-msg.sh` do `boleto-docs`. O bootstrap acrescenta o cabeçalho com o caminho do `boleto-docs` e do Node. Nenhum arquivo novo nos outros repositórios.
- **Ferramenta.** O hook usa o commitlint e a `commitlint.config.mjs` do `boleto-docs` (`@commitlint/cli` 21.2.4, travado em `package.json` e `package-lock.json`). O install roda `npm ci --ignore-scripts` na raiz do `boleto-docs` uma vez. Depois disso o hook não usa rede. A versão não entra no `versions.toml`: seria uma segunda fonte, e exigiria sincronizar e dar tag nos outros repositórios.
- **Windows.** O Git executa o hook pelo `sh` do Git for Windows. O corpo é POSIX `sh`, o arquivo é gravado em LF e sem BOM, e os caminhos (com espaço) ficam entre aspas.
- **Falha fechada.** Sem Node, `cli.js` ou configuração, o hook recusa o commit e manda rodar o `install`.
- **Diagnóstico.** O `doctor` mostra o estado por repositório e faz um autoteste num repositório temporário (inválida recusada, válida aceita).
- **Reaplicação.** O `install` regrava o hook quando o conteúdo gerado difere. Não há reinstalação automática.
- **Escape.** `git commit --no-verify` pula o hook. Não é recomendado: a CI (job `Conventional Commits`) continua sendo a barreira final.

## Consequências

- Cada dev precisa rodar o `install` uma vez (e de novo ao clonar um repositório novo ou mudar a pasta do `boleto-docs`). Sem isso o `doctor` falha.
- O `install` não roda a partir de um worktree do `boleto-docs`, porque o caminho do checkout principal fica gravado no hook.
- O hook usa a config do `boleto-docs`, e a CI de cada repositório usa a sua. Hoje são idênticas; o `doctor` avisa se diferirem.
- O caminho do checkout principal do `boleto-docs` fica gravado no hook. Mover a pasta exige novo `install`.
- Alternativas rejeitadas: `core.hooksPath` com pasta versionada em cada repositório (quatro cópias; caminho relativo quebra em worktree, branch antiga e repositório vazio), `core.hooksPath` global (atinge repositórios alheios), Husky ou lefthook (dependência nova em repositórios que nem têm `package.json`).
