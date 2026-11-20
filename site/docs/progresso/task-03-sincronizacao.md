---
sidebar_position: 3
title: 'Task 03: Sincronização de versões'
---

# Task 03: Sincronização de versões

- **Situação:** Concluída
- **Início:** 2026-11-20
- **Última atualização:** 2026-11-20
- **Repositórios:** `boleto-docs`

## Objetivo

Gerar, em cada repositório, os arquivos derivados de uma tag do `versions.toml`, e falhar na CI quando houver divergência.

## Entregue

- `scripts/sync-versions.mjs`, com os comandos `init`, `sync`, `check [--remote]` e `update --tag`. Roda só com Node, sem `npm install`.
- Parser TOML embarcado em `scripts/vendor/` (smol-toml 1.9.1, BSD-3-Clause).
- Arquivos gerados por alvo: `libs.versions.toml` e wrapper do Gradle (backend), `.node-version` e pins do `package.json` (frontend), variáveis do Flyway (migrations), `.platform/versions.env` e blocos de `ARG` nos Dockerfiles (todos).
- `.platform/lock.json` com a tag e o sha256 do `versions.toml`.
- A CI do `boleto-docs` roda `npm run sync:check`.
- Tag `v0.2.0`.

## Verificação

| O quê | Como | Resultado |
|---|---|---|
| Testes | `npm test` | 20 testes, todos passaram |
| Demonstração | `init` em pasta vazia baixando a tag `v0.2.0` do GitHub, `check --remote`, edição manual do wrapper, `check`, `sync` | arquivos gerados, `check` falhou com exit 1 após a edição, `sync` corrigiu |
| Dockerfile com bloco gerado | build da imagem do site | passou |
| CI | workflows CI e Documentação no commit `b9482b2` | verdes |

## Falhas e correções

Nenhuma falha de CI nesta tarefa.

## Decisões e desvios do plano

- Script único em Node, em vez de PowerShell e Bash.

## Pendências

- Os repositórios de aplicação ainda não usam a sincronização. Cada um a recebe na tarefa em que ganha código (Tasks 6, 7 e 12).

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-20 | Script, testes, CI, tag `v0.2.0` |
