---
sidebar_position: 6
title: 'Task 06: Repositório boleto-migrations'
---

# Task 06: Repositório `boleto-migrations` (Flyway)

- **Situação:** Em andamento (parte A, no `boleto-docs`, pronta para o PR)
- **Início:** 2026-11-21
- **Última atualização:** 2026-11-21
- **Repositórios:** `boleto-docs`, `boleto-migrations`

## Objetivo

Schema inicial do banco e execução automática das migrações: uma imagem do Flyway (JAR sobre Amazon Corretto headless, Amazon Linux 2023) que valida e aplica as migrações uma vez, schema `V1` com roles separadas e RLS por tenant, e um teste de isolamento contra um PostgreSQL real.

## Entregue

Parte A, no `boleto-docs`:

- `versions.toml`: `[tools.flyway]` agora tem `version`, `main_class` e `[tools.flyway.jars]` (24 JARs do Maven Central, cada um com `group`, `artifact`, `version` e `sha256`). Novo `[tools.squawk]` (2.73.0, binário linux-x64 com sha256). O tarball do CLI saiu ([ADR 0024](../adr/0024-flyway-jar-corretto.md)).
- `scripts/validate-versions.mjs`: valida os JARs (versão exata, sha256, sem duplicata, classe principal) e rejeita a entrada antiga `url_linux_x64` do Flyway.
- `scripts/sync-versions.mjs`: o alvo `migrations` recebe Amazon Linux, Corretto headless e PostgreSQL, as variáveis `FLYWAY_VERSION`, `FLYWAY_MAIN_CLASS` e `SQUAWK_*`, o arquivo gerado `.platform/flyway-jars.lock`, `.node-version`, `mise.toml` (Node) e o bloco `x-images` do `compose.test.yml`. `FLYWAY_URL` e `FLYWAY_SHA256` deixaram de existir.
- `docker-compose.yml`: serviço `flyway` no profile `migrations`, execução única, depende do PostgreSQL saudável. `BOLETO_APP_PASSWORD` entrou no `.env.example`. Os comandos padrão (`up -d --wait`, `down`, `down -v`) seguem subindo só a infraestrutura.
- ADRs [0023](../adr/0023-primeira-main-boleto-migrations.md) a [0029](../adr/0029-permissao-por-tela.md): primeira `main`, Flyway por JAR, modelo de dados da V1, roles e RLS, migração como primeiro passo do deploy, lint de SQL e testes, permissão por tela.
- Documentação: [padrão do projeto](../guias/padrao-do-projeto.md) (regra expand/contract e exceção da primeira `main`), [versões](../guias/versoes.md), [Compose de desenvolvimento](../guias/compose-dev.md), [containers](../arquitetura/containers.md), [multi-tenancy e auditoria](../arquitetura/multitenancy-e-auditoria.md) e README.

## Verificação

Parte A, no worktree `boleto-docs/.worktrees/task-06-versions` (Windows, Docker 29.8.0).

| O quê | Como | Resultado |
|---|---|---|
| Flyway por JAR sobre Corretto headless | Container descartável com a imagem `25.0.5-al2023-headless`, PostgreSQL 18.7: `info`, `migrate` com callback `afterMigrate` e placeholders, `validate` | `info` listou o schema vazio, `migrate` aplicou a migração e executou o callback, `validate` saiu 0 |
| sha256 dos 24 JARs | Cada arquivo baixado comparado com o `.sha1` ou `.sha256` do Maven Central | todos conferem |
| sha256 do Squawk | Download de `squawk-linux-x64` da v2.73.0 e `Get-FileHash` | confere com o valor publicado no release |
| `npm run validate`, `npm run sync:check`, `npm test` | na raiz do worktree | `versions.toml` válido, versões em dia, 42 testes passaram (32 antes; novos: validação dos JARs, `flyway-jars.lock`, bloco `x-images` do `compose.test.yml`, serviço `flyway`) |
| Compose | `docker compose config --quiet` e `docker compose --profile migrations config --quiet` (sem a pasta `../boleto-migrations`) | os dois saíram 0 |
| Comandos padrão não executam o `flyway` | `docker compose up -d --wait` | subiram só PostgreSQL, Valkey e Mailpit |
| Build do site | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` | saiu 0, sem links quebrados |
| CNPJ de teste fora do repositório público | `git grep -n` do número no `boleto-docs` | sem resultado |
| `bootstrap/` intacto | `git diff --stat origin/main -- bootstrap` | sem mudanças (sem ShellCheck nem testes do PowerShell) |

Não verificado nesta parte: a imagem do `boleto-migrations` (parte B), o `docker compose up flyway` de ponta a ponta (depende do repositório `boleto-migrations`, ainda vazio) e a CI do PR.

## Falhas e correções

- **A imagem Corretto headless não põe `java` no `PATH`.** O primeiro teste do spike falhou com `java: command not found`. O JVM fica em `$JAVA_HOME/bin/java`. O entrypoint do `boleto-migrations` chama esse caminho.
- **Montar a pasta de JARs em `/lib` quebrou o container** (`No such file or directory` ao executar o `java`), porque `/lib` é um link para `/usr/lib` no Amazon Linux 2023. Os JARs ficam em `/flyway/lib`.
- **A lista mínima de JARs precisou de mais dois módulos.** Sem `flyway-command-mcp` e `flyway-command-test-connection`, a classe principal falhou com `NoClassDefFoundError: org/flywaydb/mcp/McpConfigurationLoader`. Os dois entraram na lista.
- **Variáveis do shell herdadas de uma demonstração anterior** (`COMPOSE_PROJECT_NAME=boleto-demo-uni` e portas `2xxxx`) fizeram o `docker compose up -d --wait` da verificação subir o projeto `boleto-demo-uni`, e não o `boleto-dev`. O `boleto-dev` do desenvolvedor não foi tocado. Os containers e volumes do `boleto-demo-uni` criados nessa execução foram removidos com `down -v`.
- **Arquivo `versions.toml` com linhas de log.** O gerador da tabela de JARs gravou as mensagens de conferência na saída do arquivo, e o `npm run validate` acusou o TOML inválido. As linhas foram removidas antes de qualquer commit.

## Decisões e desvios do plano

- Decisões novas nos ADRs 0023 a 0029.
- O plano chamava a branch de `feat/migrations-flyway-jar`. A branch usada é `feat/task-06-flyway-jar`, no worktree `task-06-versions`.

## Pendências

- Parte B: repositório `boleto-migrations` (imagem, schema `V1`, roles, RLS, testes de isolamento, lint de SQL, CI e README).
- Tag do `boleto-docs` depois do merge da parte A, que o `boleto-migrations` fixa.
- Parte C: este registro completo, `modelo-de-dados.md`, guia de migrações e `tasks.md`.
- A publicação da imagem multi-arquitetura fica para o Task 14.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-21 | Parte A: JARs do Flyway e Squawk no `versions.toml`, sincronização, serviço `flyway` no Compose e ADRs 0023 a 0029 |
