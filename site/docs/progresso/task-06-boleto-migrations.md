---
sidebar_position: 6
title: 'Task 06: Repositório boleto-migrations'
---

# Task 06: Repositório `boleto-migrations` (Flyway)

- **Situação:** Concluída
- **Início:** 2026-11-21
- **Última atualização:** 2026-11-22
- **Repositórios:** `boleto-docs`, `boleto-migrations`

## Objetivo

Schema inicial do banco e execução automática das migrações: uma imagem do Flyway (JAR sobre Amazon Corretto headless, Amazon Linux 2023) que valida e aplica as migrações uma vez, schema `V1` com roles separadas e RLS por tenant, e um teste de isolamento contra um PostgreSQL real.

## Entregue

Parte A, no `boleto-docs` (PR [#7](https://github.com/Titulize/boleto-docs/pull/7), squash `b8290f7`, tag `v0.4.0`):

- `versions.toml`: `[tools.flyway]` tem `version`, `main_class` e `[tools.flyway.jars]` (24 JARs do Maven Central, cada um com `group`, `artifact`, `version` e `sha256`). Novo `[tools.squawk]` (2.73.0, binário linux-x64 com sha256). O tarball do CLI saiu ([ADR 0024](../adr/0024-flyway-jar-corretto.md)).
- `scripts/validate-versions.mjs`: valida os JARs (versão exata, sha256, sem duplicata, classe principal) e rejeita a entrada antiga `url_linux_x64` do Flyway.
- `scripts/sync-versions.mjs`: o alvo `migrations` gera `.platform/flyway-jars.lock`, as variáveis `FLYWAY_VERSION`, `FLYWAY_MAIN_CLASS` e `SQUAWK_*`, `.node-version`, `mise.toml` e o bloco `x-images` do `compose.test.yml`. `FLYWAY_URL` e `FLYWAY_SHA256` deixaram de existir.
- `docker-compose.yml`: serviço `flyway` no profile `migrations`, execução única, depende do PostgreSQL saudável. `BOLETO_APP_PASSWORD` entrou no `.env.example`. Os comandos padrão (`up -d --wait`, `down`, `down -v`) seguem subindo só a infraestrutura.
- ADRs [0023](../adr/0023-primeira-main-boleto-migrations.md) a [0029](../adr/0029-permissao-por-tela.md) e a regra expand/contract no [padrão do projeto](../guias/padrao-do-projeto.md).

Parte B, no `boleto-migrations` (PR [#1](https://github.com/Titulize/boleto-migrations/pull/1), squash `9673a5a`; commit inicial `a72f995` direto na `main`, exceção do [ADR 0023](../adr/0023-primeira-main-boleto-migrations.md)):

- Imagem de migração: `Dockerfile` com estágios `baixar` (24 JARs conferidos contra `.platform/flyway-jars.lock`), `lint` (Squawk) e final (Corretto headless, usuário 10001). `docker/entrypoint.sh` executa `migrate`, `validate` e `info` e sai com código diferente de zero em qualquer erro.
- `sql/V1__schema_inicial.sql`: empresa gestora, usuários, perfis, telas e permissões por tela, tokens de convite e recuperação, `revinfo` e tabelas `_aud`, três roles (`boleto_owner`, `boleto_app`, `boleto_funcoes`), funções de resolução de tenant e RLS forçado por `tenant_id`. Detalhes em [Modelo de dados](../arquitetura/modelo-de-dados.md).
- `sql/afterMigrate.sql`: senha da `boleto_app` e CNPJ da Titulize (valor de teste, configurável) a cada execução.
- Testes: `compose.test.yml` com PostgreSQL 18, casos SQL `tests/sql/01` a `08b` e `tests/admin/09` (executados como `boleto_app`), casos negativos da imagem em `tests/negativos.sh`.
- CI: `Conventional Commits` (só em PR) e o job do banco (sync, ShellCheck, lint, isolamento, negativos), com cache das imagens ([ADR 0021](../adr/0021-cache-imagens-ci.md)). Actions fixadas por SHA.
- README com conteúdo, uso, variáveis, contrato da imagem, regra expand/contract, como acrescentar uma tela e o aviso do CNPJ de teste.

Parte C, no `boleto-docs` (PR [#8](https://github.com/Titulize/boleto-docs/pull/8), squash `d251c10`):

- Este registro e o índice; [ADR 0030](../adr/0030-manutencao-de-dados-e-origem-do-tenant.md); nova página [Modelo de dados](../arquitetura/modelo-de-dados.md); novo guia [Migrações do banco](../guias/migracoes.md); ajustes em `containers.md`, `multitenancy-e-auditoria.md`, `compose-dev.md`, `versoes.md`, `padrao-do-projeto.md` (verificações do `boleto-migrations` e migração de dados em tabela de tenant), nos ADRs 0026 e 0028, no README e no comentário do serviço `flyway` do `docker-compose.yml` (agora cita `run --build --rm flyway`).

Fechamento, no `boleto-migrations` (PR [#2](https://github.com/Titulize/boleto-migrations/pull/2), squash `a2328e7`), sem mudança de SQL, política ou role:
- README: seção "Migração de dados e RLS forçado" (backfill como `boleto_owner` sem `app.tenant_id` afeta 0 linhas sem erro, com o padrão correto) e seção "TLS na conexão de produção" (`sslmode=verify-full`).
- `tests/negativos.sh`: os casos 4, 5 e 6 exigem a mensagem real (`password authentication failed`, `Unable to obtain connection`, `Detected resolved migration not applied to database`) e as três regras do Squawk (`ban-drop-column`, `renaming-column`, `adding-not-nullable-field`).
- `compose.test.yml`: o comentário do topo cita `run --build --rm tests`.
Fechamento, no `boleto-docs` (este PR): registro e índice como "Concluída", aviso de `sslmode=verify-full` e padrão de backfill com `SET LOCAL` no guia [Migrações do banco](../guias/migracoes.md), e `tasks.md`.
## Verificação

Parte A, no worktree do `boleto-docs` (Windows, Docker 29.8.0):

| O quê | Como | Resultado |
|---|---|---|
| Flyway por JAR sobre Corretto headless | Container descartável (`25.0.5-al2023-headless`), PostgreSQL 18.7: `info`, `migrate` com callback `afterMigrate` e placeholders, `validate` | `info` listou o schema vazio, `migrate` aplicou e executou o callback, `validate` saiu 0 |
| sha256 dos 24 JARs e do Squawk | Cada arquivo baixado contra o `.sha1` ou `.sha256` publicado | todos conferem |
| `npm run validate`, `npm run sync:check`, `npm test` | raiz do worktree | válido, em dia, 42 testes passaram |
| Compose | `docker compose config --quiet` e `--profile migrations config --quiet` | os dois saíram 0 |
| Build do site | `docker compose --profile docs run --rm --no-deps docs sh -c "npm ci && npm run build"` | saiu 0 |

Parte B, no worktree do `boleto-migrations`, registro do commit `9673a5a`:

| O quê | Como | Resultado |
|---|---|---|
| Versões | `node .platform/sync-versions.mjs check --remote` | em dia (`v0.4.0`) |
| Shell | ShellCheck (`koalaman/shellcheck:stable`) nos `.sh` | sem avisos |
| Lint | `docker build --target lint .` e o mesmo com `tests/fixtures/lint-negativo` | o primeiro passou, o segundo falhou (esperado) |
| Imagem | `docker build -t boleto-migrations:dev .` | passou |
| Isolamento | `docker compose -f compose.test.yml run --build --rm tests` | `preparar`, `admin/09` e `sql/01` a `08b` passaram como `boleto_app` |
| Teste não vazio | política permissiva injetada em `usuario` | `04_isolamento_leitura` falhou |
| Casos negativos | `bash tests/negativos.sh` | migração alterada, SQL inválido, senha errada, banco inacessível, variáveis ausentes, `validate` com pendência, lint e CNPJ configurável saíram como esperado |
| Demonstração | projeto `boleto-t6`, porta 15432 | `migrate` aplicou a V1, `psql` mostrou o schema |

Parte C, no worktree do `boleto-docs`:

| O quê | Como | Resultado |
|---|---|---|
| Migração no Compose do `boleto-docs`, de ponta a ponta | projeto `boleto-t6c`, porta 15433: `docker compose -p boleto-t6c up -d --wait postgres`, `docker compose -p boleto-t6c run --build --rm flyway`, segunda execução, `down -v` | a V1 foi aplicada (`Schema version: 1`), saída 0; a segunda execução disse "up to date" e saiu 0; o PostgreSQL continuou de pé depois do `run`. O `boleto-dev` do desenvolvedor não foi tocado |
| Comandos do guia de migrações | `\dn`, `\du`, `flyway_schema_history` como `postgres`; `boleto_app` com e sem `set_config('app.tenant_id', ...)` | `boleto_owner` dona do schema; com o tenant da Titulize a `boleto_app` viu 1 empresa, sem o tenant viu 0 |
| Mutação do teste de escrita | cópia temporária do `boleto-migrations` com `create policy ... for all to boleto_app using (true) with check (true)` em `usuario`; depois `05_isolamento_escrita` sozinho | `03_falha_fechada` já falhou na suíte inteira; o `05` sozinho falhou com "esperava erro, mas executou: insert into boleto.usuario ..." (tenant B). A cópia foi apagada |

As verificações locais restantes (`commitlint`, `validate`, `sync:check`, `npm test`, `docker compose config`, build do site, `git grep` do CNPJ de teste e conferência de `bootstrap/`) estão no registro do commit desta parte.

### Workflows

| Repositório | Workflow | Evento | Run | Resultado |
|---|---|---|---|---|
| `boleto-docs` | CI (5 jobs: validar e testes, bootstrap Linux, bootstrap Windows PowerShell 5.1, Compose Linux, Conventional Commits) | PR #7 | [44867984531](https://github.com/Titulize/boleto-docs/actions/runs/44867984531) | verde |
| `boleto-docs` | Documentação (build do site; publicação ignorada no PR) | PR #7 | [44867984570](https://github.com/Titulize/boleto-docs/actions/runs/44867984570) | verde |
| `boleto-docs` | CI | `main` depois do squash `b8290f7` | [44875700519](https://github.com/Titulize/boleto-docs/actions/runs/44875700519) | verde |
| `boleto-docs` | Documentação (build e publicação no Pages) | `main` depois do squash `b8290f7` | [44875700415](https://github.com/Titulize/boleto-docs/actions/runs/44875700415) | verde |
| `boleto-migrations` | CI (`Conventional Commits` 19 s e `Lint, imagem e testes de isolamento` 2 min 17 s) | PR #1 | [44879522723](https://github.com/Titulize/boleto-migrations/actions/runs/44879522723) | verde |
| `boleto-migrations` | CI | `main` depois do squash `9673a5a` | [44879738999](https://github.com/Titulize/boleto-migrations/actions/runs/44879738999) | verde |
| `boleto-docs` | CI | PR #8 (parte C) | [44880817521](https://github.com/Titulize/boleto-docs/actions/runs/44880817521) | verde |
| `boleto-docs` | Documentação | PR #8 | [44880817526](https://github.com/Titulize/boleto-docs/actions/runs/44880817526) | verde |
| `boleto-docs` | CI | `main` depois do squash `d251c10` | [44880967079](https://github.com/Titulize/boleto-docs/actions/runs/44880967079) | verde |
| `boleto-docs` | Documentação | `main` depois do squash `d251c10` | [44880967080](https://github.com/Titulize/boleto-docs/actions/runs/44880967080) | verde |
| `boleto-migrations` | CI (`Conventional Commits` e `Lint, imagem e testes de isolamento`) | PR #2 (fechamento) | [44881885505](https://github.com/Titulize/boleto-migrations/actions/runs/44881885505) | verde |
| `boleto-migrations` | CI (o job de commits só roda em PR e foi ignorado) | `main` depois do squash `a2328e7` | [44882064522](https://github.com/Titulize/boleto-migrations/actions/runs/44882064522) | verde |
Os workflows do PR de fechamento do `boleto-docs` (este) e da `main` depois dele constam no relatório final da tarefa: citá-los aqui exigiria outro PR.
Verificação do PR #2 do `boleto-migrations`, no worktree dele: `bash tests/negativos.sh` (casos 1 a 7 passaram), ShellCheck dos 5 `.sh` (0), `node .platform/sync-versions.mjs check --remote` (0), `docker build --target lint .` (0), `docker compose -p boleto-migrations-test -f compose.test.yml run --build --rm tests` ("todos os testes passaram", seguido de `down -v`) e `commitlint` (0). A CI repetiu o teste de isolamento e os casos negativos.

## Falhas e correções

- **Nenhum workflow falhou** nos dois repositórios neste Task, conforme `gh run list` nos dois repositórios (os workflows listados acima, todos verdes na primeira execução).
- **Primeiro build do site da revisão da parte A falhou** com ENOENT em `/app/build/__server/server.bundle.js` (`build/` antigo no bind mount). A segunda execução do mesmo comando passou, sem mudar arquivos.
- **`up --exit-code-from` pararia o PostgreSQL** (achado da parte A). O comando documentado implicava `--abort-on-container-exit`. Trocado por `docker compose run --build --rm flyway`. O comentário do serviço no `docker-compose.yml` ainda citava `up flyway`, e a revisão da parte A apontou isso. Corrigido na parte C.
- **A imagem Corretto headless não põe `java` no `PATH`.** O primeiro teste do spike falhou com `java: command not found`. O entrypoint chama `$JAVA_HOME/bin/java`.
- **Montar os JARs em `/lib` quebrou o container**, porque `/lib` é um link para `/usr/lib` no Amazon Linux 2023. Os JARs ficam em `/flyway/lib`.
- **A lista mínima de JARs precisou de mais dois módulos** (`flyway-command-mcp` e `flyway-command-test-connection`), por causa de `NoClassDefFoundError: org/flywaydb/mcp/McpConfigurationLoader`.
- **Variáveis do shell herdadas de uma demonstração anterior** (`COMPOSE_PROJECT_NAME` e portas `2xxxx`) fizeram o `docker compose up -d --wait` da verificação subir o projeto `boleto-demo-uni`, e não o `boleto-dev`. O `boleto-dev` não foi tocado, e os recursos criados foram removidos.
- **`versions.toml` com linhas de log.** O gerador da tabela de JARs gravou mensagens no arquivo, e o `npm run validate` acusou TOML inválido. As linhas saíram antes de qualquer commit.
- **`bash tests/negativos.sh` falhou no caso 1 no fechamento** (`saída sem 'Successfully applied'`): duas execuções rodaram ao mesmo tempo no projeto `boleto-migrations-neg`, e a segunda encontrou a V1 já aplicada. Sozinha, passou inteira. O código não mudou.
- **Ambiente local do fechamento:** o `bash` do PATH é o do WSL e falhou com `execvpe(/bin/bash)` (usado o Git Bash). No worktree novo faltava `node_modules`, e o `npx commitlint` esperava confirmação de instalação (`npm ci` resolveu).
- **A pasta `boleto-docs/.worktrees/task-06-versions` ficou vazia e presa por outro processo.** `Remove-Item` falhou. O git já a desregistrou, e ela não afeta nenhum arquivo.
- **Falhas locais da parte B não foram registradas.** O registro do commit `9673a5a` diz que todas as verificações passaram, sem listar tentativas anteriores. Se houve falha intermediária, este registro não a tem.

## Decisões e desvios do plano

- Decisões novas nos [ADR 0023](../adr/0023-primeira-main-boleto-migrations.md) a [0030](../adr/0030-manutencao-de-dados-e-origem-do-tenant.md). O 0030 registra três pontos que a implementação mostrou: política mínima da dona em `empresa_gestora` (para trocar o CNPJ), migração de dados que define o tenant, e `app.tenant_origem_id` como contrato do backend.
- As branches usadas foram `feat/task-06-flyway-jar`, `feat/task-06-schema-inicial` e `docs/task-06-migrations`, no lugar dos nomes do plano. As exceções do lint ficaram por arquivo (`-- squawk-ignore-file`), e não no `.squawk.toml`.
- O teste de isolamento roda com `docker compose run --build --rm tests`, não com `up --abort-on-container-exit`: o serviço `flyway` termina antes e derrubaria o `tests`.
- Não houve nova tag na parte C: o `versions.toml` não mudou. O `boleto-migrations` segue na `v0.4.0`.
- Não existe página de inventário de dados pessoais; a lista dos campos pessoais da V1 está em [Modelo de dados](../arquitetura/modelo-de-dados.md#dados-pessoais-lgpd) e o Task 15 a incorpora.

## Pendências

Nada pendente deste Task. O que segue pertence a outras tarefas:

- Task 8: definir `app.tenant_id` e `app.tenant_origem_id` só a partir do JWT validado; confirmar `revinfo_seq` (incremento 50) com `ddl-auto=validate`; decidir a auditoria do catálogo `tela` (nome, menu e ordem).
- Task 12 em diante (frontend): a barra de administração para assumir empresa. O banco já tem o suporte.
- Task 14: publicar a imagem de migração (multi-arquitetura, x64 e Graviton) e encadear migração, backend e frontend no pipeline. A CI do `boleto-migrations` roda só em x64, e o build multi-arquitetura não foi verificado.

Não verificado no fechamento: o código de saída do `compose run ... tests` local (a CI repetiu e passou), a exclusão da branch remota `docs/task-06-fechamento` do `boleto-migrations` e o link do ADR 0030 no README dele.

## Nota posterior (2026-11-22): `flyway` sem profile

Este registro descreve o estado da época e não foi reescrito. O [ADR 0035](../adr/0035-compose-sobe-a-aplicacao-inteira.md) tirou o serviço `flyway` do profile `migrations`: ele roda a cada `docker compose up -d` e o backend espera por ele. O comando `docker compose run --build --rm flyway` continua valendo para rodar só a migração. O `--profile migrations` citado na verificação deixou de existir.

## Histórico

| Data | Atualização |
|---|---|
| 2026-11-21 | Parte A: JARs do Flyway e Squawk no `versions.toml`, sincronização, serviço `flyway` no Compose e ADRs 0023 a 0029. Tag `v0.4.0` |
| 2026-11-21 | Parte B: `boleto-migrations` com imagem, V1, roles, RLS, testes de isolamento, lint e CI (PR #1) |
| 2026-11-21 | Parte C: documentação final, ADR 0030, modelo de dados e guia de migrações |
| 2026-11-22 | Fechamento: README e `negativos.sh` do `boleto-migrations` (PR #2), guia de migrações e Task 6 concluída |
| 2026-11-22 | Nota: o `up` padrão passou a subir a aplicação inteira, sem profile ([ADR 0035](../adr/0035-compose-sobe-a-aplicacao-inteira.md)) |
