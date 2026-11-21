---
sidebar_position: 5
title: 'Task 05: Compose de desenvolvimento'
---

# Task 05: Compose de desenvolvimento (infraestrutura)

- **Situação:** Concluída
- **Início:** 2026-11-20
- **Última atualização:** 2026-11-21 (revisão: compose único, [ADR 0022](../adr/0022-compose-unico.md))
- **Repositórios:** `boleto-docs`

## Objetivo

Subir PostgreSQL, Valkey e Mailpit locais com um comando, nas versões do `versions.toml`, com healthchecks e atalhos `dev up`, `dev down` e `dev reset`.

## Entregue (entrega original)

Os atalhos, o `compose/` e o job do Windows descritos nesta e na próxima seção foram substituídos pela revisão "Compose único" mais abaixo.


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
- **A prova do cache (PR #5, reexecução do `CI`, tentativa 2) achou um defeito no passo novo.** O cache teve acerto (`Cache hit for: imagens-compose-v1-Linux-X64-b5996b4...`, 189 MB) e o `docker load` carregou as três imagens (`Loaded image ID: sha256:23a2ef8...`, `3ab0eca...`, `eb63372...`). Mesmo assim o passo emitiu `O cache não tinha todas as imagens. Baixando.` e rodou o `compose pull`. Causa: a função `faltando` consultava `docker image inspect repo:tag@digest`, e depois do `load` a imagem não responde por esse nome. O pull terminou em 0,15 s, sem baixar camadas, mas contatou o registro, então a tentativa 2 não provou o cache quente. Correção: a função também consulta `docker image inspect sha256:<digest>`, porque o ID carregado é o digest do `versions.toml`. Com a correção (run `44854998456`), o log mostra `Cache hit for: imagens-compose-v1-Linux-X64-b5996b4...`, `CACHE HIT ... carregando as imagens do cache, sem pull` e `Imagens carregadas do cache. Nenhum pull foi feito.`. O passo `dev up (Bash)` ainda imprime `Pulling`/`Pulled` para as três imagens em cerca de 0,5 s, sem camadas baixadas: o Compose consulta o registro porque a imagem carregada não tem o nome `repo:tag@digest`. O cache evita a transferência de dados, não a consulta ao registro (ADR 0021).

## Decisões e desvios do plano

- Decisões no [ADR 0020](../adr/0020-compose-dev.md): `compose/` separado do compose do site, imagens só pelo `versions.env`, portas em loopback, Valkey com senha, `reset` com confirmação.
- Cache das imagens na CI: [ADR 0021](../adr/0021-cache-imagens-ci.md).
- Valkey no lugar do Redis do plano original ([ADR 0006](../adr/0006-valkey.md)).
- O profile `observability` ficou para o Task 11.

## Pendências

- Nenhuma do Task 5. A publicação no GitHub Pages é conferida na `main` após a integração.
- Schema e roles do banco: Task 6.

## Revisão: compose único e só comandos padrão (ADR 0022)

Depois da entrega, o uso foi simplificado a pedido do desenvolvedor. O que mudou em relação ao que está descrito acima:

- `docker-compose.yml` único na raiz (infraestrutura e site). O site fica no profile `docs`. A pasta `compose/`, os atalhos `dev.ps1` e `dev.sh`, os verificadores `verify.*` e o `dev.tests.ps1` foram removidos. O reset é `docker compose down -v`, sem confirmação.
- Imagens com digest no bloco gerado do próprio arquivo (âncoras em `x-images`), escrito pelo alvo `docs` do `sync-versions.mjs` (lista `composeFiles` do `.platform/lock.json`). O `sync:check` falha se o bloco for editado.
- Valores padrão de desenvolvimento no arquivo. O `.env` é opcional, e o `.env.example` (agora na raiz) lista as variáveis.
- Nome do projeto mantido em `boleto-dev`: containers e volumes do ambiente que já rodava são os mesmos.
- CI: o job `Compose de desenvolvimento (Linux)` usa os comandos padrão, com sondas inline e o ciclo `down` / `down -v`, e mantém a chave do cache das imagens (a lista de imagens não mudou). O job `Compose (Windows PowerShell 5.1)` foi removido.

### Verificação da revisão

Local: Windows, Docker Desktop 29.8, Compose 5.5. As demonstrações usaram o projeto `boleto-demo-uni` (portas 25432, 26379, 28025, 21025 e 23000), para não tocar no `boleto-dev` do desenvolvedor, que ficou `healthy` do começo ao fim.

| O quê | Como | Resultado |
|---|---|---|
| Subida | `docker compose up -d --wait` na raiz, sem `-f` | saiu 0, PostgreSQL, Valkey e Mailpit `healthy`, sem o site |
| Mailpit | `GET /` e `GET /api/v1/info` na porta de interface | HTTP 200 nos dois |
| Sondas | `select 1`, `PONG` com senha, `NOAUTH` sem senha | passaram |
| `down` mantém os dados | tabela no PostgreSQL e chave no Valkey, `down`, `up -d --wait` | os dois dados continuaram, volumes preservados |
| `down -v` apaga | mesma tabela e chave, `down -v`, `up -d --wait` | sem volumes entre os dois, tabela e chave sumiram |
| Site | `docker compose --profile docs up -d --wait --build docs` e `up -d --wait docs` | `docs` `healthy`, HTTP 200 em `/boleto-docs/` |
| Build do site | `docker compose run --rm --no-deps docs sh -c "npm ci && npm run build"` (comando do padrão do projeto) | saiu 0, sem links quebrados |
| `logs` | `docker compose logs valkey --tail 3` | mostrou o log |
| Passos da CI no Bash | os passos novos do job, em Git Bash, contra o projeto de demonstração | `SIM-OK` |
| `npm run validate`, `sync:check`, `npm test` | | passaram (32 testes) |
| `docker compose config -q` (padrão e `--profile docs`) | | sem erros |

Os resultados da CI do PR ficam na seção seguinte, preenchida depois da integração.

### Falhas e correções da revisão

- **Teste novo do `sync:check` falhou na primeira execução:** a cópia temporária do repositório não tinha `.platform/versions.env` nem `mise.toml`, então o `check` acusava divergência neles. O teste passou a copiá-los.
- **Passo da CI que não falharia:** a sondagem das portas usava `! comando`, e o Bash com `-e` ignora falha de pipeline negado. Trocado por `if ...; then exit 1; fi` antes de enviar.
- **Descoberta na demonstração:** `docker compose down -v` sem `--profile docs` não para o site nem apaga o `docs_node_modules`. O guia e o ADR 0022 documentam que, para parar o site, o comando é `docker compose --profile docs down`.
- **Saída do terminal engolida** em duas execuções (comandos do Docker com barra de progresso). A demonstração foi repetida com um script que grava a saída em arquivo.

### Pendências da revisão

- Resultado da CI do PR e da `main` (preencher depois da integração).
- Se a regra de proteção da `main` exigir o job `Compose (Windows PowerShell 5.1)` pelo nome, precisa ser retirada da lista de checks obrigatórios.
## Histórico

| Data | Atualização |
|---|---|
| 2026-11-20 | Compose, atalhos, verificação, testes, CI e documentação. Demo local passou |
| 2026-11-20 | PR #4 com todos os jobs verdes. Task concluída e integrada por squash |
| 2026-11-21 | CI falhou no `6650ff5` por limite de pulls. Cache das imagens na CI (ADR 0021) |
| 2026-11-21 | Revisão: compose único na raiz, sem atalhos, imagens em bloco gerado (ADR 0022) |
