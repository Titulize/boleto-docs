---
sidebar_position: 5
title: 'Task 05: Compose de desenvolvimento'
---

# Task 05: Compose de desenvolvimento (infraestrutura)

- **Situação:** Concluída
- **Início:** 2026-11-20
- **Última atualização:** 2026-11-21
- **Repositórios:** `boleto-docs`

## Objetivo

Subir PostgreSQL, Valkey e Mailpit locais com um comando, nas versões do `versions.toml`, com healthchecks e atalhos `dev up`, `dev down` e `dev reset`.

## Entregue

- `compose/docker-compose.yml` (projeto `boleto-dev`): PostgreSQL 18.7, Valkey 9.1.4 e Mailpit 1.34.0, com healthchecks, volumes nomeados `postgres_data` e `valkey_data` e portas em `127.0.0.1`. As imagens vêm de `.platform/versions.env`, por digest.
- `compose/.env.example` com portas e credenciais de desenvolvimento. O `up` cria o `compose/.env` a partir dele.
- Atalhos `compose/dev.ps1` (PowerShell 7 e Windows PowerShell 5.1) e `compose/dev.sh` (Bash): `up`, `down`, `reset` (com confirmação), `ps`, `logs` e `help`.
- Verificação `compose/tests/verify.sh` e `compose/tests/verify.ps1`: espera todos os serviços ficarem `healthy` e sonda cada um.
- Testes `compose/tests/dev.tests.ps1` (lógica do `dev.ps1`) e `scripts/compose.test.mjs` (regras do compose, no `npm test`).
- Jobs de CI `Compose de desenvolvimento (Linux)` e `Compose (Windows PowerShell 5.1)`.
- Guia [Compose de desenvolvimento](../guias/compose-dev.md), [ADR 0020](../adr/0020-compose-dev.md), [containers](../arquitetura/containers.md), [versões](../guias/versoes.md), [ambiente do dev](../guias/ambiente-do-dev.md) e README atualizados.

## Verificação

Local: Windows, Docker 29.8.0, Compose 5.5.1, PowerShell 7.7.0, Windows PowerShell 5.1 e Git Bash 5.3.

| O quê | Como | Resultado |
|---|---|---|
| Demo (PowerShell 7) | `compose/dev.ps1 up` chamado de outra pasta, depois `compose/tests/verify.ps1` | `up` saiu 0, três serviços `healthy`, `verify` passou (10 verificações) |
| Mailpit em `localhost:8025` | `Invoke-WebRequest` e `curl.exe http://localhost:8025`, `GET /api/v1/info` | HTTP 200 nos dois. A API devolveu `"Version":"v1.34.0"` |
| `down` e `up` (5.1) | tabela no PostgreSQL e chave no Valkey, `down`, `up` | os dados continuaram |
| `reset` sem confirmação (5.1 e 7) | `reset` com stdin redirecionado | recusou, código 2 |
| `reset -Yes` (5.1) | tabela e chave criadas antes | sumiram, serviços `healthy`, `verify.ps1` passou |
| Porta ocupada (7) | listener local em `127.0.0.1:5432` antes do `up` | `up` saiu 1 com a mensagem que aponta o `compose/.env` |
| `ps`, `logs mailpit`, comando inválido, `help` (5.1) | | 0, 0, 2, 0 |
| Ciclo com Bash (Git Bash) | `dev.sh up` (de `/tmp`), `verify.sh`, `reset` sem `--yes` (stdin não terminal), `reset --yes`, `logs valkey`, `down` | 0, 0, 2, 0 (tabela sumiu), 0, 0. Projeto vazio depois do `down` |
| ShellCheck | `dev.sh` e `verify.sh` | sem avisos |
| Parser do PowerShell | os três `.ps1` no 7 e no 5.1 | sem erros |
| `dev.tests.ps1` | PowerShell 7 e 5.1 | todos passaram |
| `path.tests.ps1` (regressão do bootstrap) | PowerShell 7 e 5.1 | todos passaram |
| `npm test`, `npm run validate`, `npm run sync:check` | | 27 testes passaram, 0 e 0 |
| Workflows da CI | actionlint 1.7.12 local | sem erros |
| CI no GitHub | PR #4, commit `d1047e5` | os 7 jobs de `CI` e o `Build do site` passaram (ver abaixo) |

Não verificado: macOS e Bash em Linux local (o Bash rodou na CI no Ubuntu). No runner Windows não há containers Linux, então o Windows PowerShell 5.1 com Docker real foi verificado só nesta máquina.

### CI do PR #4 (commit `d1047e5`)

Todos passaram na primeira execução: CI / Validar versions.toml e testes, CI / Bootstrap (Linux), CI / Bootstrap (Windows PowerShell 5.1), CI / Compose de desenvolvimento (Linux), CI / Compose (Windows PowerShell 5.1), CI / Conventional Commits e Documentação / Build do site. O job Publicar no GitHub Pages é pulado em PR e roda na `main` após a integração.

## Falhas e correções

- **`verify.ps1` falhou no Windows PowerShell 5.1** na sondagem do PostgreSQL (`select 1` sem resposta). O 5.1 não escapa aspas duplas dentro de argumentos passados a programas nativos, e o `sh -c 'psql -U "$POSTGRES_USER" ...'` chegou quebrado ao container. O comando passou a não usar aspas duplas internas.
- **Teste do `reset` sem confirmação travou** na primeira tentativa: o terminal da execução não tinha stdin redirecionado, então o script tratou a sessão como interativa e esperou a resposta. O comportamento do script está certo. O teste passou a redirecionar o stdin, como acontece em scripts e na CI.
- **`Join-Path` com `\`** (`.platform\versions.env`) quebraria o `dev.ps1` no PowerShell 7 em Linux, onde a CI o executa. Trocado por `/`, que funciona nos dois sistemas. Encontrado antes de enviar.
- **Build do site falhou com `ENOTEMPTY`** em `/app/node_modules` no projeto Compose `boleto-docs`. O volume `docs_node_modules` é compartilhado com o checkout principal do `boleto-docs`. Rodado com `docker compose -p boleto-docs-wt run --rm --no-deps docs sh -c "npm ci && npm run build"`, passou.

- **CI falhou no commit `6650ff5` (`main`, squash do PR #4), job `Compose de desenvolvimento (Linux)`, passo `Baixar as imagens (até 3 tentativas)`.** O log da tentativa 1 mostra `error from registry: Data limit exceeded` no pull do PostgreSQL (`public.ecr.aws`) nas três tentativas do passo, em cerca de 65 segundos. A reexecução (tentativa 2) passou. A hipótese inicial, limite do Docker Hub, estava errada: o Valkey e o Mailpit (`docker.io`) não chegaram a falhar, e o recusado foi o `public.ecr.aws`. Este registro não tinha essa falha, e o PR #4 tinha passado sem ela. Correção: cache das imagens na CI, com chave derivada da lista de imagens com digest, e o passo imprime `CACHE HIT` ou `CACHE MISS` e pula o pull quando há acerto ([ADR 0021](../adr/0021-cache-imagens-ci.md)). Alternativa registrada e não adotada: `docker login` no Docker Hub com conta gratuita.

## Decisões e desvios do plano

- Decisões no [ADR 0020](../adr/0020-compose-dev.md): `compose/` separado do compose do site, imagens só pelo `versions.env`, portas em loopback, Valkey com senha, `reset` com confirmação.
- Cache das imagens na CI: [ADR 0021](../adr/0021-cache-imagens-ci.md).
- Valkey no lugar do Redis do plano original ([ADR 0006](../adr/0006-valkey.md)).
- O profile `observability` ficou para o Task 11.

## Pendências

- Nenhuma do Task 5. A publicação no GitHub Pages é conferida na `main` após a integração.
- Schema e roles do banco: Task 6.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-20 | Compose, atalhos, verificação, testes, CI e documentação. Demo local passou |
| 2026-11-20 | PR #4 com todos os jobs verdes. Task concluída e integrada por squash |
| 2026-11-21 | CI falhou no `6650ff5` por limite de pulls. Cache das imagens na CI (ADR 0021) |
